package com.heapwatch.controller;

import com.heapwatch.model.JvmProcess;
import com.heapwatch.service.JvmDiscoveryService;
import com.heapwatch.service.MetricsHistoryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/jvms")
@CrossOrigin(origins = "*")
public class JvmController {

    private final JvmDiscoveryService discoveryService;
    private final MetricsHistoryService metricsHistoryService;

    public JvmController(JvmDiscoveryService discoveryService,
                         MetricsHistoryService metricsHistoryService) {
        this.discoveryService = discoveryService;
        this.metricsHistoryService = metricsHistoryService;
    }

    @GetMapping
    public List<JvmProcess> listJvms() {
        return discoveryService.getDiscoveredJvms();
    }

    @GetMapping("/{pid}")
    public ResponseEntity<JvmProcess> getJvm(@PathVariable int pid) {
        return discoveryService.getJvm(pid)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{pid}/history")
    public ResponseEntity<Map<String, Object>> getHistory(@PathVariable int pid) {
        Map<String, Object> history = metricsHistoryService.getHistory(pid);
        return ResponseEntity.ok(history);
    }

    @PostMapping("/refresh")
    public List<JvmProcess> refreshJvms() {
        discoveryService.discoverAndRefresh();
        return discoveryService.getDiscoveredJvms();
    }
}
