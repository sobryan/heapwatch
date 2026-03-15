package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Analyzes heap dumps using jcmd GC.class_histogram.
 * Provides top object types by instance count and size,
 * and identifies potential memory leak suspects.
 */
@Slf4j
@Service
public class HeapDumpAnalysisService {

    private final HeapDumpService heapDumpService;

    public HeapDumpAnalysisService(HeapDumpService heapDumpService) {
        this.heapDumpService = heapDumpService;
    }

    /**
     * Analyzes a completed heap dump by running GC.class_histogram on the target PID.
     * If the process is still alive, we get a live histogram. Otherwise, we provide
     * file-level metadata.
     */
    public Map<String, Object> analyze(String dumpId) {
        var dump = heapDumpService.getDump(dumpId)
                .orElseThrow(() -> new RuntimeException("Heap dump not found: " + dumpId));

        if (!"COMPLETED".equals(dump.getStatus())) {
            throw new RuntimeException("Heap dump is not completed (status: " + dump.getStatus() + ")");
        }

        Map<String, Object> analysis = new LinkedHashMap<>();
        analysis.put("dumpId", dumpId);
        analysis.put("pid", dump.getPid());
        analysis.put("processName", dump.getProcessName());
        analysis.put("fileSizeBytes", dump.getFileSizeBytes());
        analysis.put("fileSizeFormatted", formatBytes(dump.getFileSizeBytes()));

        // Run class histogram on the live process
        List<Map<String, Object>> histogram = getClassHistogram(dump.getPid());
        analysis.put("topObjectsBySize", histogram);

        // Compute summary stats
        long totalInstances = 0;
        long totalBytes = 0;
        for (Map<String, Object> entry : histogram) {
            totalInstances += ((Number) entry.getOrDefault("instances", 0)).longValue();
            totalBytes += ((Number) entry.getOrDefault("bytes", 0)).longValue();
        }
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("totalClassesAnalyzed", histogram.size());
        summary.put("totalInstances", totalInstances);
        summary.put("totalBytes", totalBytes);
        summary.put("totalBytesFormatted", formatBytes(totalBytes));
        analysis.put("summary", summary);

        // Identify potential leak suspects
        analysis.put("leakSuspects", identifyLeakSuspects(histogram));

        return analysis;
    }

