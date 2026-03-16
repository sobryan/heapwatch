package com.heapwatch.service;

import com.heapwatch.model.CodeIssue;
import com.heapwatch.model.DiagnosisReport;
import com.heapwatch.model.JvmProcess;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.nio.file.Path;
import java.util.*;

/**
 * Maps profiling results (CPU hotspots, allocation hotspots, thread contention)
 * to source files in the connected repository.
 */
@Slf4j
@Service
public class CodeMappingService {

    private final GitRepoService gitRepoService;
    private final JvmDiscoveryService discoveryService;
    private final IssueRankingService issueRankingService;

    public CodeMappingService(GitRepoService gitRepoService,
                              JvmDiscoveryService discoveryService,
                              IssueRankingService issueRankingService) {
        this.gitRepoService = gitRepoService;
        this.discoveryService = discoveryService;
        this.issueRankingService = issueRankingService;
    }

    /**
     * Map all identified issues from profiling data and diagnosis reports to source code.
     */
    public List<CodeIssue> mapIssuesToSource() {
        if (!gitRepoService.isConnected()) {
            return List.of();
        }

        List<CodeIssue> allIssues = new ArrayList<>();

        // Get all discovered JVMs and their known issues
        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        for (JvmProcess jvm : jvms) {
            jvm.computeStatus();
            allIssues.addAll(mapJvmIssues(jvm));
        }

        // Rank and return
        return issueRankingService.rankIssues(allIssues);
    }

    /**
     * Map issues from a specific JVM's profiling data to source code.
     */
    private List<CodeIssue> mapJvmIssues(JvmProcess jvm) {
        List<CodeIssue> issues = new ArrayList<>();
        String displayName = jvm.getDisplayName().toLowerCase();

        // Identify the main class from display name
        String mainClass = extractMainClass(jvm.getDisplayName());
        if (mainClass == null) return issues;

        Map<String, Object> classInfo = gitRepoService.searchClass(mainClass);
        if (!(Boolean) classInfo.getOrDefault("found", false)) {
            return issues;
        }

        String fqcn = (String) classInfo.get("className");
        String filePath = (String) classInfo.get("filePath");
        String source = (String) classInfo.getOrDefault("source", "");

        // Memory leak detection
        if (jvm.getHeapUsagePercent() > 85) {
            String methodSource = findLeakMethod(source);
            int[] lineRange = findMethodLines(source, methodSource);

            issues.add(CodeIssue.builder()
                    .id(UUID.randomUUID().toString().substring(0, 8))
                    .severity(jvm.getHeapUsagePercent() > 95 ? "CRITICAL" : "HIGH")
                    .category("MEMORY")
                    .title("Memory leak pattern detected")
                    .description(String.format("Heap at %.1f%% - unbounded collection growth suspected in %s",
                            jvm.getHeapUsagePercent(), mainClass))
                    .method(fqcn + "." + extractMethodName(methodSource))
                    .filePath(filePath)
                    .lineStart(lineRange[0])
                    .lineEnd(lineRange[1])
                    .sourceSnippet(methodSource != null ? methodSource : truncateSource(source, 20))
                    .allocationBytes(jvm.getHeapUsedBytes())
                    .impactScore(9)
                    .build());
        }

        // CPU hotspot detection
        if (jvm.getCpuPercent() > 30) {
            String cpuMethod = findCpuHotspot(source);
            int[] lineRange = findMethodLines(source, cpuMethod);

            issues.add(CodeIssue.builder()
                    .id(UUID.randomUUID().toString().substring(0, 8))
                    .severity(jvm.getCpuPercent() > 80 ? "HIGH" : "MEDIUM")
                    .category("CPU")
                    .title("CPU hotspot detected")
                    .description(String.format("CPU usage at %.1f%% - inefficient algorithm suspected in %s",
                            jvm.getCpuPercent(), mainClass))
                    .method(fqcn + "." + extractMethodName(cpuMethod))
                    .filePath(filePath)
                    .lineStart(lineRange[0])
                    .lineEnd(lineRange[1])
                    .sourceSnippet(cpuMethod != null ? cpuMethod : truncateSource(source, 20))
                    .cpuPercent(jvm.getCpuPercent())
                    .impactScore(jvm.getCpuPercent() > 80 ? 8 : 6)
                    .build());
        }

        // Thread contention detection
        if (jvm.getDeadlockedThreads() > 0) {
            String threadMethod = findContentionMethod(source);
            int[] lineRange = findMethodLines(source, threadMethod);

            issues.add(CodeIssue.builder()
                    .id(UUID.randomUUID().toString().substring(0, 8))
                    .severity("CRITICAL")
                    .category("THREADS")
                    .title("Deadlock detected")
                    .description(String.format("%d deadlocked thread(s) in %s - lock ordering issue",
                            jvm.getDeadlockedThreads(), mainClass))
                    .method(fqcn + "." + extractMethodName(threadMethod))
                    .filePath(filePath)
                    .lineStart(lineRange[0])
                    .lineEnd(lineRange[1])
                    .sourceSnippet(threadMethod != null ? threadMethod : truncateSource(source, 20))
                    .threadCount(jvm.getDeadlockedThreads())
                    .impactScore(10)
                    .build());
        } else if (jvm.getThreadCount() > 100) {
            issues.add(CodeIssue.builder()
                    .id(UUID.randomUUID().toString().substring(0, 8))
                    .severity("MEDIUM")
                    .category("THREADS")
                    .title("Thread pool saturation")
                    .description(String.format("%d threads active in %s - possible thread leak or pool misconfiguration",
                            jvm.getThreadCount(), mainClass))
                    .method(fqcn)
                    .filePath(filePath)
                    .lineStart(1)
                    .lineEnd(10)
                    .sourceSnippet(truncateSource(source, 10))
                    .threadCount(jvm.getThreadCount())
                    .impactScore(5)
                    .build());
        }

        // GC pressure detection
        if (jvm.getGcCollectionTimeMs() > 500) {
            String gcMethod = findGcPressureMethod(source);
            int[] lineRange = findMethodLines(source, gcMethod);

            issues.add(CodeIssue.builder()
                    .id(UUID.randomUUID().toString().substring(0, 8))
                    .severity(jvm.getGcCollectionTimeMs() > 2000 ? "HIGH" : "MEDIUM")
                    .category("GC")
                    .title("Excessive GC pressure")
                    .description(String.format("GC pause time %dms - rapid short-lived allocations in %s",
                            jvm.getGcCollectionTimeMs(), mainClass))
                    .method(fqcn + "." + extractMethodName(gcMethod))
                    .filePath(filePath)
                    .lineStart(lineRange[0])
                    .lineEnd(lineRange[1])
                    .sourceSnippet(gcMethod != null ? gcMethod : truncateSource(source, 20))
                    .gcPauseMs(jvm.getGcCollectionTimeMs())
                    .impactScore(jvm.getGcCollectionTimeMs() > 2000 ? 7 : 5)
                    .build());
        }

        return issues;
    }

