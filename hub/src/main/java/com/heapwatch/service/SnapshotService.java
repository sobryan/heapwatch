package com.heapwatch.service;

import com.heapwatch.model.JvmProcess;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Captures and compares JVM state snapshots for comparison mode.
 * Snapshots include heap, thread, GC, and status at a point in time.
 */
@Slf4j
@Service
public class SnapshotService {

    private final JvmDiscoveryService discoveryService;
    private final AtomicInteger snapshotIdCounter = new AtomicInteger(1);
    private final Map<Integer, Map<String, Object>> snapshots = new ConcurrentHashMap<>();

    public SnapshotService(JvmDiscoveryService discoveryService) {
        this.discoveryService = discoveryService;
    }

    /**
     * Captures the current state of a JVM process as a snapshot.
     */
    public Map<String, Object> captureSnapshot(int pid) {
        JvmProcess jvm = discoveryService.getJvm(pid)
                .orElseThrow(() -> new RuntimeException("JVM process not found: " + pid));
        jvm.computeStatus();

        int snapshotId = snapshotIdCounter.getAndIncrement();

        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("id", snapshotId);
        snapshot.put("pid", pid);
        snapshot.put("processName", jvm.getDisplayName());
        snapshot.put("timestamp", Instant.now().toString());
        snapshot.put("heapUsedBytes", jvm.getHeapUsedBytes());
        snapshot.put("heapMaxBytes", jvm.getHeapMaxBytes());
        snapshot.put("heapUsagePercent", jvm.getHeapUsagePercent());
        snapshot.put("threadCount", jvm.getThreadCount());
        snapshot.put("cpuPercent", jvm.getCpuPercent());
        snapshot.put("status", jvm.getStatus());
        snapshot.put("gcCollectionCount", jvm.getGcCollectionCount());
        snapshot.put("gcCollectionTimeMs", jvm.getGcCollectionTimeMs());
        snapshot.put("deadlockedThreads", jvm.getDeadlockedThreads());

        snapshots.put(snapshotId, snapshot);
        log.info("Captured snapshot {} for PID {}", snapshotId, pid);
        return snapshot;
    }

    /**
     * Lists all saved snapshots, optionally filtered by PID.
     */
    public List<Map<String, Object>> listSnapshots(Integer pid) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> snap : snapshots.values()) {
            if (pid == null || pid.equals(((Number) snap.get("pid")).intValue())) {
                result.add(snap);
            }
        }
        result.sort((a, b) -> {
            String tsA = (String) a.get("timestamp");
            String tsB = (String) b.get("timestamp");
            return tsB.compareTo(tsA); // newest first
        });
        return result;
    }

    /**
     * Compares two snapshots and returns the deltas.
     */
    public Map<String, Object> compare(int snapshot1Id, int snapshot2Id) {
        Map<String, Object> snap1 = snapshots.get(snapshot1Id);
        Map<String, Object> snap2 = snapshots.get(snapshot2Id);

        if (snap1 == null) throw new RuntimeException("Snapshot not found: " + snapshot1Id);
        if (snap2 == null) throw new RuntimeException("Snapshot not found: " + snapshot2Id);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("snapshot1", snap1);
        result.put("snapshot2", snap2);

        // Calculate deltas
        Map<String, Object> deltas = new LinkedHashMap<>();

        long heap1 = ((Number) snap1.get("heapUsedBytes")).longValue();
        long heap2 = ((Number) snap2.get("heapUsedBytes")).longValue();
        deltas.put("heapUsedChange", heap2 - heap1);
        deltas.put("heapUsedChangeFormatted", formatBytesDelta(heap2 - heap1));

        double heapPct1 = ((Number) snap1.get("heapUsagePercent")).doubleValue();
        double heapPct2 = ((Number) snap2.get("heapUsagePercent")).doubleValue();
        deltas.put("heapPercentChange", Math.round((heapPct2 - heapPct1) * 10.0) / 10.0);

        int threads1 = ((Number) snap1.get("threadCount")).intValue();
        int threads2 = ((Number) snap2.get("threadCount")).intValue();
        deltas.put("threadCountChange", threads2 - threads1);

        long gc1 = ((Number) snap1.get("gcCollectionCount")).longValue();
        long gc2 = ((Number) snap2.get("gcCollectionCount")).longValue();
        deltas.put("gcCountChange", gc2 - gc1);

        long gcTime1 = ((Number) snap1.get("gcCollectionTimeMs")).longValue();
        long gcTime2 = ((Number) snap2.get("gcCollectionTimeMs")).longValue();
        deltas.put("gcTimeChangeMs", gcTime2 - gcTime1);

        String status1 = (String) snap1.get("status");
        String status2 = (String) snap2.get("status");
        deltas.put("statusChanged", !status1.equals(status2));
        deltas.put("statusBefore", status1);
        deltas.put("statusAfter", status2);

        // Determine overall health direction
        int score = 0;
        if (heapPct2 < heapPct1) score++;
        else if (heapPct2 > heapPct1) score--;
        if (threads2 < threads1 && threads1 > 100) score++;
        else if (threads2 > threads1 * 1.5) score--;
        if ("HEALTHY".equals(status2) && !"HEALTHY".equals(status1)) score++;
        if ("CRITICAL".equals(status2) && !"CRITICAL".equals(status1)) score--;

        deltas.put("overallTrend", score > 0 ? "IMPROVING" : score < 0 ? "DEGRADING" : "STABLE");

        result.put("deltas", deltas);
        return result;
    }

    private String formatBytesDelta(long bytes) {
        String prefix = bytes >= 0 ? "+" : "";
        long abs = Math.abs(bytes);
        if (abs < 1024) return prefix + abs + " B";
        if (abs < 1024 * 1024) return prefix + String.format("%.1f KB", abs / 1024.0);
        if (abs < 1024L * 1024 * 1024) return prefix + String.format("%.1f MB", abs / (1024.0 * 1024));
        return prefix + String.format("%.1f GB", abs / (1024.0 * 1024 * 1024));
    }
}
