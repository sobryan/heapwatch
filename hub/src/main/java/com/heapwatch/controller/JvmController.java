package com.heapwatch.controller;

import com.heapwatch.model.JvmProcess;
import com.heapwatch.service.HistogramDiffService;
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
    private final HistogramDiffService histogramDiffService;

    public JvmController(JvmDiscoveryService discoveryService,
                         MetricsHistoryService metricsHistoryService,
                         HistogramDiffService histogramDiffService) {
        this.discoveryService = discoveryService;
        this.metricsHistoryService = metricsHistoryService;
        this.histogramDiffService = histogramDiffService;
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

    @PostMapping("/{pid}/heap-baseline")
    public ResponseEntity<Map<String, Object>> captureHeapBaseline(@PathVariable int pid) {
        try {
            Map<String, Object> result = histogramDiffService.captureBaseline(pid);
            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{pid}/heap-diff")
    public ResponseEntity<Map<String, Object>> getHeapDiff(@PathVariable int pid) {
        try {
            Map<String, Object> result = histogramDiffService.computeDiff(pid);
            return ResponseEntity.ok(result);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
