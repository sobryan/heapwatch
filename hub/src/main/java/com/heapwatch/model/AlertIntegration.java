package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

import java.util.Map;

/**
 * Configurable notification channel for alert delivery.
 */
@Data
@Builder
public class AlertIntegration {
    private String id;
    private String name;
    private String type; // WEBHOOK, GITHUB_ISSUES, EMAIL
    private Map<String, String> config; // type-specific config
    private boolean enabled;
    private String createdAt;
    private String lastTestedAt;
    private String lastTestResult;
}
