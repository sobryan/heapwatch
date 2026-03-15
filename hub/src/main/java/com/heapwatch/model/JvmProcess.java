package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class JvmProcess {
    private int pid;
    private String mainClass;
    private String displayName;
    private String jvmVersion;
    private boolean attachable;

    // Heap info
    private long heapUsedBytes;
    private long heapMaxBytes;
    private double heapUsagePercent;

    // CPU info
    private double cpuPercent;

    // Thread info
    private int threadCount;
    private int deadlockedThreads;

    // GC info
    private long gcCollectionCount;
    private long gcCollectionTimeMs;

    // Uptime
    private long uptimeMs;

    // Status
    private String status; // HEALTHY, WARNING, CRITICAL

    // Agent info
    private String agentId;
    private String hostName;

    public void computeStatus() {
        if (heapMaxBytes > 0) {
            heapUsagePercent = (double) heapUsedBytes / heapMaxBytes * 100.0;
        }
        if (heapUsagePercent > 85 || deadlockedThreads > 0) {
            status = "CRITICAL";
        } else if (heapUsagePercent > 70 || cpuPercent > 80) {
            status = "WARNING";
        } else {
            status = "HEALTHY";
        }
    }
}
