package com.heapwatch.service;

import com.heapwatch.model.CodeIssue;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Ranks identified code issues by severity using profiling metrics and heuristics.
 *
 * Severity Levels:
 *   CRITICAL: memory leak pattern, deadlock, >95% heap
 *   HIGH: CPU hotspot >30%, thread contention >5 threads, GC pause >500ms
 *   MEDIUM: O(n^2) algorithm, unnecessary allocation, pool saturation
 *   LOW: minor optimization, style improvement
 */
@Slf4j
@Service
public class IssueRankingService {

    private final Map<String, CodeIssue> issueStore = new ConcurrentHashMap<>();
    private final AtomicInteger idCounter = new AtomicInteger(1);

    /**
     * Rank a list of issues by severity and impact score.
     */
    public List<CodeIssue> rankIssues(List<CodeIssue> issues) {
        // Assign IDs and compute severity
        for (CodeIssue issue : issues) {
            if (issue.getId() == null || issue.getId().isEmpty()) {
                issue.setId("ISSUE-" + idCounter.getAndIncrement());
            }

            // Re-compute severity based on metrics
            String computedSeverity = computeSeverity(issue);
            issue.setSeverity(computedSeverity);

            // Compute impact score if not set
            if (issue.getImpactScore() == 0) {
                issue.setImpactScore(computeImpactScore(issue));
            }

            // Store for later retrieval
            issueStore.put(issue.getId(), issue);
        }

        // Sort: CRITICAL first, then HIGH, MEDIUM, LOW. Within same severity, by impact score desc.
        issues.sort((a, b) -> {
            int sevCompare = severityWeight(b.getSeverity()) - severityWeight(a.getSeverity());
            if (sevCompare != 0) return sevCompare;
            return Integer.compare(b.getImpactScore(), a.getImpactScore());
        });

        return issues;
    }

    /**
     * Get all stored issues, ranked.
     */
    public List<CodeIssue> getAllIssues() {
        List<CodeIssue> all = new ArrayList<>(issueStore.values());
        all.sort((a, b) -> {
            int sevCompare = severityWeight(b.getSeverity()) - severityWeight(a.getSeverity());
            if (sevCompare != 0) return sevCompare;
            return Integer.compare(b.getImpactScore(), a.getImpactScore());
        });
        return all;
    }

    /**
     * Get a single issue by ID.
     */
    public Optional<CodeIssue> getIssue(String id) {
        return Optional.ofNullable(issueStore.get(id));
    }

    /**
     * Store an issue (e.g., after AI analysis).
     */
    public void updateIssue(CodeIssue issue) {
        issueStore.put(issue.getId(), issue);
    }

    /**
     * Clear all stored issues.
     */
    public void clearIssues() {
        issueStore.clear();
    }

    /**
     * Compute severity based on metrics.
     */
    private String computeSeverity(CodeIssue issue) {
        String category = issue.getCategory();

        // CRITICAL conditions
        if ("MEMORY".equals(category) && issue.getDescription() != null &&
            (issue.getDescription().contains("leak") || issue.getDescription().contains(">95%"))) {
            return "CRITICAL";
        }
        if ("THREADS".equals(category) && issue.getDescription() != null &&
            issue.getDescription().toLowerCase().contains("deadlock")) {
            return "CRITICAL";
        }
        if (issue.getAllocationBytes() > 0) {
            // Estimate heap percentage
            double heapPercent = extractHeapPercent(issue.getDescription());
            if (heapPercent > 95) return "CRITICAL";
        }

        // HIGH conditions
        if ("CPU".equals(category) && issue.getCpuPercent() > 30) {
            return "HIGH";
        }
        if ("THREADS".equals(category) && issue.getThreadCount() > 5) {
            return "HIGH";
        }
        if ("GC".equals(category) && issue.getGcPauseMs() > 500) {
            return "HIGH";
        }

        // MEDIUM conditions
        if ("CPU".equals(category) || "ALGORITHM".equals(category)) {
            return "MEDIUM";
        }
        if ("MEMORY".equals(category) && issue.getAllocationBytes() > 0) {
            return "MEDIUM";
        }
        if ("THREADS".equals(category) && issue.getThreadCount() > 0) {
            return "MEDIUM";
        }

        // Default based on existing severity
        if (issue.getSeverity() != null && !issue.getSeverity().isEmpty()) {
            return issue.getSeverity();
        }

        return "LOW";
    }

    private int computeImpactScore(CodeIssue issue) {
        int score = 5; // baseline

        switch (issue.getSeverity()) {
            case "CRITICAL": score += 4; break;
            case "HIGH": score += 2; break;
            case "MEDIUM": score += 0; break;
            case "LOW": score -= 2; break;
        }

        // Boost for specific metrics
        if (issue.getCpuPercent() > 80) score += 1;
        if (issue.getGcPauseMs() > 2000) score += 1;
        if (issue.getThreadCount() > 10) score += 1;

        return Math.min(10, Math.max(1, score));
    }

    private int severityWeight(String severity) {
        switch (severity) {
            case "CRITICAL": return 4;
            case "HIGH": return 3;
            case "MEDIUM": return 2;
            case "LOW": return 1;
            default: return 0;
        }
    }

    private double extractHeapPercent(String description) {
        if (description == null) return 0;
        try {
            int idx = description.indexOf('%');
            if (idx > 0) {
                int start = idx - 1;
                while (start > 0 && (Character.isDigit(description.charAt(start)) ||
                       description.charAt(start) == '.')) {
                    start--;
                }
                return Double.parseDouble(description.substring(start + 1, idx));
            }
        } catch (NumberFormatException e) {
            // ignore
        }
        return 0;
    }
}
