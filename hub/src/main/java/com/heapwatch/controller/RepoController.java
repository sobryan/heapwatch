package com.heapwatch.controller;

import com.heapwatch.model.CodeIssue;
import com.heapwatch.model.RepoStatus;
import com.heapwatch.service.CodeMappingService;
import com.heapwatch.service.GitRepoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/repo")
@CrossOrigin(origins = "*")
public class RepoController {

    private final GitRepoService gitRepoService;
    private final CodeMappingService codeMappingService;

    public RepoController(GitRepoService gitRepoService, CodeMappingService codeMappingService) {
        this.gitRepoService = gitRepoService;
        this.codeMappingService = codeMappingService;
    }

    /**
     * Connect to a GitHub repository.
     */
    @PostMapping("/connect")
    public ResponseEntity<RepoStatus> connect(@RequestBody Map<String, String> request) {
        String repoUrl = request.get("repoUrl");
        String branch = request.getOrDefault("branch", "main");
        if (repoUrl == null || repoUrl.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        RepoStatus status = gitRepoService.connect(repoUrl, branch);
        return ResponseEntity.ok(status);
    }

    /**
     * Get current repository connection status.
     */
    @GetMapping("/status")
    public ResponseEntity<RepoStatus> getStatus() {
        return ResponseEntity.ok(gitRepoService.getStatus());
    }

    /**
     * Search for a class in the indexed repository.
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchClass(@RequestParam String className) {
        Map<String, Object> result = gitRepoService.searchClass(className);
        return ResponseEntity.ok(result);
    }

    /**
     * Map profiling issues to source code in the connected repository.
     */
    @GetMapping("/map-issues")
    public ResponseEntity<List<CodeIssue>> mapIssues() {
        List<CodeIssue> mapped = codeMappingService.mapIssuesToSource();
        return ResponseEntity.ok(mapped);
    }
}
