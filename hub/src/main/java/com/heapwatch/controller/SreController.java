package com.heapwatch.controller;

import com.heapwatch.model.SreIncident;
import com.heapwatch.service.SreAgentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/sre")
@CrossOrigin(origins = "*")
public class SreController {

    private final SreAgentService sreAgentService;

    public SreController(SreAgentService sreAgentService) {
        this.sreAgentService = sreAgentService;
    }

    @GetMapping("/incidents")
    public List<SreIncident> getIncidents() {
        return sreAgentService.getIncidents();
    }

    @GetMapping("/incidents/{id}")
    public ResponseEntity<SreIncident> getIncident(@PathVariable String id) {
        return sreAgentService.getIncident(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/incidents/{id}/resolve")
    public ResponseEntity<SreIncident> resolveIncident(@PathVariable String id) {
        try {
            SreIncident resolved = sreAgentService.resolveIncident(id);
            return ResponseEntity.ok(resolved);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/status")
    public Map<String, Object> getStatus() {
        return sreAgentService.getStatus();
    }

    @PostMapping("/toggle")
    public Map<String, Object> toggle() {
        boolean running = sreAgentService.toggle();
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("running", running);
        result.put("message", running ? "SRE Agent started" : "SRE Agent paused");
        return result;
    }
}
