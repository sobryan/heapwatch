package com.heapwatch.controller;

import com.heapwatch.model.CodeIssue;
import com.heapwatch.service.AiAdvisorService;
import com.heapwatch.service.IssueRankingService;
import com.heapwatch.service.PrService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/issues")
@CrossOrigin(origins = "*")
public class IssueController {

    private final IssueRankingService issueRankingService;
    private final AiAdvisorService aiAdvisorService;
    private final PrService prService;

    public IssueController(IssueRankingService issueRankingService,
                           AiAdvisorService aiAdvisorService,
                           PrService prService) {
        this.issueRankingService = issueRankingService;
        this.aiAdvisorService = aiAdvisorService;
        this.prService = prService;
    }

    /**
     * Get all identified issues, ranked by severity.
     */
    @GetMapping
    public ResponseEntity<List<CodeIssue>> getAllIssues() {
        return ResponseEntity.ok(issueRankingService.getAllIssues());
    }

    /**
     * Get a single issue by ID with full source context.
     */
    @GetMapping("/{id}")
    public ResponseEntity<CodeIssue> getIssue(@PathVariable String id) {
        return issueRankingService.getIssue(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * AI analysis of a specific issue.
     * Feeds profiling data + source code snippet to Claude and returns
     * root cause explanation, suggested fix, estimated performance impact.
     */
    @PostMapping("/{id}/analyze")
    public ResponseEntity<CodeIssue> analyzeIssue(@PathVariable String id) {
        try {
            CodeIssue analyzed = aiAdvisorService.analyzeCodeIssue(id);
            return ResponseEntity.ok(analyzed);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(null);
        }
    }

    /**
     * Create a PR plan for a specific issue.
     * Generates branch, commit message, PR body with profiling evidence.
     */
    @PostMapping("/{id}/create-pr")
    public ResponseEntity<Map<String, Object>> createPr(@PathVariable String id) {
        try {
            Map<String, Object> plan = prService.createPrPlan(id);
            return ResponseEntity.ok(plan);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Get all PR plans.
     */
    @GetMapping("/prs")
    public ResponseEntity<List<Map<String, Object>>> getPrPlans() {
        return ResponseEntity.ok(prService.getAllPrPlans());
    }
}
