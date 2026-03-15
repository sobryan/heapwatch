package com.heapwatch.controller;

import com.heapwatch.service.GcAnalysisService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/jvms")
@CrossOrigin(origins = "*")
public class GcAnalysisController {

    private final GcAnalysisService gcAnalysisService;

    public GcAnalysisController(GcAnalysisService gcAnalysisService) {
        this.gcAnalysisService = gcAnalysisService;
    }

    @GetMapping("/{pid}/gc")
    public ResponseEntity<Map<String, Object>> analyzeGc(@PathVariable int pid) {
        try {
            Map<String, Object> analysis = gcAnalysisService.analyze(pid);
            return ResponseEntity.ok(analysis);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
