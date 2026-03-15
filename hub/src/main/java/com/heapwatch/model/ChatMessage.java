package com.heapwatch.model;

import lombok.Builder;
import lombok.Data;
import java.time.Instant;

@Data
@Builder
public class ChatMessage {
    private String role; // user, assistant
    private String content;
    private Instant timestamp;
}
