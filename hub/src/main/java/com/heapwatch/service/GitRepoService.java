package com.heapwatch.service;

import com.heapwatch.model.RepoStatus;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.*;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * Service that connects to a GitHub repo, clones it, and indexes Java source files.
 * Maps fully-qualified class names to file paths and parses method signatures.
 */
@Slf4j
@Service
public class GitRepoService {

    private String repoUrl;
    private String branch = "main";
    private Path localPath;
    private boolean connected;
    private String lastIndexed;
    private String lastError;

    // className -> filePath
    private final Map<String, Path> classIndex = new ConcurrentHashMap<>();
    // className -> list of method signatures
    private final Map<String, List<String>> methodIndex = new ConcurrentHashMap<>();
    // className -> source content
    private final Map<String, String> sourceCache = new ConcurrentHashMap<>();

    private static final Pattern PACKAGE_PATTERN = Pattern.compile("^\\s*package\\s+([\\w.]+)\\s*;");
    private static final Pattern CLASS_PATTERN = Pattern.compile("(?:public\\s+)?(?:abstract\\s+)?(?:final\\s+)?(?:class|interface|enum|record)\\s+(\\w+)");
    private static final Pattern METHOD_PATTERN = Pattern.compile(
            "(?:public|protected|private|static|final|synchronized|native|abstract|\\s)*" +
            "(?:<[^>]+>\\s+)?" +
            "(\\w+(?:<[^>]*>)?(?:\\[\\])?)\\s+(\\w+)\\s*\\([^)]*\\)");

    /**
     * Connect to a repository by URL (clone) or local path.
     */
    public RepoStatus connect(String url, String branchName) {
        this.repoUrl = url;
        this.branch = branchName != null ? branchName : "main";
        this.lastError = null;

        try {
            if (url.startsWith("/") || url.startsWith("file://")) {
                // Local path
                String path = url.startsWith("file://") ? url.substring(7) : url;
                this.localPath = Path.of(path);
                if (!Files.isDirectory(localPath)) {
                    this.lastError = "Directory not found: " + path;
                    this.connected = false;
                    return buildStatus();
                }
            } else {
                // Clone from remote
                Path tempDir = Files.createTempDirectory("heapwatch-repo-");
                log.info("Cloning {} (branch: {}) to {}", url, branch, tempDir);

                ProcessBuilder pb = new ProcessBuilder(
                        "git", "clone", "--depth", "1", "--branch", branch, url, tempDir.toString()
                ).redirectErrorStream(true);

                Process proc = pb.start();
                String output = readProcessOutput(proc);

                if (!proc.waitFor(60, TimeUnit.SECONDS)) {
                    proc.destroyForcibly();
                    this.lastError = "Git clone timed out after 60 seconds";
                    this.connected = false;
                    return buildStatus();
                }

                if (proc.exitValue() != 0) {
                    this.lastError = "Git clone failed: " + output;
                    this.connected = false;
                    return buildStatus();
                }

                this.localPath = tempDir;
            }

            // Index the repo
            indexRepository();
            this.connected = true;
            this.lastIndexed = Instant.now().toString();
            log.info("Repository connected and indexed: {} files, {} classes",
                    classIndex.size(), methodIndex.size());

        } catch (Exception e) {
            log.error("Failed to connect to repository", e);
            this.lastError = e.getMessage();
            this.connected = false;
        }

        return buildStatus();
    }

    /**
     * Get the current repository connection status.
     */
    public RepoStatus getStatus() {
        return buildStatus();
    }

    /**
     * Search for a class by fully-qualified name or simple name.
     */
    public Map<String, Object> searchClass(String className) {
        Map<String, Object> result = new HashMap<>();

        // Try exact match first
        Path path = classIndex.get(className);
        if (path != null) {
            result.put("found", true);
            result.put("className", className);
            result.put("filePath", path.toString());
            result.put("methods", methodIndex.getOrDefault(className, List.of()));
            result.put("source", sourceCache.getOrDefault(className, ""));
            return result;
        }

        // Try simple name match
        for (Map.Entry<String, Path> entry : classIndex.entrySet()) {
            if (entry.getKey().endsWith("." + className) || entry.getKey().equals(className)) {
                result.put("found", true);
                result.put("className", entry.getKey());
                result.put("filePath", entry.getValue().toString());
                result.put("methods", methodIndex.getOrDefault(entry.getKey(), List.of()));
                result.put("source", sourceCache.getOrDefault(entry.getKey(), ""));
                return result;
            }
        }

        result.put("found", false);
        result.put("className", className);
        result.put("availableClasses", new ArrayList<>(classIndex.keySet()));
        return result;
    }

