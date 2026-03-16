package com.heapwatch.service;

import com.heapwatch.model.AlertIntegration;
import com.heapwatch.model.SreIncident;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import com.google.gson.Gson;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.TimeUnit;

/**
 * Manages alert notification channels (webhooks, GitHub Issues, email)
 * and dispatches alerts/incidents to configured channels based on escalation policy.
 *
 * Escalation policy:
 *   LOW    -> webhook only
 *   MEDIUM -> webhook + email
 *   HIGH   -> all channels
 *   CRITICAL -> all channels + auto-create PR flag
 */
@Slf4j
@Service
public class AlertIntegrationService {

    private final List<AlertIntegration> integrations = new CopyOnWriteArrayList<>();
    private final Map<String, AlertIntegration> integrationMap = new ConcurrentHashMap<>();
    private final Gson gson = new Gson();
    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build();

    // Dedup: channel+incident -> last sent time
    private final Map<String, Instant> lastSentTimes = new ConcurrentHashMap<>();
    private static final int DEDUP_WINDOW_SECONDS = 300; // 5 minutes

    public List<AlertIntegration> getIntegrations() {
        return new ArrayList<>(integrations);
    }

    public AlertIntegration getIntegration(String id) {
        return integrationMap.get(id);
    }

    public AlertIntegration addIntegration(AlertIntegration integration) {
        String id = UUID.randomUUID().toString().substring(0, 8);
        integration.setId(id);
        integration.setCreatedAt(Instant.now().toString());
        integrations.add(integration);
        integrationMap.put(id, integration);
        log.info("Alert integration added: {} ({})", integration.getName(), integration.getType());
        return integration;
    }

    public AlertIntegration updateIntegration(String id, AlertIntegration updates) {
        AlertIntegration existing = integrationMap.get(id);
        if (existing == null) {
            throw new RuntimeException("Integration not found: " + id);
        }
        if (updates.getName() != null) existing.setName(updates.getName());
        if (updates.getType() != null) existing.setType(updates.getType());
        if (updates.getConfig() != null) existing.setConfig(updates.getConfig());
        existing.setEnabled(updates.isEnabled());
        return existing;
    }

    public boolean deleteIntegration(String id) {
        AlertIntegration removed = integrationMap.remove(id);
        if (removed != null) {
            integrations.remove(removed);
            log.info("Alert integration removed: {} ({})", removed.getName(), removed.getType());
            return true;
        }
        return false;
    }

    public Map<String, Object> testIntegration(String id) {
        AlertIntegration integration = integrationMap.get(id);
        if (integration == null) {
            throw new RuntimeException("Integration not found: " + id);
        }

        Map<String, Object> testPayload = new LinkedHashMap<>();
        testPayload.put("type", "TEST");
        testPayload.put("title", "HeapWatch Test Notification");
        testPayload.put("message", "This is a test notification from HeapWatch SRE Agent.");
        testPayload.put("severity", "INFO");
        testPayload.put("timestamp", Instant.now().toString());

        Map<String, Object> result = new LinkedHashMap<>();
        try {
            boolean success = sendToChannel(integration, testPayload);
            integration.setLastTestedAt(Instant.now().toString());
            integration.setLastTestResult(success ? "SUCCESS" : "FAILED");
            result.put("success", success);
            result.put("message", success ? "Test notification sent successfully." : "Failed to send test notification.");
        } catch (Exception e) {
            integration.setLastTestedAt(Instant.now().toString());
            integration.setLastTestResult("ERROR: " + e.getMessage());
            result.put("success", false);
            result.put("message", "Error: " + e.getMessage());
        }
        return result;
    }

    /**
     * Dispatch an SRE incident to appropriate channels based on escalation policy.
     */
    public void dispatchIncident(SreIncident incident) {
        String severity = incident.getSeverity();

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "SRE_INCIDENT");
        payload.put("incidentId", incident.getId());
        payload.put("title", incident.getTitle());
        payload.put("description", incident.getDescription());
        payload.put("severity", severity);
        payload.put("anomalyType", incident.getAnomalyType());
        payload.put("affectedJvm", incident.getAffectedJvm());
        payload.put("recommendedFix", incident.getRecommendedFix());
        payload.put("timestamp", incident.getCreatedAt());

        for (AlertIntegration integration : integrations) {
            if (!integration.isEnabled()) continue;

            // Escalation policy
            boolean shouldSend = shouldSendToChannel(severity, integration.getType());
            if (!shouldSend) continue;

            // Dedup check
            String dedupKey = integration.getId() + "-" + incident.getId();
            Instant lastSent = lastSentTimes.get(dedupKey);
            if (lastSent != null && lastSent.plusSeconds(DEDUP_WINDOW_SECONDS).isAfter(Instant.now())) {
                continue;
            }

            try {
                boolean sent = sendToChannel(integration, payload);
                if (sent) {
                    lastSentTimes.put(dedupKey, Instant.now());
                }
            } catch (Exception e) {
                log.warn("Failed to send to integration {}: {}", integration.getName(), e.getMessage());
            }
        }

