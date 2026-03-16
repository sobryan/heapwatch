package com.heapwatch.service;

import com.heapwatch.model.JvmProcess;
import com.heapwatch.model.SreIncident;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Autonomous SRE monitoring agent that continuously watches JVM processes,
 * detects anomalies, runs diagnosis, and generates incident reports.
 */
@Slf4j
@Service
public class SreAgentService {

    private final JvmDiscoveryService discoveryService;
    private final MetricsHistoryService metricsHistoryService;
    private final NotificationService notificationService;
    private final AlertIntegrationService alertIntegrationService;

    private final List<SreIncident> incidents = new CopyOnWriteArrayList<>();
    private final Map<String, SreIncident> incidentMap = new ConcurrentHashMap<>();

    // Baselines: pid -> metric -> baseline value
    private final Map<Integer, Map<String, Double>> baselines = new ConcurrentHashMap<>();
    // Track last metric values for rate-of-change detection
    private final Map<Integer, Map<String, Double>> lastMetrics = new ConcurrentHashMap<>();

    private final AtomicBoolean running = new AtomicBoolean(true);
    private final AtomicInteger totalScans = new AtomicInteger(0);
    private final AtomicInteger anomaliesDetected = new AtomicInteger(0);
    private final AtomicLong lastScanEpochMs = new AtomicLong(0);

    // Dedup: anomalyType+pid -> last incident time
    private final Map<String, Instant> recentIncidents = new ConcurrentHashMap<>();

    // Thresholds
    private static final double HEAP_GROWTH_RATE_THRESHOLD = 5.0; // % per scan
    private static final double THREAD_SPIKE_THRESHOLD = 50; // thread count jump
    private static final double GC_FREQUENCY_THRESHOLD = 20; // gc count jump per scan
    private static final double CPU_SUSTAINED_THRESHOLD = 80.0; // % CPU
    private static final int INCIDENT_DEDUP_SECONDS = 300; // 5 minutes

    public SreAgentService(JvmDiscoveryService discoveryService,
                           MetricsHistoryService metricsHistoryService,
                           NotificationService notificationService,
                           AlertIntegrationService alertIntegrationService) {
        this.discoveryService = discoveryService;
        this.metricsHistoryService = metricsHistoryService;
        this.notificationService = notificationService;
        this.alertIntegrationService = alertIntegrationService;
    }

    @Scheduled(fixedRate = 30000)
    public void monitoringLoop() {
        if (!running.get()) return;

        totalScans.incrementAndGet();
        lastScanEpochMs.set(System.currentTimeMillis());

        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        Instant now = Instant.now();

        for (JvmProcess jvm : jvms) {
            Map<String, Double> currentMetrics = collectMetrics(jvm);
            Map<String, Double> prev = lastMetrics.get(jvm.getPid());
            Map<String, Double> baseline = baselines.get(jvm.getPid());

            // Initialize baseline on first sight
            if (baseline == null) {
                baselines.put(jvm.getPid(), new HashMap<>(currentMetrics));
                lastMetrics.put(jvm.getPid(), new HashMap<>(currentMetrics));
                continue;
            }

            // Detect anomalies
            detectHeapGrowth(jvm, currentMetrics, prev, now);
            detectThreadSpike(jvm, currentMetrics, prev, now);
            detectGcFrequencyIncrease(jvm, currentMetrics, prev, now);
            detectSustainedHighCpu(jvm, currentMetrics, now);

            // Update last metrics
            lastMetrics.put(jvm.getPid(), new HashMap<>(currentMetrics));

            // Update baselines slowly (exponential moving average)
            updateBaseline(jvm.getPid(), currentMetrics, baseline);
        }

        // Clean up old dedup entries
        recentIncidents.entrySet().removeIf(e -> e.getValue().plusSeconds(INCIDENT_DEDUP_SECONDS * 2).isBefore(now));

        log.debug("SRE Agent scan #{}: {} JVMs, {} total incidents",
                totalScans.get(), jvms.size(), incidents.size());
    }

    private Map<String, Double> collectMetrics(JvmProcess jvm) {
        Map<String, Double> metrics = new HashMap<>();
        metrics.put("heapPercent", jvm.getHeapUsagePercent());
        metrics.put("threadCount", (double) jvm.getThreadCount());
        metrics.put("cpuPercent", jvm.getCpuPercent());
        metrics.put("gcCount", (double) jvm.getGcCollectionCount());
        metrics.put("heapUsedBytes", (double) jvm.getHeapUsedBytes());
        return metrics;
    }

