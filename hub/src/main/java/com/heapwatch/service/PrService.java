package com.heapwatch.service;

import com.heapwatch.model.CodeIssue;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;

/**
 * Generates PR plans for code fixes based on identified issues.
 * Creates branch name, commit message, PR title/body with profiling evidence.
 * Currently generates simulated PRs (stored in-memory) since we may not have
 * write access to target repos.
 */
@Slf4j
@Service
public class PrService {

    private final IssueRankingService issueRankingService;
    private final Map<String, Map<String, Object>> prPlans = new LinkedHashMap<>();

    public PrService(IssueRankingService issueRankingService) {
        this.issueRankingService = issueRankingService;
    }

    /**
     * Create a PR plan for a specific issue.
     * Generates all PR content but stores it as a plan rather than actually creating a GitHub PR.
     */
    public Map<String, Object> createPrPlan(String issueId) {
        Optional<CodeIssue> optIssue = issueRankingService.getIssue(issueId);
        if (optIssue.isEmpty()) {
            throw new RuntimeException("Issue not found: " + issueId);
        }

        CodeIssue issue = optIssue.get();
        if (!issue.isAnalyzed()) {
            throw new RuntimeException("Issue must be analyzed by AI before creating a PR. Call POST /api/issues/" + issueId + "/analyze first.");
        }

        String branchName = generateBranchName(issue);
        String prTitle = generatePrTitle(issue);
        String prBody = generatePrBody(issue);
        String commitMessage = generateCommitMessage(issue);
        String diff = generateDiff(issue);

        // Update the issue with PR info
        issue.setPrBranch(branchName);
        issue.setPrTitle(prTitle);
        issue.setPrBody(prBody);
        issue.setPrDiff(diff);
        issue.setPrCreated(true);
        issueRankingService.updateIssue(issue);

        Map<String, Object> plan = new LinkedHashMap<>();
        plan.put("issueId", issueId);
        plan.put("status", "PLANNED");
        plan.put("branch", branchName);
        plan.put("prTitle", prTitle);
        plan.put("prBody", prBody);
        plan.put("commitMessage", commitMessage);
        plan.put("diff", diff);
        plan.put("filePath", issue.getFilePath());
        plan.put("severity", issue.getSeverity());
        plan.put("category", issue.getCategory());
        plan.put("createdAt", Instant.now().toString());
        plan.put("beforeCode", issue.getBeforeCode());
        plan.put("afterCode", issue.getAfterCode());
        plan.put("estimatedImpact", issue.getEstimatedImpact());

        String prId = "PR-" + issueId;
        prPlans.put(prId, plan);

        log.info("Created PR plan {} for issue {}: {}", prId, issueId, prTitle);
        return plan;
    }

    /**
     * Get all PR plans.
     */
    public List<Map<String, Object>> getAllPrPlans() {
        return new ArrayList<>(prPlans.values());
    }

    /**
     * Get a specific PR plan.
     */
    public Optional<Map<String, Object>> getPrPlan(String prId) {
        return Optional.ofNullable(prPlans.get(prId));
    }

    // --- PR content generators ---

    private String generateBranchName(CodeIssue issue) {
        String category = issue.getCategory().toLowerCase();
        String method = issue.getMethod();
        String simpleName = method.contains(".")
                ? method.substring(method.lastIndexOf('.') + 1)
                : method;
        simpleName = simpleName.replaceAll("[^a-zA-Z0-9]", "-").toLowerCase();
        return String.format("heapwatch/fix-%s-%s", category, simpleName);
    }

    private String generatePrTitle(CodeIssue issue) {
        String prefix;
        switch (issue.getSeverity()) {
            case "CRITICAL": prefix = "fix(critical)"; break;
            case "HIGH": prefix = "perf"; break;
            case "MEDIUM": prefix = "refactor"; break;
            default: prefix = "chore"; break;
        }
        return String.format("%s: %s", prefix, issue.getTitle().toLowerCase());
    }

    private String generatePrBody(CodeIssue issue) {
        StringBuilder body = new StringBuilder();

        body.append("## HeapWatch Automated Fix\n\n");

        // Severity badge
        body.append("**Severity**: ").append(issue.getSeverity())
            .append(" | **Category**: ").append(issue.getCategory())
            .append(" | **Impact Score**: ").append(issue.getImpactScore()).append("/10\n\n");

        // Issue description
        body.append("### Problem\n\n");
        body.append(issue.getDescription()).append("\n\n");

        // Root cause
        if (issue.getRootCause() != null && !issue.getRootCause().isEmpty()) {
            body.append("### Root Cause\n\n");
            body.append(issue.getRootCause()).append("\n\n");
        }

        // Profiling evidence
        body.append("### Profiling Evidence\n\n");
        body.append("| Metric | Value |\n");
        body.append("|--------|-------|\n");
        if (issue.getCpuPercent() > 0) {
            body.append(String.format("| CPU Usage | %.1f%% |\n", issue.getCpuPercent()));
        }
        if (issue.getAllocationBytes() > 0) {
            body.append(String.format("| Allocation | %s |\n", formatBytes(issue.getAllocationBytes())));
        }
        if (issue.getThreadCount() > 0) {
            body.append(String.format("| Thread Count | %d |\n", issue.getThreadCount()));
        }
        if (issue.getGcPauseMs() > 0) {
            body.append(String.format("| GC Pause | %dms |\n", issue.getGcPauseMs()));
        }
        body.append("\n");

        // Before/after code
        if (issue.getBeforeCode() != null && issue.getAfterCode() != null) {
            body.append("### Before\n\n");
            body.append("```java\n").append(issue.getBeforeCode()).append("\n```\n\n");
            body.append("### After\n\n");
            body.append("```java\n").append(issue.getAfterCode()).append("\n```\n\n");
        }

        // Estimated impact
        if (issue.getEstimatedImpact() != null) {
            body.append("### Estimated Impact\n\n");
            body.append(issue.getEstimatedImpact()).append("\n\n");
        }

        body.append("---\n");
        body.append("*Generated by [HeapWatch](https://heapwatch-hub-1018998956407.us-central1.run.app) - JVM Performance Monitor*\n");

        return body.toString();
    }

    private String generateCommitMessage(CodeIssue issue) {
        return String.format("fix(%s): %s\n\nIdentified by HeapWatch profiler.\nSeverity: %s, Impact: %d/10\n\n%s",
                issue.getCategory().toLowerCase(),
                issue.getTitle().toLowerCase(),
                issue.getSeverity(),
                issue.getImpactScore(),
                issue.getRootCause() != null ? issue.getRootCause() : "");
    }

    private String generateDiff(CodeIssue issue) {
        if (issue.getBeforeCode() == null || issue.getAfterCode() == null) {
            return "No code diff available. Run AI analysis first.";
        }

        StringBuilder diff = new StringBuilder();
        diff.append(String.format("--- a/%s\n", issue.getFilePath()));
        diff.append(String.format("+++ b/%s\n", issue.getFilePath()));
        diff.append(String.format("@@ -%d,%d +%d,%d @@\n",
                issue.getLineStart(), countLines(issue.getBeforeCode()),
                issue.getLineStart(), countLines(issue.getAfterCode())));

        for (String line : issue.getBeforeCode().split("\n")) {
            diff.append("-").append(line).append("\n");
        }
        for (String line : issue.getAfterCode().split("\n")) {
            diff.append("+").append(line).append("\n");
        }

        return diff.toString();
    }

    private int countLines(String text) {
        if (text == null || text.isEmpty()) return 0;
        return text.split("\n").length;
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024 * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
