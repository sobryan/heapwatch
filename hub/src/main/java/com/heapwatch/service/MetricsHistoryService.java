package com.heapwatch.service;

import com.heapwatch.model.JvmProcess;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Captures JVM metrics snapshots every 15 seconds and retains up to 1 hour of history.
 * Provides time-series data for heap usage, thread count, CPU percent, and GC counts.
 */
@Slf4j
@Service
public class MetricsHistoryService {

    private static final int MAX_SNAPSHOTS = 240; // 1 hour at 15-second intervals

    private final JvmDiscoveryService discoveryService;

    // PID -> list of snapshots (most recent last)
    private final Map<Integer, List<Map<String, Object>>> history = new ConcurrentHashMap<>();

    public MetricsHistoryService(JvmDiscoveryService discoveryService) {
        this.discoveryService = discoveryService;
    }

    @Scheduled(fixedRate = 15000)
    public void captureSnapshot() {
        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        Instant now = Instant.now();

        for (JvmProcess jvm : jvms) {
            List<Map<String, Object>> snapshots = history.computeIfAbsent(
                    jvm.getPid(), k -> new CopyOnWriteArrayList<>());

            Map<String, Object> snapshot = new LinkedHashMap<>();
            snapshot.put("timestamp", now.toString());
            snapshot.put("heapUsed", jvm.getHeapUsedBytes());
            snapshot.put("heapMax", jvm.getHeapMaxBytes());
            snapshot.put("heapPercent", jvm.getHeapUsagePercent());
            snapshot.put("threadCount", jvm.getThreadCount());
            snapshot.put("cpuPercent", jvm.getCpuPercent());
            snapshot.put("gcCount", jvm.getGcCollectionCount());
            snapshot.put("gcTimeMs", jvm.getGcCollectionTimeMs());
            snapshots.add(snapshot);

            // Evict old snapshots
            while (snapshots.size() > MAX_SNAPSHOTS) {
                snapshots.remove(0);
            }
        }

        // Remove history for PIDs no longer alive
        Set<Integer> activePids = new HashSet<>();
        for (JvmProcess jvm : jvms) {
            activePids.add(jvm.getPid());
        }
        history.keySet().removeIf(pid -> !activePids.contains(pid));
    }

    /**
     * Returns time-series history for a specific JVM process.
     */
    public Map<String, Object> getHistory(int pid) {
        List<Map<String, Object>> snapshots = history.getOrDefault(pid, List.of());
        JvmProcess jvm = discoveryService.getJvm(pid).orElse(null);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pid", pid);
        result.put("processName", jvm != null ? jvm.getDisplayName() : "Unknown");
        result.put("snapshotCount", snapshots.size());
        result.put("intervalSeconds", 15);
        result.put("snapshots", snapshots);
        return result;
    }
}
