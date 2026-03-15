package com.heapwatch.service;

import com.heapwatch.model.JfrRecording;
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
 * Java Flight Recorder service — starts/stops JFR recordings on target JVMs
 * via jcmd (no restart required). Works with JDK 11+ out of the box.
 */
@Slf4j
@Service
public class JfrService {

    @Value("${heapwatch.jfr.output-dir:/tmp/heapwatch-jfr}")
    private String outputDir;

    private final SimpMessagingTemplate messagingTemplate;
    private final NotificationService notificationService;
    private final Map<String, JfrRecording> recordings = new ConcurrentHashMap<>();

    public JfrService(SimpMessagingTemplate messagingTemplate, NotificationService notificationService) {
        this.messagingTemplate = messagingTemplate;
        this.notificationService = notificationService;
    }
    private final ExecutorService executor = Executors.newCachedThreadPool(r -> {
        Thread t = new Thread(r, "jfr-worker");
        t.setDaemon(true);
        return t;
    });

    public JfrRecording startRecording(int pid, String processName, int durationSeconds, String profileType) {
        String id = UUID.randomUUID().toString().substring(0, 8);
        String fileName = String.format("heapwatch-%s-%s-%d.jfr", id, profileType.toLowerCase(), pid);
        Path outputPath = Paths.get(outputDir, fileName);

        JfrRecording recording = JfrRecording.builder()
                .id(id)
                .pid(pid)
                .processName(processName)
                .durationSeconds(durationSeconds)
                .status("PENDING")
                .startTime(Instant.now())
                .outputPath(outputPath.toString())
                .profileType(profileType)
                .build();

        recordings.put(id, recording);
        broadcastJfrStatus();
        executor.submit(() -> executeRecording(recording));
        return recording;
    }

    public List<JfrRecording> getAllRecordings() {
        List<JfrRecording> list = new ArrayList<>(recordings.values());
        list.sort(Comparator.comparing(JfrRecording::getStartTime).reversed());
        return list;
    }

    public Optional<JfrRecording> getRecording(String id) {
        return Optional.ofNullable(recordings.get(id));
    }

    public void cancelRecording(String id) {
        JfrRecording recording = recordings.get(id);
        if (recording != null && "RECORDING".equals(recording.getStatus())) {
            try {
                runJcmd(recording.getPid(), "JFR.stop", "name=heapwatch-" + id);
                recording.setStatus("CANCELLED");
                recording.setEndTime(Instant.now());
                broadcastJfrStatus();
            } catch (Exception e) {
                log.error("Failed to cancel recording {}", id, e);
            }
        }
    }

    private void broadcastJfrStatus() {
        try {
            messagingTemplate.convertAndSend("/topic/profiler/jfr", getAllRecordings());
        } catch (Exception e) {
            log.debug("WebSocket JFR broadcast failed: {}", e.getMessage());
        }
    }

    public Optional<Path> getOutputFile(String id) {
        return Optional.ofNullable(recordings.get(id))
                .map(r -> Paths.get(r.getOutputPath()))
                .filter(Files::exists);
    }

    private void executeRecording(JfrRecording recording) {
        try {
            ensureOutputDir();
            recording.setStatus("RECORDING");
            broadcastJfrStatus();

            // Build JFR settings based on profile type
            String settings = switch (recording.getProfileType().toUpperCase()) {
                case "CPU" -> "settings=profile";
                case "ALLOC" -> "settings=default,jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true";
                default -> "settings=profile"; // FULL
            };

            // Start JFR recording via jcmd
            String startResult = runJcmd(recording.getPid(),
                    "JFR.start",
                    "name=heapwatch-" + recording.getId(),
                    "duration=" + recording.getDurationSeconds() + "s",
                    "filename=" + recording.getOutputPath(),
                    settings);

            log.info("JFR started for pid {}: {}", recording.getPid(), startResult);

            // Wait for recording to complete
            Thread.sleep((recording.getDurationSeconds() + 5) * 1000L);

            // Check if file was created
            Path outputPath = Paths.get(recording.getOutputPath());
            if (Files.exists(outputPath)) {
                recording.setFileSizeBytes(Files.size(outputPath));
                recording.setStatus("COMPLETED");
                log.info("JFR recording {} completed: {} bytes", recording.getId(), recording.getFileSizeBytes());
                notificationService.addNotification("RECORDING",
                        "JFR Recording Completed",
                        recording.getProfileType() + " recording for " + recording.getProcessName() +
                                " (PID " + recording.getPid() + ") completed - " +
                                formatFileSize(recording.getFileSizeBytes()),
                        "INFO");
            } else {
                recording.setStatus("FAILED");
                recording.setError("Output file not created");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            recording.setStatus("CANCELLED");
        } catch (Exception e) {
            log.error("JFR recording {} failed", recording.getId(), e);
            recording.setStatus("FAILED");
            recording.setError(e.getMessage());
        } finally {
            recording.setEndTime(Instant.now());
            broadcastJfrStatus();
        }
    }

    private String runJcmd(int pid, String... commands) throws Exception {
        List<String> cmd = new ArrayList<>();
        cmd.add("jcmd");
        cmd.add(String.valueOf(pid));
        cmd.addAll(Arrays.asList(commands));

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

        if (!proc.waitFor(30, TimeUnit.SECONDS)) {
            proc.destroyForcibly();
            throw new RuntimeException("jcmd timed out");
        }

        return output.toString().trim();
    }

    private void ensureOutputDir() throws Exception {
        Path dir = Paths.get(outputDir);
        if (!Files.exists(dir)) {
            Files.createDirectories(dir);
        }
    }

    private String formatFileSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
