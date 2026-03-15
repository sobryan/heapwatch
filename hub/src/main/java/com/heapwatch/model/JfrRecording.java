package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;
import java.time.Instant;

@Data
@Builder
public class JfrRecording {
    private String id;
    private int pid;
    private String processName;
    private int durationSeconds;
    private String status; // PENDING, RECORDING, COMPLETED, FAILED, CANCELLED
    private Instant startTime;
    private Instant endTime;
    private String outputPath;
    private String error;
    private String profileType; // CPU, ALLOC, FULL
    private long fileSizeBytes;
}
