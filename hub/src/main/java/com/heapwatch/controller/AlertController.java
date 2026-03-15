package com.heapwatch.controller;

import com.heapwatch.service.AlertService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/alerts")
@CrossOrigin(origins = "*")
public class AlertController {

    private final AlertService alertService;

    public AlertController(AlertService alertService) {
        this.alertService = alertService;
    }

    @GetMapping
    public Map<String, Object> getAlerts() {
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("alerts", alertService.getAlerts());
        result.put("activeCount", alertService.getActiveAlertCount());
        return result;
    }

    @GetMapping("/rules")
    public List<Map<String, Object>> getRules() {
        return alertService.getRules();
    }

    @PostMapping("/rules")
    public ResponseEntity<Map<String, Object>> addRule(@RequestBody Map<String, Object> rule) {
        Map<String, Object> created = alertService.addRule(rule);
        return ResponseEntity.ok(created);
    }

    @DeleteMapping
    public ResponseEntity<Void> clearAlerts() {
        alertService.clearAlerts();
        return ResponseEntity.noContent().build();
    }
}