    private void detectHeapGrowth(JvmProcess jvm, Map<String, Double> current,
                                   Map<String, Double> prev, Instant now) {
        if (prev == null) return;
        double currentHeap = current.getOrDefault("heapPercent", 0.0);
        double prevHeap = prev.getOrDefault("heapPercent", 0.0);
        double growthRate = currentHeap - prevHeap;

        if (growthRate > HEAP_GROWTH_RATE_THRESHOLD && currentHeap > 50) {
            String severity = currentHeap > 90 ? "CRITICAL" : currentHeap > 75 ? "HIGH" : "MEDIUM";
            createIncident(jvm, "HEAP_GROWTH", severity,
                    "Rapid Heap Growth Detected",
                    String.format("Heap usage increased by %.1f%% in 30s (%.1f%% -> %.1f%%). " +
                            "Growth rate exceeds threshold of %.1f%%/scan. " +
                            "Possible memory leak or excessive object allocation.",
                            growthRate, prevHeap, currentHeap, HEAP_GROWTH_RATE_THRESHOLD),
                    "Investigate top-growing classes via heap histogram diff. " +
                            "Check for unclosed resources, growing collections, or cache eviction issues.",
                    now);
        }
    }

    private void detectThreadSpike(JvmProcess jvm, Map<String, Double> current,
                                    Map<String, Double> prev, Instant now) {
        if (prev == null) return;
        double currentThreads = current.getOrDefault("threadCount", 0.0);
        double prevThreads = prev.getOrDefault("threadCount", 0.0);
        double spike = currentThreads - prevThreads;

        if (spike > THREAD_SPIKE_THRESHOLD) {
            String severity = currentThreads > 500 ? "HIGH" : "MEDIUM";
            createIncident(jvm, "THREAD_SPIKE", severity,
                    "Thread Count Spike",
                    String.format("Thread count jumped by %.0f in 30s (%.0f -> %.0f). " +
                            "Threshold: %.0f threads. Possible thread pool exhaustion or runaway thread creation.",
                            spike, prevThreads, currentThreads, THREAD_SPIKE_THRESHOLD),
                    "Review thread dump for blocked/waiting threads. " +
                            "Check thread pool configurations and async task submissions.",
                    now);
        }
    }

    private void detectGcFrequencyIncrease(JvmProcess jvm, Map<String, Double> current,
                                            Map<String, Double> prev, Instant now) {
        if (prev == null) return;
        double currentGc = current.getOrDefault("gcCount", 0.0);
        double prevGc = prev.getOrDefault("gcCount", 0.0);
        double gcJump = currentGc - prevGc;

        if (gcJump > GC_FREQUENCY_THRESHOLD) {
            String severity = gcJump > 50 ? "HIGH" : "MEDIUM";
            createIncident(jvm, "GC_FREQUENCY", severity,
                    "GC Frequency Spike",
                    String.format("GC collection count increased by %.0f in 30s (%.0f -> %.0f). " +
                            "High GC frequency indicates memory pressure.",
                            gcJump, prevGc, currentGc),
                    "Reduce short-lived object allocations. Consider tuning GC parameters " +
                            "or increasing heap size.",
                    now);
        }
    }

    private void detectSustainedHighCpu(JvmProcess jvm, Map<String, Double> current, Instant now) {
        double cpuPercent = current.getOrDefault("cpuPercent", 0.0);
        if (cpuPercent > CPU_SUSTAINED_THRESHOLD) {
            String severity = cpuPercent > 95 ? "CRITICAL" : "HIGH";
            createIncident(jvm, "HIGH_CPU", severity,
                    "Sustained High CPU Usage",
                    String.format("CPU usage at %.1f%% exceeds threshold of %.1f%%. " +
                            "Sustained high CPU can degrade responsiveness and throughput.",
                            cpuPercent, CPU_SUSTAINED_THRESHOLD),
                    "Capture a CPU profile (JFR) to identify hot methods. " +
                            "Check for tight loops, regex catastrophic backtracking, or excessive logging.",
                    now);
        }
    }

