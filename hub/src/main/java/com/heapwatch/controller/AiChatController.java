package com.heapwatch.controller;

import com.heapwatch.model.ChatMessage;
import com.heapwatch.service.AiAdvisorService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*")
public class AiChatController {

    private final AiAdvisorService aiService;

    public AiChatController(AiAdvisorService aiService) {
        this.aiService = aiService;
    }

    @PostMapping
    public ChatMessage sendMessage(@RequestBody Map<String, String> request) {
        String message = request.get("message");
        if (message == null || message.isBlank()) {
            return ChatMessage.builder()
                    .role("assistant")
                    .content("Please provide a message.")
                    .build();
        }
        return aiService.chat(message);
    }

    @GetMapping("/history")
    public List<ChatMessage> getChatHistory() {
        return aiService.getChatHistory();
    }

    @DeleteMapping("/history")
    public ResponseEntity<Void> clearChat() {
        aiService.clearChat();
        return ResponseEntity.noContent().build();
    }
}