        // Cleanup old dedup entries
        Instant cutoff = Instant.now().minusSeconds(DEDUP_WINDOW_SECONDS * 2);
        lastSentTimes.entrySet().removeIf(e -> e.getValue().isBefore(cutoff));
    }

    private boolean shouldSendToChannel(String severity, String channelType) {
        return switch (severity) {
            case "LOW" -> "WEBHOOK".equals(channelType);
            case "MEDIUM" -> "WEBHOOK".equals(channelType) || "EMAIL".equals(channelType);
            case "HIGH", "CRITICAL" -> true; // all channels
            default -> "WEBHOOK".equals(channelType);
        };
    }

    private boolean sendToChannel(AlertIntegration integration, Map<String, Object> payload) {
        return switch (integration.getType()) {
            case "WEBHOOK" -> sendWebhook(integration, payload);
            case "GITHUB_ISSUES" -> sendGithubIssue(integration, payload);
            case "EMAIL" -> sendEmail(integration, payload);
            default -> {
                log.warn("Unknown integration type: {}", integration.getType());
                yield false;
            }
        };
    }

    private boolean sendWebhook(AlertIntegration integration, Map<String, Object> payload) {
        String url = integration.getConfig().get("url");
        if (url == null || url.isBlank()) {
            log.warn("Webhook URL not configured for integration: {}", integration.getName());
            return false;
        }

        try {
            RequestBody body = RequestBody.create(
                    gson.toJson(payload), MediaType.parse("application/json"));
            Request request = new Request.Builder().url(url).post(body).build();
            try (Response response = httpClient.newCall(request).execute()) {
                boolean success = response.isSuccessful();
                log.info("Webhook {} to {}: {}", success ? "sent" : "failed",
                        url, response.code());
                return success;
            }
        } catch (Exception e) {
            log.error("Webhook send failed: {}", e.getMessage());
            return false;
        }
    }

    private boolean sendGithubIssue(AlertIntegration integration, Map<String, Object> payload) {
        String repo = integration.getConfig().get("repo");
        String token = integration.getConfig().get("token");
        if (repo == null || token == null) {
            log.warn("GitHub repo/token not configured for integration: {}", integration.getName());
            return false;
        }

        try {
            String title = "[HeapWatch] " + payload.getOrDefault("title", "Alert");
            String body = String.format("## HeapWatch SRE Alert\n\n" +
                    "**Severity:** %s\n" +
                    "**Type:** %s\n" +
                    "**Affected JVM:** %s\n\n" +
                    "### Description\n%s\n\n" +
                    "### Recommended Fix\n%s\n\n" +
                    "*Generated by HeapWatch SRE Agent at %s*",
                    payload.get("severity"), payload.get("anomalyType"),
                    payload.get("affectedJvm"), payload.get("description"),
                    payload.get("recommendedFix"), payload.get("timestamp"));

            Map<String, Object> issueBody = new LinkedHashMap<>();
            issueBody.put("title", title);
            issueBody.put("body", body);
            issueBody.put("labels", List.of("heapwatch", "sre-alert",
                    String.valueOf(payload.getOrDefault("severity", "INFO")).toLowerCase()));

            String apiUrl = "https://api.github.com/repos/" + repo + "/issues";
            RequestBody reqBody = RequestBody.create(
                    gson.toJson(issueBody), MediaType.parse("application/json"));
            Request request = new Request.Builder()
                    .url(apiUrl)
                    .header("Authorization", "Bearer " + token)
                    .header("Accept", "application/vnd.github+json")
                    .post(reqBody)
                    .build();

            try (Response response = httpClient.newCall(request).execute()) {
                boolean success = response.isSuccessful();
                log.info("GitHub issue {} for {}: {}", success ? "created" : "failed",
                        repo, response.code());
                return success;
            }
        } catch (Exception e) {
            log.error("GitHub issue creation failed: {}", e.getMessage());
            return false;
        }
    }

    private boolean sendEmail(AlertIntegration integration, Map<String, Object> payload) {
        // Email integration is configured but actual SMTP sending would require
        // spring-boot-starter-mail. For POC, we log the would-be email.
        String to = integration.getConfig().get("to");
        if (to == null || to.isBlank()) {
            log.warn("Email address not configured for integration: {}", integration.getName());
            return false;
        }

        log.info("EMAIL would be sent to {}: [{}] {} - {}",
                to, payload.get("severity"), payload.get("title"), payload.get("description"));
        // Return true for POC; real implementation would use JavaMailSender
        return true;
    }
}
