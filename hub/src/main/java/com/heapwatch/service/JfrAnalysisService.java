package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Analyzes completed JFR recording files using jcmd JFR.dump and the jfr command-line tool.
 * Falls back to jcmd-based extraction if the jfr tool is not available.
 */
@Slf4j
@Service
public class JfrAnalysisService {

    private final JfrService jfrService;

    public JfrAnalysisService(JfrService jfrService) {
        this.jfrService = jfrService;
    }

    /**
     * Analyzes a completed JFR recording and returns structured results.
     */
    public Map<String, Object> analyze(String recordingId) {
        var recording = jfrService.getRecording(recordingId)
                .orElseThrow(() -> new RuntimeException("Recording not found: " + recordingId));

        if (!"COMPLETED".equals(recording.getStatus())) {
            throw new RuntimeException("Recording is not completed (status: " + recording.getStatus() + ")");
        }

        Path filePath = Paths.get(recording.getOutputPath());
        if (!Files.exists(filePath)) {
            throw new RuntimeException("Recording file not found: " + filePath);
        }

        Map<String, Object> analysis = new LinkedHashMap<>();
        analysis.put("recordingId", recordingId);
        analysis.put("pid", recording.getPid());
        analysis.put("processName", recording.getProcessName());
        analysis.put("profileType", recording.getProfileType());
        analysis.put("durationSeconds", recording.getDurationSeconds());
        analysis.put("fileSizeBytes", recording.getFileSizeBytes());

        // Try using the jfr CLI tool first (ships with JDK 17+)
        boolean jfrToolAvailable = isJfrToolAvailable();

        if (jfrToolAvailable) {
            analysis.put("cpuHotspots", extractCpuHotspots(filePath));
            analysis.put("allocationHotspots", extractAllocationHotspots(filePath));
            analysis.put("threadActivity", extractThreadActivity(filePath));
            analysis.put("gcSummary", extractGcSummary(filePath));
        } else {
            // Fallback: run jcmd-based analysis on the target PID
            analysis.put("cpuHotspots", extractCpuViaJcmd(recording.getPid()));
            analysis.put("allocationHotspots", List.of(Map.of("note", "jfr CLI not available; allocation data requires JFR file parsing")));
            analysis.put("threadActivity", extractThreadActivityViaJcmd(recording.getPid()));
            analysis.put("gcSummary", extractGcViaJcmd(recording.getPid()));
        }

        return analysis;
    }

