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
 * Checks JVM metrics against configurable thresholds and fires alerts.
 * Default rules: heap > 85% = WARNING, heap > 95% = CRITICAL, threads > 500 = WARNING.
 */
@Slf4j
@Service
public class AlertService {

    private static final int MAX_ALERTS = 500;

    private final JvmDiscoveryService discoveryService;
    private final NotificationService notificationService;
    private final AlertIntegrationService alertIntegrationService;

    private final List<Map<String, Object>> alertRules = new CopyOnWriteArrayList<>();
    private final List<Map<String, Object>> triggeredAlerts = new CopyOnWriteArrayList<>();

    // Track last alert time per rule+pid to avoid flooding
    private final Map<String, Instant> lastAlertTime = new ConcurrentHashMap<>();

    public AlertService(JvmDiscoveryService discoveryService,
                        NotificationService notificationService,
                        AlertIntegrationService alertIntegrationService) {
        this.discoveryService = discoveryService;
        this.notificationService = notificationService;
        this.alertIntegrationService = alertIntegrationService;
        initDefaultRules();
    }

    private void initDefaultRules() {
        alertRules.add(createRule("heap-warning", "Heap Usage Warning",
                "heapPercent", ">", 85.0, "WARNING"));
        alertRules.add(createRule("heap-critical", "Heap Usage Critical",
                "heapPercent", ">", 95.0, "CRITICAL"));
        alertRules.add(createRule("threads-warning", "High Thread Count",
                "threadCount", ">", 500.0, "WARNING"));
    }

    private Map<String, Object> createRule(String id, String name, String metric,
                                            String operator, double threshold, String severity) {
        Map<String, Object> rule = new LinkedHashMap<>();
        rule.put("id", id);
        rule.put("name", name);
        rule.put("metric", metric);
        rule.put("operator", operator);
        rule.put("threshold", threshold);
        rule.put("severity", severity);
        rule.put("enabled", true);
        return rule;
    }

    @Scheduled(fixedRate = 15000)
    public void evaluateRules() {
        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        Instant now = Instant.now();

        for (JvmProcess jvm : jvms) {
            for (Map<String, Object> rule : alertRules) {
                if (!Boolean.TRUE.equals(rule.get("enabled"))) continue;

                String metric = (String) rule.get("metric");
                String operator = (String) rule.get("operator");
                double threshold = ((Number) rule.get("threshold")).doubleValue();
                String severity = (String) rule.get("severity");
                String ruleId = (String) rule.get("id");
                String ruleName = (String) rule.get("name");

                double value = getMetricValue(jvm, metric);
                boolean triggered = evaluate(value, operator, threshold);

                if (triggered) {
                    String key = ruleId + "-" + jvm.getPid();
                    Instant last = lastAlertTime.get(key);
                    // Suppress duplicates within 60 seconds
                    if (last != null && last.plusSeconds(60).isAfter(now)) continue;

                    Map<String, Object> alert = new LinkedHashMap<>();
                    alert.put("id", UUID.randomUUID().toString().substring(0, 8));
                    alert.put("ruleId", ruleId);
                    alert.put("ruleName", ruleName);
                    alert.put("pid", jvm.getPid());
                    alert.put("processName", jvm.getDisplayName());
                    alert.put("metric", metric);
                    alert.put("value", value);
                    alert.put("threshold", threshold);
                    alert.put("severity", severity);
                    alert.put("timestamp", now.toString());
                    alert.put("message", String.format("%s: %s = %.1f (threshold: %.1f) on %s (PID %d)",
                            severity, metric, value, threshold, jvm.getDisplayName(), jvm.getPid()));

                    triggeredAlerts.add(0, alert); // newest first
                    lastAlertTime.put(key, now);
                    log.info("Alert triggered: {}", alert.get("message"));

                    // Push to notification center
                    notificationService.addNotification("ALERT", ruleName,
                            (String) alert.get("message"), severity);

                    // Dispatch to integration channels based on escalation
                    dispatchAlertToIntegrations(alert);

                    // Evict old alerts
                    while (triggeredAlerts.size() > MAX_ALERTS) {
                        triggeredAlerts.remove(triggeredAlerts.size() - 1);
                    }
                }
            }
        }
    }

    private double getMetricValue(JvmProcess jvm, String metric) {
        return switch (metric) {
            case "heapPercent" -> jvm.getHeapUsagePercent();
            case "threadCount" -> jvm.getThreadCount();
            case "cpuPercent" -> jvm.getCpuPercent();
            case "gcCount" -> jvm.getGcCollectionCount();
            default -> 0.0;
        };
    }

    private boolean evaluate(double value, String operator, double threshold) {
        return switch (operator) {
            case ">" -> value > threshold;
            case ">=" -> value >= threshold;
            case "<" -> value < threshold;
            case "<=" -> value <= threshold;
            case "==" -> Math.abs(value - threshold) < 0.001;
            default -> false;
        };
    }

    public List<Map<String, Object>> getAlerts() {
        return new ArrayList<>(triggeredAlerts);
    }

    public int getActiveAlertCount() {
        // Count alerts from the last 5 minutes
        Instant cutoff = Instant.now().minusSeconds(300);
        return (int) triggeredAlerts.stream()
                .filter(a -> {
                    String ts = (String) a.get("timestamp");
                    return ts != null && Instant.parse(ts).isAfter(cutoff);
                })
                .count();
    }

    public List<Map<String, Object>> getRules() {
        return new ArrayList<>(alertRules);
    }

    public Map<String, Object> addRule(Map<String, Object> rule) {
        String id = "custom-" + UUID.randomUUID().toString().substring(0, 6);
        rule.put("id", id);
        if (!rule.containsKey("enabled")) rule.put("enabled", true);
        alertRules.add(rule);
        return rule;
    }

    public void clearAlerts() {
        triggeredAlerts.clear();
    }

    /**
     * Dispatch alert to integration channels using escalation policy:
     * LOW/WARNING -> webhook only, MEDIUM -> webhook+email,
     * HIGH/CRITICAL -> all channels.
     */
    private void dispatchAlertToIntegrations(Map<String, Object> alert) {
        try {
            // Build a lightweight SreIncident-like object for the integration service
            com.heapwatch.model.SreIncident incident = com.heapwatch.model.SreIncident.builder()
                    .id((String) alert.get("id"))
                    .pid(((Number) alert.get("pid")).intValue())
                    .processName((String) alert.get("processName"))
                    .severity(mapAlertSeverityToEscalation((String) alert.get("severity")))
                    .anomalyType("ALERT_RULE")
                    .title((String) alert.get("ruleName"))
                    .description((String) alert.get("message"))
                    .recommendedFix("Check alert rule: " + alert.get("ruleName"))
                    .affectedJvm(alert.get("processName") + " (PID " + alert.get("pid") + ")")
                    .createdAt((String) alert.get("timestamp"))
                    .build();
            alertIntegrationService.dispatchIncident(incident);
        } catch (Exception e) {
            // Don't let integration failures break alerting
        }
    }

    private String mapAlertSeverityToEscalation(String alertSeverity) {
        return switch (alertSeverity) {
            case "CRITICAL" -> "CRITICAL";
            case "WARNING" -> "MEDIUM";
            default -> "LOW";
        };
    }
}
