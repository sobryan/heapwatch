package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Incident detected by the SRE Agent autonomous monitoring loop.
 */
@Data
@Builder
public class SreIncident {
    private String id;
    private int pid;
    private String processName;
    private String status; // OPEN, INVESTIGATING, RESOLVED
    private String severity; // LOW, MEDIUM, HIGH, CRITICAL
    private String anomalyType; // HEAP_GROWTH, THREAD_SPIKE, GC_FREQUENCY, HIGH_CPU
    private String title;
    private String description;
    private String diagnosis;
    private String recommendedFix;
    private String affectedJvm;
    private String createdAt;
    private String updatedAt;
    private String resolvedAt;
    private List<IncidentEvent> timeline;

    @Data
    @Builder
    public static class IncidentEvent {
        private String timestamp;
        private String type; // DETECTED, INVESTIGATING, DIAGNOSIS_COMPLETE, RESOLVED
        private String message;
    }
}
