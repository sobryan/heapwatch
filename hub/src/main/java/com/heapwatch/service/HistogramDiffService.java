package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Captures class histogram baselines and computes diffs to identify
 * growing/shrinking object types between snapshots.
 */
@Slf4j
@Service
public class HistogramDiffService {

    // pid -> baseline histogram (className -> {instances, bytes})
    private final Map<Integer, Map<String, long[]>> baselines = new ConcurrentHashMap<>();
    private final Map<Integer, String> baselineTimestamps = new ConcurrentHashMap<>();

    /**
     * Captures the current class histogram as a baseline for the given PID.
     */
    public Map<String, Object> captureBaseline(int pid) {
        Map<String, long[]> histogram = getRawHistogram(pid);
        baselines.put(pid, histogram);
        String ts = java.time.Instant.now().toString();
        baselineTimestamps.put(pid, ts);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pid", pid);
        result.put("timestamp", ts);
        result.put("classCount", histogram.size());
        result.put("message", "Baseline captured with " + histogram.size() + " classes");
        return result;
    }

    /**
     * Compares current histogram to the stored baseline, returning classes
     * that grew or shrank.
     */
    public Map<String, Object> computeDiff(int pid) {
        Map<String, long[]> baseline = baselines.get(pid);
        if (baseline == null) {
            throw new RuntimeException("No baseline captured for PID " + pid + ". Capture a baseline first.");
        }

        Map<String, long[]> current = getRawHistogram(pid);
        String baselineTs = baselineTimestamps.getOrDefault(pid, "unknown");
        String currentTs = java.time.Instant.now().toString();

        List<Map<String, Object>> growing = new ArrayList<>();
        List<Map<String, Object>> shrinking = new ArrayList<>();
        List<Map<String, Object>> newClasses = new ArrayList<>();

        // Compare current to baseline
        for (Map.Entry<String, long[]> entry : current.entrySet()) {
            String className = entry.getKey();
            long[] curValues = entry.getValue(); // [instances, bytes]
            long[] baseValues = baseline.get(className);

            if (baseValues == null) {
                // New class since baseline
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("className", className);
                item.put("currentInstances", curValues[0]);
                item.put("currentBytes", curValues[1]);
                item.put("deltaInstances", curValues[0]);
                item.put("deltaBytes", curValues[1]);
                item.put("currentBytesFormatted", formatBytes(curValues[1]));
                item.put("deltaBytesFormatted", "+" + formatBytes(curValues[1]));
                newClasses.add(item);
            } else {
                long deltaInstances = curValues[0] - baseValues[0];
                long deltaBytes = curValues[1] - baseValues[1];

                if (deltaInstances != 0 || deltaBytes != 0) {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("className", className);
                    item.put("baselineInstances", baseValues[0]);
                    item.put("baselineBytes", baseValues[1]);
                    item.put("currentInstances", curValues[0]);
                    item.put("currentBytes", curValues[1]);
                    item.put("deltaInstances", deltaInstances);
                    item.put("deltaBytes", deltaBytes);
                    item.put("currentBytesFormatted", formatBytes(curValues[1]));
                    item.put("deltaBytesFormatted",
                            (deltaBytes >= 0 ? "+" : "") + formatBytes(deltaBytes));

                    if (deltaBytes > 0) {
                        growing.add(item);
                    } else {
                        shrinking.add(item);
                    }
                }
            }
        }

        // Sort growing by deltaBytes descending, shrinking by deltaBytes ascending
        growing.sort((a, b) -> Long.compare(
                ((Number) b.get("deltaBytes")).longValue(),
                ((Number) a.get("deltaBytes")).longValue()));
        shrinking.sort((a, b) -> Long.compare(
                ((Number) a.get("deltaBytes")).longValue(),
                ((Number) b.get("deltaBytes")).longValue()));

        // Limit to top 30 each
        if (growing.size() > 30) growing = new ArrayList<>(growing.subList(0, 30));
        if (shrinking.size() > 30) shrinking = new ArrayList<>(shrinking.subList(0, 30));
        if (newClasses.size() > 20) newClasses = new ArrayList<>(newClasses.subList(0, 20));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pid", pid);
        result.put("baselineTimestamp", baselineTs);
        result.put("currentTimestamp", currentTs);
        result.put("growing", growing);
        result.put("shrinking", shrinking);
        result.put("newClasses", newClasses);
        result.put("growingCount", growing.size());
        result.put("shrinkingCount", shrinking.size());
        result.put("newCount", newClasses.size());
        return result;
    }

    public boolean hasBaseline(int pid) {
        return baselines.containsKey(pid);
    }

    /**
     * Runs jcmd GC.class_histogram and returns raw map of className -> [instances, bytes].
     */
    private Map<String, long[]> getRawHistogram(int pid) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), "GC.class_histogram")
                    .redirectErrorStream(true).start();

            Map<String, long[]> histogram = new LinkedHashMap<>();
            Pattern linePattern = Pattern.compile("^\\s*\\d+:\\s+(\\d+)\\s+(\\d+)\\s+(.+)$");

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    Matcher matcher = linePattern.matcher(line);
                    if (matcher.matches()) {
                        long instances = Long.parseLong(matcher.group(1));
                        long bytes = Long.parseLong(matcher.group(2));
                        String className = friendlyClassName(matcher.group(3).trim());
                        histogram.put(className, new long[]{instances, bytes});
                    }
                }
            }

            if (!proc.waitFor(30, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
            }

            return histogram;
        } catch (Exception e) {
            log.warn("Failed to get class histogram for pid {}: {}", pid, e.getMessage());
            return Collections.emptyMap();
        }
    }

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
        if (bytes == 0) return "0 B";
        boolean negative = bytes < 0;
        long abs = Math.abs(bytes);
        String formatted;
        if (abs < 1024) formatted = abs + " B";
        else if (abs < 1024 * 1024) formatted = String.format("%.1f KB", abs / 1024.0);
        else if (abs < 1024L * 1024 * 1024) formatted = String.format("%.1f MB", abs / (1024.0 * 1024));
        else formatted = String.format("%.1f GB", abs / (1024.0 * 1024 * 1024));
        return negative ? "-" + formatted : formatted;
    }
}
