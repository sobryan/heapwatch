package com.heapwatch.controller;

import com.heapwatch.model.AlertIntegration;
import com.heapwatch.service.AlertIntegrationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/alerts/integrations")
@CrossOrigin(origins = "*")
public class AlertIntegrationController {

    private final AlertIntegrationService alertIntegrationService;

    public AlertIntegrationController(AlertIntegrationService alertIntegrationService) {
        this.alertIntegrationService = alertIntegrationService;
    }

    @GetMapping
    public List<AlertIntegration> getIntegrations() {
        return alertIntegrationService.getIntegrations();
    }

    @PostMapping
    public ResponseEntity<AlertIntegration> addIntegration(@RequestBody AlertIntegration integration) {
        AlertIntegration created = alertIntegrationService.addIntegration(integration);
        return ResponseEntity.ok(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<AlertIntegration> updateIntegration(
            @PathVariable String id, @RequestBody AlertIntegration updates) {
        try {
            AlertIntegration updated = alertIntegrationService.updateIntegration(id, updates);
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteIntegration(@PathVariable String id) {
        boolean deleted = alertIntegrationService.deleteIntegration(id);
        return deleted ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }

    @PostMapping("/{id}/test")
    public ResponseEntity<Map<String, Object>> testIntegration(@PathVariable String id) {
        try {
            Map<String, Object> result = alertIntegrationService.testIntegration(id);
            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }
}
