package com.heapwatch.controller;

import com.heapwatch.service.SnapshotService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class SnapshotController {

    private final SnapshotService snapshotService;

    public SnapshotController(SnapshotService snapshotService) {
        this.snapshotService = snapshotService;
    }

    @PostMapping("/jvms/{pid}/snapshot")
    public ResponseEntity<Map<String, Object>> captureSnapshot(@PathVariable int pid) {
        try {
            Map<String, Object> snapshot = snapshotService.captureSnapshot(pid);
            return ResponseEntity.ok(snapshot);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/jvms/{pid}/snapshots")
    public List<Map<String, Object>> listSnapshots(@PathVariable int pid) {
        return snapshotService.listSnapshots(pid);
    }

    @GetMapping("/compare")
    public ResponseEntity<Map<String, Object>> compare(
            @RequestParam int snapshot1,
            @RequestParam int snapshot2) {
        try {
            Map<String, Object> comparison = snapshotService.compare(snapshot1, snapshot2);
            return ResponseEntity.ok(comparison);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
