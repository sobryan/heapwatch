package com.heapwatch.controller;

import com.heapwatch.model.DiagnosisReport;
import com.heapwatch.service.AiAdvisorService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/diagnose")
@CrossOrigin(origins = "*")
public class DiagnoseController {

    private final AiAdvisorService aiAdvisorService;

    public DiagnoseController(AiAdvisorService aiAdvisorService) {
        this.aiAdvisorService = aiAdvisorService;
    }

    /**
     * One-click comprehensive diagnosis for a JVM process.
     * Gathers all available data and returns a structured diagnosis report.
     */
    @PostMapping("/{pid}")
    public ResponseEntity<DiagnosisReport> diagnose(@PathVariable int pid) {
        try {
            DiagnosisReport report = aiAdvisorService.diagnose(pid);
            return ResponseEntity.ok(report);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().build();
        }
    }
}
