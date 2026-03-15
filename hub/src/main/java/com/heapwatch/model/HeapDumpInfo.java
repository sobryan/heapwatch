package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;
import java.time.Instant;

@Data
@Builder
public class HeapDumpInfo {
    private String id;
    private int pid;
    private String processName;
    private String filePath;
    private long fileSizeBytes;
    private Instant createdAt;
    private String status; // PENDING, DUMPING, COMPLETED, FAILED
    private String error;
}