    private boolean isJfrToolAvailable() {
        try {
            Process proc = new ProcessBuilder("jfr", "--version")
                    .redirectErrorStream(true).start();
            boolean finished = proc.waitFor(5, TimeUnit.SECONDS);
            if (!finished) { proc.destroyForcibly(); return false; }
            return proc.exitValue() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Uses `jfr print --events jdk.ExecutionSample` to extract CPU hotspots.
     */
    private List<Map<String, Object>> extractCpuHotspots(Path jfrFile) {
        try {
            String output = runCommand("jfr", "print", "--events", "jdk.ExecutionSample", jfrFile.toString());
            Map<String, Integer> methodCounts = new LinkedHashMap<>();

            // Parse ExecutionSample events — look for top-of-stack method
            Pattern stackPattern = Pattern.compile("stackTrace:.*?\\n\\s+(.+?)\\n", Pattern.DOTALL);
            // Simpler approach: count method occurrences in stack traces
            for (String line : output.split("\n")) {
                line = line.trim();
                if (line.startsWith("jdk.ExecutionSample") || line.isEmpty()) continue;
                if (line.contains("(") && !line.startsWith("@") && !line.startsWith("jfr")) {
                    // Extract method name from stack frame like "com.example.Class.method()"
                    String method = line.split("\\(")[0].trim();
                    if (!method.isEmpty() && !method.startsWith("java.lang.Thread")) {
                        methodCounts.merge(method, 1, Integer::sum);
                    }
                }
            }

            // Sort by count descending, take top 20
            List<Map<String, Object>> hotspots = new ArrayList<>();
            methodCounts.entrySet().stream()
                    .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                    .limit(20)
                    .forEach(e -> {
                        Map<String, Object> entry = new LinkedHashMap<>();
                        entry.put("method", e.getKey());
                        entry.put("samples", e.getValue());
                        hotspots.add(entry);
                    });

            if (hotspots.isEmpty()) {
                hotspots.add(Map.of("note", "No CPU execution samples found in recording"));
            }
            return hotspots;
        } catch (Exception e) {
            log.warn("Failed to extract CPU hotspots: {}", e.getMessage());
            return List.of(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Uses `jfr print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB`
     * to extract memory allocation hotspots.
     */
    private List<Map<String, Object>> extractAllocationHotspots(Path jfrFile) {
        try {
            String output = runCommand("jfr", "print", "--events",
                    "jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB",
                    jfrFile.toString());

            Map<String, long[]> allocCounts = new LinkedHashMap<>(); // className -> [count, totalBytes]
            String currentClass = null;
            long currentSize = 0;

            for (String line : output.split("\n")) {
                line = line.trim();
                if (line.startsWith("objectClass")) {
                    // objectClass = com.example.SomeClass (classLoader = ...)
                    String cls = line.replaceFirst("objectClass\\s*=\\s*", "").split("\\s*\\(")[0].trim();
                    currentClass = cls;
                } else if (line.startsWith("allocationSize") && currentClass != null) {
                    try {
                        String sizeStr = line.replaceFirst("allocationSize\\s*=\\s*", "").trim();
                        // Handle formatted sizes like "1.2 kB" or raw bytes
                        currentSize = parseSize(sizeStr);
                        allocCounts.computeIfAbsent(currentClass, k -> new long[]{0, 0});
                        allocCounts.get(currentClass)[0]++;
                        allocCounts.get(currentClass)[1] += currentSize;
                        currentClass = null;
                    } catch (Exception ignored) {}
                }
            }

            List<Map<String, Object>> hotspots = new ArrayList<>();
            allocCounts.entrySet().stream()
                    .sorted((a, b) -> Long.compare(b.getValue()[1], a.getValue()[1]))
                    .limit(20)
                    .forEach(e -> {
                        Map<String, Object> entry = new LinkedHashMap<>();
                        entry.put("className", e.getKey());
                        entry.put("allocationCount", e.getValue()[0]);
                        entry.put("totalBytes", e.getValue()[1]);
                        entry.put("totalFormatted", formatBytes(e.getValue()[1]));
                        hotspots.add(entry);
                    });

            if (hotspots.isEmpty()) {
                hotspots.add(Map.of("note", "No allocation events found. Use ALLOC or FULL profile type to capture allocations."));
            }
            return hotspots;
        } catch (Exception e) {
            log.warn("Failed to extract allocation hotspots: {}", e.getMessage());
            return List.of(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Extracts thread activity summary from JFR.
     */
    private Map<String, Object> extractThreadActivity(Path jfrFile) {
        try {
            String output = runCommand("jfr", "print", "--events",
                    "jdk.ThreadStart,jdk.ThreadEnd,jdk.ThreadSleep,jdk.ThreadPark",
                    jfrFile.toString());

            int threadStarts = 0, threadEnds = 0, threadSleeps = 0, threadParks = 0;
            for (String line : output.split("\n")) {
                if (line.contains("jdk.ThreadStart")) threadStarts++;
                else if (line.contains("jdk.ThreadEnd")) threadEnds++;
                else if (line.contains("jdk.ThreadSleep")) threadSleeps++;
                else if (line.contains("jdk.ThreadPark")) threadParks++;
            }

            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("threadStarts", threadStarts);
            summary.put("threadEnds", threadEnds);
            summary.put("threadSleepEvents", threadSleeps);
            summary.put("threadParkEvents", threadParks);
            return summary;
        } catch (Exception e) {
            log.warn("Failed to extract thread activity: {}", e.getMessage());
            return Map.of("error", e.getMessage());
        }
    }

    /**
     * Extracts GC events summary from JFR.
     */
    private Map<String, Object> extractGcSummary(Path jfrFile) {
        try {
            String output = runCommand("jfr", "print", "--events",
                    "jdk.GarbageCollection,jdk.GCPhasePause",
                    jfrFile.toString());

            int gcCount = 0;
            long totalPauseNs = 0;
            long maxPauseNs = 0;
            String gcCause = "";

            for (String line : output.split("\n")) {
                line = line.trim();
                if (line.contains("jdk.GarbageCollection")) {
                    gcCount++;
                } else if (line.startsWith("duration")) {
                    try {
                        String durStr = line.replaceFirst("duration\\s*=\\s*", "").trim();
                        long ns = parseDuration(durStr);
                        totalPauseNs += ns;
                        if (ns > maxPauseNs) maxPauseNs = ns;
                    } catch (Exception ignored) {}
                } else if (line.startsWith("cause") && gcCause.isEmpty()) {
                    gcCause = line.replaceFirst("cause\\s*=\\s*", "").trim().replace("\"", "");
                }
            }

            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("collectionCount", gcCount);
            summary.put("totalPauseMs", totalPauseNs / 1_000_000);
            summary.put("maxPauseMs", maxPauseNs / 1_000_000);
            summary.put("avgPauseMs", gcCount > 0 ? totalPauseNs / gcCount / 1_000_000 : 0);
            if (!gcCause.isEmpty()) {
                summary.put("lastCause", gcCause);
            }
            return summary;
        } catch (Exception e) {
            log.warn("Failed to extract GC summary: {}", e.getMessage());
            return Map.of("error", e.getMessage());
        }
    }

    // --- Fallback methods using jcmd ---

    private List<Map<String, Object>> extractCpuViaJcmd(int pid) {
        try {
            String output = runCommand("jcmd", String.valueOf(pid), "Thread.print");
            Map<String, Integer> stateCounts = new LinkedHashMap<>();
            for (String line : output.split("\n")) {
                if (line.contains("java.lang.Thread.State:")) {
                    String state = line.trim().replace("java.lang.Thread.State: ", "");
                    stateCounts.merge(state, 1, Integer::sum);
                }
            }
            List<Map<String, Object>> result = new ArrayList<>();
            stateCounts.forEach((state, count) -> {
                Map<String, Object> entry = new LinkedHashMap<>();
                entry.put("threadState", state);
                entry.put("count", count);
                result.add(entry);
            });
            if (result.isEmpty()) {
                result.add(Map.of("note", "No thread state data available"));
            }
            return result;
        } catch (Exception e) {
            return List.of(Map.of("error", "Could not get CPU info: " + e.getMessage()));
        }
    }

    private Map<String, Object> extractThreadActivityViaJcmd(int pid) {
        try {
            String output = runCommand("jcmd", String.valueOf(pid), "Thread.print");
            int threadCount = 0;
            int runnableCount = 0;
            int waitingCount = 0;
            int blockedCount = 0;
            for (String line : output.split("\n")) {
                if (line.startsWith("\"")) threadCount++;
                if (line.contains("RUNNABLE")) runnableCount++;
                if (line.contains("WAITING") || line.contains("TIMED_WAITING")) waitingCount++;
                if (line.contains("BLOCKED")) blockedCount++;
            }
            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("totalThreads", threadCount);
            summary.put("runnable", runnableCount);
            summary.put("waiting", waitingCount);
            summary.put("blocked", blockedCount);
            return summary;
        } catch (Exception e) {
            return Map.of("error", "Could not get thread info: " + e.getMessage());
        }
    }

    private Map<String, Object> extractGcViaJcmd(int pid) {
        try {
            String output = runCommand("jcmd", String.valueOf(pid), "GC.heap_info");
            Map<String, Object> summary = new LinkedHashMap<>();
            for (String line : output.split("\n")) {
                if (line.contains("total") && line.contains("used")) {
                    summary.put("heapInfo", line.trim());
                }
            }
            if (summary.isEmpty()) {
                summary.put("note", "GC info not available");
            }
            return summary;
        } catch (Exception e) {
            return Map.of("error", "Could not get GC info: " + e.getMessage());
        }
    }

    // --- Utility methods ---

    private String runCommand(String... command) throws Exception {
        Process proc = new ProcessBuilder(command)
                .redirectErrorStream(true).start();
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }
        if (!proc.waitFor(60, TimeUnit.SECONDS)) {
            proc.destroyForcibly();
            throw new RuntimeException("Command timed out: " + String.join(" ", command));
        }
        return output.toString();
    }

    private long parseSize(String sizeStr) {
        sizeStr = sizeStr.trim().toLowerCase();
        try {
            if (sizeStr.endsWith("kb") || sizeStr.endsWith("k")) {
                return (long) (Double.parseDouble(sizeStr.replaceAll("[^\\d.]", "")) * 1024);
            } else if (sizeStr.endsWith("mb") || sizeStr.endsWith("m")) {
                return (long) (Double.parseDouble(sizeStr.replaceAll("[^\\d.]", "")) * 1024 * 1024);
            } else if (sizeStr.endsWith("gb") || sizeStr.endsWith("g")) {
                return (long) (Double.parseDouble(sizeStr.replaceAll("[^\\d.]", "")) * 1024 * 1024 * 1024);
            } else {
                return Long.parseLong(sizeStr.replaceAll("[^\\d]", ""));
            }
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private long parseDuration(String durStr) {
        durStr = durStr.trim().toLowerCase();
        try {
            if (durStr.endsWith("ms")) {
                return (long) (Double.parseDouble(durStr.replace("ms", "").trim()) * 1_000_000);
            } else if (durStr.endsWith("us") || durStr.contains("\u00b5s")) {
                return (long) (Double.parseDouble(durStr.replaceAll("[^\\d.]", "")) * 1_000);
            } else if (durStr.endsWith("ns")) {
                return Long.parseLong(durStr.replace("ns", "").trim());
            } else if (durStr.endsWith("s")) {
                return (long) (Double.parseDouble(durStr.replace("s", "").trim()) * 1_000_000_000);
            }
            return Long.parseLong(durStr.replaceAll("[^\\d]", ""));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private String formatBytes(long bytes) {
        if (bytes <= 0) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
