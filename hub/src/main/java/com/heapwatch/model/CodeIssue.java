package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;

/**
 * Represents an identified code issue mapped to source code with severity ranking.
 */
@Data
@Builder
public class CodeIssue {
    private String id;
    private String severity; // CRITICAL, HIGH, MEDIUM, LOW
    private String category; // MEMORY, CPU, THREADS, GC, ALGORITHM
    private String title;
    private String description;
    private String method; // fully qualified method name
    private String filePath; // source file path in repo
    private int lineStart;
    private int lineEnd;
    private String sourceSnippet; // relevant source code
    private double cpuPercent; // profiling metric
    private long allocationBytes; // profiling metric
    private int threadCount; // profiling metric
    private long gcPauseMs; // profiling metric
    private int impactScore; // 1-10

    // AI analysis fields
    private String rootCause;
    private String suggestedFix;
    private String beforeCode;
    private String afterCode;
    private String estimatedImpact;
    private boolean analyzed;

    // PR fields
    private String prBranch;
    private String prTitle;
    private String prBody;
    private String prDiff;
    private boolean prCreated;
}
