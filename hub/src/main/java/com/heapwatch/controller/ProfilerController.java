package com.heapwatch.controller;

import com.heapwatch.model.HeapDumpInfo;
import com.heapwatch.model.JfrRecording;
import com.heapwatch.service.HeapDumpAnalysisService;
import com.heapwatch.service.HeapDumpService;
import com.heapwatch.service.JfrAnalysisService;
import com.heapwatch.service.JfrService;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/profiler")
@CrossOrigin(origins = "*")
public class ProfilerController {

    private final JfrService jfrService;
    private final HeapDumpService heapDumpService;
    private final JfrAnalysisService jfrAnalysisService;
    private final HeapDumpAnalysisService heapDumpAnalysisService;

    public ProfilerController(JfrService jfrService, HeapDumpService heapDumpService,
                              JfrAnalysisService jfrAnalysisService,
                              HeapDumpAnalysisService heapDumpAnalysisService) {
        this.jfrService = jfrService;
        this.heapDumpService = heapDumpService;
        this.jfrAnalysisService = jfrAnalysisService;
        this.heapDumpAnalysisService = heapDumpAnalysisService;
    }

    // --- JFR Recordings ---

    @PostMapping("/jfr")
    public ResponseEntity<JfrRecording> startJfr(@RequestBody Map<String, Object> request) {
        int pid = ((Number) request.get("pid")).intValue();
        String processName = (String) request.getOrDefault("processName", "unknown");
        int duration = ((Number) request.getOrDefault("durationSeconds", 30)).intValue();
        String profileType = (String) request.getOrDefault("profileType", "CPU");

        JfrRecording recording = jfrService.startRecording(pid, processName, duration, profileType);
        return ResponseEntity.accepted().body(recording);
    }

    @GetMapping("/jfr")
    public List<JfrRecording> listJfr() {
        return jfrService.getAllRecordings();
    }

    @GetMapping("/jfr/{id}")
    public ResponseEntity<JfrRecording> getJfr(@PathVariable String id) {
        return jfrService.getRecording(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/jfr/{id}")
    public ResponseEntity<Void> cancelJfr(@PathVariable String id) {
        jfrService.cancelRecording(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/jfr/{id}/download")
    public ResponseEntity<FileSystemResource> downloadJfr(@PathVariable String id) {
        return jfrService.getOutputFile(id)
                .map(path -> {
                    FileSystemResource resource = new FileSystemResource(path.toFile());
                    return ResponseEntity.ok()
                            .header(HttpHeaders.CONTENT_DISPOSITION,
                                    "attachment; filename=\"" + path.getFileName() + "\"")
                            .contentType(MediaType.APPLICATION_OCTET_STREAM)
                            .body(resource);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/jfr/{id}/analysis")
    public ResponseEntity<Map<String, Object>> analyzeJfr(@PathVariable String id) {
        try {
            Map<String, Object> analysis = jfrAnalysisService.analyze(id);
            return ResponseEntity.ok(analysis);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // --- Heap Dumps ---

    @PostMapping("/heapdump")
    public ResponseEntity<HeapDumpInfo> triggerHeapDump(@RequestBody Map<String, Object> request) {
        int pid = ((Number) request.get("pid")).intValue();
        String processName = (String) request.getOrDefault("processName", "unknown");
        HeapDumpInfo info = heapDumpService.triggerHeapDump(pid, processName);
        return ResponseEntity.accepted().body(info);
    }

    @GetMapping("/heapdump")
    public List<HeapDumpInfo> listHeapDumps() {
        return heapDumpService.getAllDumps();
    }

    @GetMapping("/heapdump/{id}")
    public ResponseEntity<HeapDumpInfo> getHeapDump(@PathVariable String id) {
        return heapDumpService.getDump(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/heapdump/{id}/analysis")
    public ResponseEntity<Map<String, Object>> analyzeHeapDump(@PathVariable String id) {
        try {
            Map<String, Object> analysis = heapDumpAnalysisService.analyze(id);
            return ResponseEntity.ok(analysis);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
