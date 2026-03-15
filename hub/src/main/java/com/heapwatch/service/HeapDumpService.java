package com.heapwatch.service;

import com.heapwatch.model.HeapDumpInfo;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

/**
 * Triggers heap dumps on target JVMs via jcmd GC.heap_dump.
 * No application restart required.
 */
@Slf4j
@Service
public class HeapDumpService {

    @Value("${heapwatch.jfr.output-dir:/tmp/heapwatch-jfr}")
    private String outputDir;

    private final SimpMessagingTemplate messagingTemplate;
    private final Map<String, HeapDumpInfo> dumps = new ConcurrentHashMap<>();

    public HeapDumpService(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "heapdump-worker");
        t.setDaemon(true);
        return t;
    });

    public HeapDumpInfo triggerHeapDump(int pid, String processName) {
        String id = UUID.randomUUID().toString().substring(0, 8);
        String fileName = String.format("heapdump-%s-%d-%s.hprof", id, pid,
                Instant.now().toString().replace(":", "-").substring(0, 19));
        Path path = Paths.get(outputDir, fileName);

        HeapDumpInfo info = HeapDumpInfo.builder()
                .id(id)
                .pid(pid)
                .processName(processName)
                .filePath(path.toString())
                .status("PENDING")
                .createdAt(Instant.now())
                .build();

        dumps.put(id, info);
        broadcastHeapDumpStatus();
        executor.submit(() -> executeHeapDump(info));
        return info;
    }

    public List<HeapDumpInfo> getAllDumps() {
        List<HeapDumpInfo> list = new ArrayList<>(dumps.values());
        list.sort(Comparator.comparing(HeapDumpInfo::getCreatedAt).reversed());
        return list;
    }

    public Optional<HeapDumpInfo> getDump(String id) {
        return Optional.ofNullable(dumps.get(id));
    }

    private void executeHeapDump(HeapDumpInfo info) {
        try {
            Path dir = Paths.get(outputDir);
            if (!Files.exists(dir)) Files.createDirectories(dir);

            info.setStatus("DUMPING");
            broadcastHeapDumpStatus();

            List<String> cmd = List.of("jcmd", String.valueOf(info.getPid()),
                    "GC.heap_dump", info.getFilePath());

            Process proc = new ProcessBuilder(cmd)
                    .redirectErrorStream(true)
                    .start();

            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            if (!proc.waitFor(120, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
                info.setStatus("FAILED");
                info.setError("Heap dump timed out");
                return;
            }

            Path filePath = Paths.get(info.getFilePath());
            if (Files.exists(filePath)) {
                info.setFileSizeBytes(Files.size(filePath));
                info.setStatus("COMPLETED");
                log.info("Heap dump {} completed: {} bytes", info.getId(), info.getFileSizeBytes());
            } else {
                info.setStatus("FAILED");
                info.setError("Heap dump file not created: " + output);
            }
        } catch (Exception e) {
            log.error("Heap dump {} failed", info.getId(), e);
            info.setStatus("FAILED");
            info.setError(e.getMessage());
        } finally {
            broadcastHeapDumpStatus();
        }
    }

    private void broadcastHeapDumpStatus() {
        try {
            messagingTemplate.convertAndSend("/topic/profiler/heapdump", getAllDumps());
        } catch (Exception e) {
            log.debug("WebSocket heap dump broadcast failed: {}", e.getMessage());
        }
    }
}