    /**
     * Get source code for a specific method within a class.
     */
    public String getMethodSource(String className, String methodName) {
        String source = sourceCache.get(className);
        if (source == null) {
            // Try simple name
            for (Map.Entry<String, String> entry : sourceCache.entrySet()) {
                if (entry.getKey().endsWith("." + className)) {
                    source = entry.getValue();
                    break;
                }
            }
        }
        if (source == null) return null;

        // Extract method body
        String[] lines = source.split("\n");
        StringBuilder methodSource = new StringBuilder();
        boolean inMethod = false;
        int braceCount = 0;

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            if (!inMethod && line.contains(methodName) && line.contains("(")) {
                inMethod = true;
                braceCount = 0;
            }
            if (inMethod) {
                methodSource.append(line).append("\n");
                for (char c : line.toCharArray()) {
                    if (c == '{') braceCount++;
                    if (c == '}') braceCount--;
                }
                if (braceCount <= 0 && methodSource.length() > 0 && line.contains("}")) {
                    break;
                }
            }
        }

        return methodSource.length() > 0 ? methodSource.toString() : null;
    }

    /**
     * Get the file path for a given class name.
     */
    public Path getFilePath(String className) {
        Path path = classIndex.get(className);
        if (path != null) return path;

        for (Map.Entry<String, Path> entry : classIndex.entrySet()) {
            if (entry.getKey().endsWith("." + className)) {
                return entry.getValue();
            }
        }
        return null;
    }

    /**
     * Find the line range of a method in its source file.
     */
    public int[] findMethodLineRange(String className, String methodName) {
        String source = sourceCache.get(className);
        if (source == null) {
            for (Map.Entry<String, String> entry : sourceCache.entrySet()) {
                if (entry.getKey().endsWith("." + className)) {
                    source = entry.getValue();
                    break;
                }
            }
        }
        if (source == null) return new int[]{0, 0};

        String[] lines = source.split("\n");
        int startLine = -1;
        int endLine = -1;
        int braceCount = 0;

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            if (startLine == -1 && line.contains(methodName) && line.contains("(")) {
                startLine = i + 1;
                braceCount = 0;
            }
            if (startLine > 0) {
                for (char c : line.toCharArray()) {
                    if (c == '{') braceCount++;
                    if (c == '}') braceCount--;
                }
                if (braceCount <= 0 && line.contains("}")) {
                    endLine = i + 1;
                    break;
                }
            }
        }

        return new int[]{Math.max(startLine, 0), Math.max(endLine, 0)};
    }

    public boolean isConnected() {
        return connected;
    }

    public Map<String, Path> getClassIndex() {
        return Collections.unmodifiableMap(classIndex);
    }

    // --- Private helpers ---

    private void indexRepository() throws IOException {
        classIndex.clear();
        methodIndex.clear();
        sourceCache.clear();

        try (Stream<Path> files = Files.walk(localPath)) {
            files.filter(p -> p.toString().endsWith(".java"))
                 .filter(p -> !p.toString().contains("/build/"))
                 .filter(p -> !p.toString().contains("/target/"))
                 .filter(p -> !p.toString().contains("/.gradle/"))
                 .forEach(this::indexJavaFile);
        }
    }

    private void indexJavaFile(Path file) {
        try {
            String content = Files.readString(file);
            String packageName = "";
            List<String> methods = new ArrayList<>();

            for (String line : content.split("\n")) {
                Matcher pkgMatcher = PACKAGE_PATTERN.matcher(line);
                if (pkgMatcher.find()) {
                    packageName = pkgMatcher.group(1);
                }

                Matcher classMatcher = CLASS_PATTERN.matcher(line);
                if (classMatcher.find()) {
                    String className = classMatcher.group(1);
                    String fqcn = packageName.isEmpty() ? className : packageName + "." + className;
                    classIndex.put(fqcn, file);
                    sourceCache.put(fqcn, content);
                }

                Matcher methodMatcher = METHOD_PATTERN.matcher(line);
                if (methodMatcher.find()) {
                    String returnType = methodMatcher.group(1);
                    String methodName = methodMatcher.group(2);
                    if (!methodName.equals("if") && !methodName.equals("for") &&
                        !methodName.equals("while") && !methodName.equals("switch")) {
                        methods.add(returnType + " " + methodName + "(...)");
                    }
                }
            }

            if (!packageName.isEmpty()) {
                // Associate methods with the first class found in file
                for (String fqcn : classIndex.keySet()) {
                    if (classIndex.get(fqcn).equals(file)) {
                        methodIndex.put(fqcn, methods);
                        break;
                    }
                }
            }
        } catch (IOException e) {
            log.warn("Failed to index file: {}", file, e);
        }
    }

    private RepoStatus buildStatus() {
        return RepoStatus.builder()
                .repoUrl(repoUrl)
                .branch(branch)
                .localPath(localPath != null ? localPath.toString() : null)
                .connected(connected)
                .indexedFiles(classIndex.size())
                .indexedClasses((int) classIndex.values().stream().distinct().count())
                .lastIndexed(lastIndexed)
                .error(lastError)
                .build();
    }

    private String readProcessOutput(Process proc) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append("\n");
            }
        }
        return sb.toString();
    }
}