    private void createIncident(JvmProcess jvm, String anomalyType, String severity,
                                 String title, String description, String recommendedFix,
                                 Instant now) {
        // Dedup check
        String dedupKey = anomalyType + "-" + jvm.getPid();
        Instant lastTime = recentIncidents.get(dedupKey);
        if (lastTime != null && lastTime.plusSeconds(INCIDENT_DEDUP_SECONDS).isAfter(now)) {
            return; // Skip duplicate
        }

        String id = UUID.randomUUID().toString().substring(0, 8);
        List<SreIncident.IncidentEvent> timeline = new ArrayList<>();
        timeline.add(SreIncident.IncidentEvent.builder()
                .timestamp(now.toString())
                .type("DETECTED")
                .message("Anomaly detected: " + title)
                .build());
        timeline.add(SreIncident.IncidentEvent.builder()
                .timestamp(now.toString())
                .type("DIAGNOSIS_COMPLETE")
                .message("Auto-diagnosis: " + description)
                .build());

        SreIncident incident = SreIncident.builder()
                .id(id)
                .pid(jvm.getPid())
                .processName(jvm.getDisplayName())
                .status("OPEN")
                .severity(severity)
                .anomalyType(anomalyType)
                .title(title)
                .description(description)
                .diagnosis(description)
                .recommendedFix(recommendedFix)
                .affectedJvm(jvm.getDisplayName() + " (PID " + jvm.getPid() + ")")
                .createdAt(now.toString())
                .updatedAt(now.toString())
                .timeline(timeline)
                .build();

        incidents.add(0, incident); // newest first
        incidentMap.put(id, incident);
        recentIncidents.put(dedupKey, now);
        anomaliesDetected.incrementAndGet();

        // Cap incidents list
        while (incidents.size() > 200) {
            SreIncident removed = incidents.remove(incidents.size() - 1);
            incidentMap.remove(removed.getId());
        }

        log.info("SRE Incident created: [{}] {} - {} on {} (PID {})",
                severity, anomalyType, title, jvm.getDisplayName(), jvm.getPid());

        // Push notification
        notificationService.addNotification("SRE_INCIDENT", title,
                String.format("[%s] %s on %s (PID %d)", severity, title,
                        jvm.getDisplayName(), jvm.getPid()), severity);

        // Send to integrations based on escalation policy
        alertIntegrationService.dispatchIncident(incident);
    }

    private void updateBaseline(int pid, Map<String, Double> current, Map<String, Double> baseline) {
        double alpha = 0.1; // slow adaptation
        for (Map.Entry<String, Double> entry : current.entrySet()) {
            double base = baseline.getOrDefault(entry.getKey(), entry.getValue());
            double updated = base * (1 - alpha) + entry.getValue() * alpha;
            baseline.put(entry.getKey(), updated);
        }
    }

    // Public API methods

    public List<SreIncident> getIncidents() {
        return new ArrayList<>(incidents);
    }

    public Optional<SreIncident> getIncident(String id) {
        return Optional.ofNullable(incidentMap.get(id));
    }

    public SreIncident resolveIncident(String id) {
        SreIncident incident = incidentMap.get(id);
        if (incident == null) {
            throw new RuntimeException("Incident not found: " + id);
        }
        Instant now = Instant.now();
        incident.setStatus("RESOLVED");
        incident.setResolvedAt(now.toString());
        incident.setUpdatedAt(now.toString());
        incident.getTimeline().add(SreIncident.IncidentEvent.builder()
                .timestamp(now.toString())
                .type("RESOLVED")
                .message("Incident resolved by operator.")
                .build());
        return incident;
    }

    public Map<String, Object> getStatus() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("running", running.get());
        status.put("totalScans", totalScans.get());
        status.put("anomaliesDetected", anomaliesDetected.get());
        status.put("lastScanTime", lastScanEpochMs.get() > 0
                ? Instant.ofEpochMilli(lastScanEpochMs.get()).toString() : null);
        long openCount = incidents.stream().filter(i -> "OPEN".equals(i.getStatus())).count();
        status.put("openIncidents", openCount);
        status.put("totalIncidents", incidents.size());
        return status;
    }

    public boolean toggle() {
        boolean newState = !running.get();
        running.set(newState);
        log.info("SRE Agent {}", newState ? "started" : "paused");
        return newState;
    }

    public boolean isRunning() {
        return running.get();
    }
}
