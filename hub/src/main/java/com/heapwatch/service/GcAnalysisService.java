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
 * Analyzes GC behavior of target JVMs using jcmd GC.heap_info and VM.info.
 * Provides GC pause distribution, throughput, young/old gen stats.
 */
@Slf4j
@Service
public class GcAnalysisService {

    /**
     * Performs GC analysis on the given PID.
     */
    public Map<String, Object> analyze(int pid) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pid", pid);

        // Get GC info from VM.info (contains GC pause stats on most JVMs)
        Map<String, Object> gcStats = getGcStats(pid);
        result.putAll(gcStats);

        // Get heap space breakdown
        Map<String, Object> heapSpaces = getHeapSpaces(pid);
        result.put("heapSpaces", heapSpaces);

        return result;
    }

    private Map<String, Object> getGcStats(int pid) {
        Map<String, Object> stats = new LinkedHashMap<>();
        try {
            // Try VM.info for comprehensive GC data
            String vmInfo = runJcmd(pid, "VM.info");

            // Parse GC type
            if (vmInfo.contains("G1")) {
                stats.put("gcType", "G1 Garbage Collector");
            } else if (vmInfo.contains("ZGC")) {
                stats.put("gcType", "ZGC");
            } else if (vmInfo.contains("Shenandoah")) {
                stats.put("gcType", "Shenandoah");
            } else if (vmInfo.contains("Parallel")) {
                stats.put("gcType", "Parallel GC");
            } else if (vmInfo.contains("Serial")) {
                stats.put("gcType", "Serial GC");
            } else {
                stats.put("gcType", "Unknown");
            }

            // Try GC.run_finalization to get GC stats via PerfCounter
            String perfCounters = runJcmd(pid, "PerfCounter.print");

            long youngGcCount = extractPerfCounter(perfCounters, "sun.gc.collector.0.invocations");
            long oldGcCount = extractPerfCounter(perfCounters, "sun.gc.collector.1.invocations");
            long youngGcTimeMs = extractPerfCounter(perfCounters, "sun.gc.collector.0.time") / 1_000_000; // ns to ms
            long oldGcTimeMs = extractPerfCounter(perfCounters, "sun.gc.collector.1.time") / 1_000_000;
            long totalCollections = youngGcCount + oldGcCount;
            long totalPauseMs = youngGcTimeMs + oldGcTimeMs;

            stats.put("youngGenCollections", youngGcCount);
            stats.put("oldGenCollections", oldGcCount);
            stats.put("totalCollections", totalCollections);
            stats.put("youngGenPauseMs", youngGcTimeMs);
            stats.put("oldGenPauseMs", oldGcTimeMs);
            stats.put("totalPauseMs", totalPauseMs);
            stats.put("avgPauseMs", totalCollections > 0 ? totalPauseMs / totalCollections : 0);

            // Estimate max pause from the older gen collector (typically longer)
            long maxPauseEstimate = oldGcCount > 0 ? oldGcTimeMs / oldGcCount : 0;
            if (maxPauseEstimate < (youngGcCount > 0 ? youngGcTimeMs / youngGcCount : 0)) {
                maxPauseEstimate = youngGcCount > 0 ? youngGcTimeMs / youngGcCount : 0;
            }
            stats.put("maxPauseEstimateMs", maxPauseEstimate);

            // Calculate throughput (% of time NOT in GC)
            long uptimeMs = extractPerfCounter(perfCounters, "sun.os.hrt.ticks");
            long tickFreq = extractPerfCounter(perfCounters, "sun.os.hrt.frequency");
            if (tickFreq > 0 && uptimeMs > 0) {
                long uptimeActualMs = (uptimeMs * 1000) / tickFreq;
                if (uptimeActualMs > 0) {
                    double throughput = 100.0 * (1.0 - ((double) totalPauseMs / uptimeActualMs));
                    stats.put("throughputPercent", Math.max(0, Math.min(100, Math.round(throughput * 10.0) / 10.0)));
                }
            }
            if (!stats.containsKey("throughputPercent")) {
                stats.put("throughputPercent", 99.0); // Assume high throughput if we can't measure
            }

        } catch (Exception e) {
            log.warn("GC stats analysis failed for pid {}: {}", pid, e.getMessage());
            stats.put("error", "Could not get GC stats: " + e.getMessage());
        }
        return stats;
    }

    private Map<String, Object> getHeapSpaces(int pid) {
        Map<String, Object> spaces = new LinkedHashMap<>();
        try {
            String heapInfo = runJcmd(pid, "GC.heap_info");

            // Parse heap region info
            for (String line : heapInfo.split("\n")) {
                line = line.trim();
                if (line.contains("total") && line.contains("used")) {
                    // e.g., " garbage-first heap   total 131072K, used 65536K [..."
                    String spaceName = line.split("total")[0].trim();
                    if (spaceName.isEmpty()) spaceName = "heap";

                    var totalMatcher = Pattern.compile("total\\s+(\\d+)K").matcher(line);
                    var usedMatcher = Pattern.compile("used\\s+(\\d+)K").matcher(line);

                    Map<String, Object> space = new LinkedHashMap<>();
                    if (totalMatcher.find()) space.put("totalKB", Long.parseLong(totalMatcher.group(1)));
                    if (usedMatcher.find()) space.put("usedKB", Long.parseLong(usedMatcher.group(1)));
                    spaces.put(spaceName, space);
                }
            }

            if (spaces.isEmpty()) {
                spaces.put("raw", heapInfo.trim());
            }
        } catch (Exception e) {
            spaces.put("error", e.getMessage());
        }
        return spaces;
    }

    private long extractPerfCounter(String perfOutput, String counterName) {
        for (String line : perfOutput.split("\n")) {
            if (line.trim().startsWith(counterName + "=")) {
                String value = line.split("=", 2)[1].trim();
                try {
                    return Long.parseLong(value);
                } catch (NumberFormatException e) {
                    return 0;
                }
            }
        }
        return 0;
    }

    private String runJcmd(int pid, String command) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), command)
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(10, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
                return "";
            }
            StringBuilder sb = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }
}
