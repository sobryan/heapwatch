package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;

/**
 * Structured diagnosis report returned by the one-click diagnose endpoint.
 */
@Data
@Builder
public class DiagnosisReport {
    private int pid;
    private String processName;
    private String timestamp;
    private int healthScore; // 0-100
    private String healthAssessment;
    private List<DiagnosisIssue> issues;
    private List<CodeRecommendation> recommendations;
    private JvmSnapshot snapshot;

    @Data
    @Builder
    public static class DiagnosisIssue {
        private String severity; // CRITICAL, WARNING, INFO
        private String category; // MEMORY, CPU, THREADS, GC
        private String title;
        private String description;
        private String affectedMethod;
        private int impactScore; // 1-10
    }

    @Data
    @Builder
    public static class CodeRecommendation {
        private String title;
        private String description;
        private String affectedMethod;
        private String suggestedFix;
        private String estimatedImpact;
    }

    @Data
    @Builder
    public static class JvmSnapshot {
        private long heapUsedBytes;
        private long heapMaxBytes;
        private double heapUsagePercent;
        private int threadCount;
        private double cpuPercent;
        private String status;
        private long gcCollectionCount;
        private long gcCollectionTimeMs;
    }
}
