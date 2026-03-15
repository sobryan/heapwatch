package com.heapwatch.controller;

import com.heapwatch.service.ThreadAnalysisService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/jvms")
@CrossOrigin(origins = "*")
public class ThreadAnalysisController {

    private final ThreadAnalysisService threadAnalysisService;

    public ThreadAnalysisController(ThreadAnalysisService threadAnalysisService) {
        this.threadAnalysisService = threadAnalysisService;
    }

    @GetMapping("/{pid}/threads")
    public ResponseEntity<Map<String, Object>> analyzeThreads(@PathVariable int pid) {
        try {
            Map<String, Object> analysis = threadAnalysisService.analyze(pid);
            return ResponseEntity.ok(analysis);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
