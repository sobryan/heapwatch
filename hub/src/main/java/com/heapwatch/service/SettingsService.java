package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages application settings: discovery interval, alert thresholds,
 * JFR defaults, and AI model configuration.
 */
@Slf4j
@Service
public class SettingsService {

    @Value("${heapwatch.discovery.interval-seconds:15}")
    private int defaultDiscoveryInterval;

    @Value("${heapwatch.ai.model:claude-sonnet-4-20250514}")
    private String defaultAiModel;

    @Value("${heapwatch.jfr.output-dir:/tmp/heapwatch-jfr}")
    private String defaultJfrOutputDir;

    private final Map<String, Object> settings = new ConcurrentHashMap<>();

    /**
     * Gets the current settings, merging defaults with any overrides.
     */
    public Map<String, Object> getSettings() {
        Map<String, Object> result = new LinkedHashMap<>();

        result.put("discoveryIntervalSeconds", settings.getOrDefault("discoveryIntervalSeconds", defaultDiscoveryInterval));
        result.put("aiModel", settings.getOrDefault("aiModel", defaultAiModel));
        result.put("aiEnabled", settings.getOrDefault("aiEnabled", true));
        result.put("jfrDefaultDurationSeconds", settings.getOrDefault("jfrDefaultDurationSeconds", 30));
        result.put("jfrOutputDir", settings.getOrDefault("jfrOutputDir", defaultJfrOutputDir));

        // Alert thresholds
        result.put("heapWarningThreshold", settings.getOrDefault("heapWarningThreshold", 85.0));
        result.put("heapCriticalThreshold", settings.getOrDefault("heapCriticalThreshold", 95.0));
        result.put("threadWarningThreshold", settings.getOrDefault("threadWarningThreshold", 500));

        return result;
    }

    /**
     * Updates settings with the provided values.
     */
    public Map<String, Object> updateSettings(Map<String, Object> updates) {
        for (Map.Entry<String, Object> entry : updates.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();

            switch (key) {
                case "discoveryIntervalSeconds" -> {
                    int val = ((Number) value).intValue();
                    if (val >= 5 && val <= 300) {
                        settings.put(key, val);
                    }
                }
                case "aiModel" -> settings.put(key, value.toString());
                case "aiEnabled" -> settings.put(key, Boolean.valueOf(value.toString()));
                case "jfrDefaultDurationSeconds" -> {
                    int val = ((Number) value).intValue();
                    if (val >= 5 && val <= 600) {
                        settings.put(key, val);
                    }
                }
                case "jfrOutputDir" -> settings.put(key, value.toString());
                case "heapWarningThreshold" -> {
                    double val = ((Number) value).doubleValue();
                    if (val >= 0 && val <= 100) {
                        settings.put(key, val);
                    }
                }
                case "heapCriticalThreshold" -> {
                    double val = ((Number) value).doubleValue();
                    if (val >= 0 && val <= 100) {
                        settings.put(key, val);
                    }
                }
                case "threadWarningThreshold" -> {
                    int val = ((Number) value).intValue();
                    if (val >= 1) {
                        settings.put(key, val);
                    }
                }
                default -> log.warn("Unknown setting key: {}", key);
            }
        }
        log.info("Settings updated: {}", settings);
        return getSettings();
    }
}