    // --- Heuristic pattern matchers ---

    private String extractMainClass(String displayName) {
        // Extract simple class name from display name
        if (displayName.contains(".")) {
            String[] parts = displayName.split("\\.");
            return parts[parts.length - 1];
        }
        // Remove common suffixes
        return displayName.replace(".jar", "").replace("Application", "App").trim();
    }

    private String findLeakMethod(String source) {
        // Look for patterns indicating memory leaks
        String[] patterns = {"ArrayList", "LinkedList", "HashMap", "add(", "put(", "LEAK"};
        return findMethodContaining(source, patterns);
    }

    private String findCpuHotspot(String source) {
        // Look for patterns indicating CPU-intensive code
        String[] patterns = {"sort", "Sort", "loop", "while (true)", "for (int", "O(n"};
        return findMethodContaining(source, patterns);
    }

    private String findContentionMethod(String source) {
        // Look for synchronization patterns
        String[] patterns = {"synchronized", "lock", "Lock", "ReentrantLock", "wait(", "notify"};
        return findMethodContaining(source, patterns);
    }

    private String findGcPressureMethod(String source) {
        // Look for allocation-heavy patterns
        String[] patterns = {"new byte[", "new String", "allocate", "ByteBuffer", "churn"};
        return findMethodContaining(source, patterns);
    }

    private String findMethodContaining(String source, String[] patterns) {
        String[] lines = source.split("\n");
        for (String pattern : patterns) {
            for (int i = 0; i < lines.length; i++) {
                if (lines[i].contains(pattern)) {
                    // Walk backward to find method start
                    int methodStart = i;
                    for (int j = i - 1; j >= 0; j--) {
                        if (lines[j].contains("void ") || lines[j].contains("int ") ||
                            lines[j].contains("String ") || lines[j].contains("public ") ||
                            lines[j].contains("private ") || lines[j].contains("protected ")) {
                            if (lines[j].contains("(")) {
                                methodStart = j;
                                break;
                            }
                        }
                    }
                    // Walk forward to find method end
                    int braceCount = 0;
                    StringBuilder sb = new StringBuilder();
                    for (int j = methodStart; j < lines.length; j++) {
                        sb.append(lines[j]).append("\n");
                        for (char c : lines[j].toCharArray()) {
                            if (c == '{') braceCount++;
                            if (c == '}') braceCount--;
                        }
                        if (braceCount <= 0 && j > methodStart && lines[j].contains("}")) {
                            return sb.toString();
                        }
                        if (sb.length() > 2000) break; // Safety limit
                    }
                    return sb.toString();
                }
            }
        }
        return null;
    }

    private String extractMethodName(String methodSource) {
        if (methodSource == null) return "unknown";
        // Find method name from first line
        String firstLine = methodSource.split("\n")[0];
        int parenIdx = firstLine.indexOf('(');
        if (parenIdx > 0) {
            String before = firstLine.substring(0, parenIdx).trim();
            String[] parts = before.split("\\s+");
            return parts[parts.length - 1];
        }
        return "unknown";
    }

    private int[] findMethodLines(String source, String methodSource) {
        if (methodSource == null || source == null) return new int[]{0, 0};
        String firstLine = methodSource.split("\n")[0].trim();
        String[] sourceLines = source.split("\n");
        for (int i = 0; i < sourceLines.length; i++) {
            if (sourceLines[i].trim().equals(firstLine)) {
                int methodLines = methodSource.split("\n").length;
                return new int[]{i + 1, i + methodLines};
            }
        }
        return new int[]{0, 0};
    }

    private String truncateSource(String source, int maxLines) {
        String[] lines = source.split("\n");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Math.min(maxLines, lines.length); i++) {
            sb.append(lines[i]).append("\n");
        }
        return sb.toString();
    }
}