    /**
     * Runs `jcmd <pid> GC.class_histogram` and parses the output.
     * Example output format:
     *  num     #instances         #bytes  class name
     * -----------------------------------------------
     *    1:        123456       12345678  [B
     *    2:         98765        9876543  java.lang.String
     */
    private List<Map<String, Object>> getClassHistogram(int pid) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), "GC.class_histogram")
                    .redirectErrorStream(true).start();

            List<Map<String, Object>> entries = new ArrayList<>();
            Pattern linePattern = Pattern.compile("^\\s*(\\d+):\\s+(\\d+)\\s+(\\d+)\\s+(.+)$");

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                int count = 0;
                while ((line = reader.readLine()) != null && count < 50) {
                    Matcher matcher = linePattern.matcher(line);
                    if (matcher.matches()) {
                        Map<String, Object> entry = new LinkedHashMap<>();
                        entry.put("rank", Integer.parseInt(matcher.group(1)));
                        entry.put("instances", Long.parseLong(matcher.group(2)));
                        entry.put("bytes", Long.parseLong(matcher.group(3)));
                        String className = matcher.group(4).trim();
                        entry.put("className", friendlyClassName(className));
                        entry.put("rawClassName", className);
                        entry.put("bytesFormatted", formatBytes(Long.parseLong(matcher.group(3))));
                        entries.add(entry);
                        count++;
                    }
                }
            }

            if (!proc.waitFor(30, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
            }

            if (entries.isEmpty()) {
                entries.add(Map.of("note", "Process may no longer be running. Class histogram not available."));
            }

            return entries;
        } catch (Exception e) {
            log.warn("Failed to get class histogram for pid {}: {}", pid, e.getMessage());
            return List.of(Map.of("error", "Could not get class histogram: " + e.getMessage()));
        }
    }

    /**
     * Identifies potential leak suspects based on heuristics:
     * - Non-JDK classes with unusually high instance counts or sizes
     * - Collection types (HashMap, ArrayList, etc.) in top positions
     * - byte[] or char[] dominating memory (often a sign of String-related leaks)
     */
    private List<Map<String, Object>> identifyLeakSuspects(List<Map<String, Object>> histogram) {
        List<Map<String, Object>> suspects = new ArrayList<>();

        for (Map<String, Object> entry : histogram) {
            if (entry.containsKey("error") || entry.containsKey("note")) continue;

            String className = (String) entry.getOrDefault("rawClassName", "");
            long instances = ((Number) entry.getOrDefault("instances", 0)).longValue();
            long bytes = ((Number) entry.getOrDefault("bytes", 0)).longValue();
            int rank = ((Number) entry.getOrDefault("rank", 99)).intValue();

            // Only flag top 20 entries
            if (rank > 20) continue;

            Map<String, Object> suspect = new LinkedHashMap<>();

            // Large byte arrays often indicate String-related leaks or buffer accumulation
            if (className.equals("[B") && rank <= 3 && bytes > 10_000_000) {
                suspect.put("className", "byte[]");
                suspect.put("reason", "Large byte array footprint (" + formatBytes(bytes) + ") — may indicate String or buffer accumulation");
                suspect.put("severity", "MEDIUM");
                suspect.put("recommendation", "Check for unbounded String concatenation, logging buffers, or cached byte data");
                suspects.add(suspect);
            }

            // Collection types in top positions suggest unbounded growth
            if ((className.contains("HashMap") || className.contains("ArrayList") ||
                    className.contains("LinkedList") || className.contains("ConcurrentHashMap") ||
                    className.contains("HashSet")) && instances > 10000) {
                suspect.put("className", entry.get("className"));
                suspect.put("reason", instances + " instances of collection type — possible unbounded growth");
                suspect.put("severity", instances > 100000 ? "HIGH" : "MEDIUM");
                suspect.put("recommendation", "Verify collections are being properly cleared or bounded (e.g., LRU eviction)");
                suspects.add(suspect);
            }

            // Non-JDK classes in top 10 with high counts
            if (rank <= 10 && !className.startsWith("[") &&
                    !className.startsWith("java.") && !className.startsWith("jdk.") &&
                    !className.startsWith("sun.") && instances > 50000) {
                suspect.put("className", entry.get("className"));
                suspect.put("reason", instances + " instances of application class in top " + rank);
                suspect.put("severity", "HIGH");
                suspect.put("recommendation", "Investigate object lifecycle — are instances being retained unnecessarily?");
                suspects.add(suspect);
            }
        }

        if (suspects.isEmpty()) {
            suspects.add(Map.of(
                    "className", "none",
                    "reason", "No obvious leak suspects detected from class histogram",
                    "severity", "INFO",
                    "recommendation", "Heap looks normal. Take another dump in a few minutes and compare for growth trends."
            ));
        }

        return suspects;
    }

    /**
     * Converts internal JVM class names to friendly names.
     * e.g., "[B" -> "byte[]", "[Ljava.lang.String;" -> "String[]"
     */
    private String friendlyClassName(String raw) {
        if (raw == null) return "Unknown";
        return switch (raw) {
            case "[B" -> "byte[]";
            case "[C" -> "char[]";
            case "[I" -> "int[]";
            case "[J" -> "long[]";
            case "[D" -> "double[]";
            case "[F" -> "float[]";
            case "[Z" -> "boolean[]";
            case "[S" -> "short[]";
            default -> {
                if (raw.startsWith("[L") && raw.endsWith(";")) {
                    yield raw.substring(2, raw.length() - 1) + "[]";
                }
                yield raw;
            }
        };
    }

    private String formatBytes(long bytes) {
        if (bytes <= 0) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
