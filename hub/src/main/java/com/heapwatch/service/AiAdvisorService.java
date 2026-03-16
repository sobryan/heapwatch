package com.heapwatch.service;

import com.heapwatch.model.ChatMessage;
import com.heapwatch.model.CodeIssue;
import com.heapwatch.model.DiagnosisReport;
import com.heapwatch.model.JvmProcess;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import com.google.gson.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.TimeUnit;

/**
 * AI Advisor powered by Claude API.
 * Provides intelligent analysis of JVM performance data.
 * Phase 3: Enhanced with comprehensive diagnosis including code correlation.
 */
@Slf4j
@Service
public class AiAdvisorService {

    @Value("${heapwatch.ai.api-key:}")
    private String apiKey;

    @Value("${heapwatch.ai.model:claude-sonnet-4-20250514}")
    private String model;

    private final List<ChatMessage> chatHistory = new CopyOnWriteArrayList<>();
    private final Gson gson = new Gson();
    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .build();

    private final JvmDiscoveryService discoveryService;
    private final AlertService alertService;
    private final MetricsHistoryService metricsHistoryService;
    private final IssueRankingService issueRankingService;

    public AiAdvisorService(JvmDiscoveryService discoveryService,
                            AlertService alertService,
                            MetricsHistoryService metricsHistoryService,
                            IssueRankingService issueRankingService) {
        this.discoveryService = discoveryService;
        this.alertService = alertService;
        this.metricsHistoryService = metricsHistoryService;
        this.issueRankingService = issueRankingService;
    }

    public ChatMessage chat(String userMessage) {
        chatHistory.add(ChatMessage.builder()
                .role("user")
                .content(userMessage)
                .timestamp(Instant.now())
                .build());

        String response;
        if (apiKey == null || apiKey.isBlank()) {
            response = generateLocalResponse(userMessage);
        } else {
            response = callClaudeApi(userMessage);
        }

        ChatMessage assistantMessage = ChatMessage.builder()
                .role("assistant")
                .content(response)
                .timestamp(Instant.now())
                .build();
        chatHistory.add(assistantMessage);
        return assistantMessage;
    }

    public List<ChatMessage> getChatHistory() {
        return new ArrayList<>(chatHistory);
    }

    public void clearChat() {
        chatHistory.clear();
    }

    /**
     * Analyze a code issue using AI. Feeds profiling data + source code snippet to Claude.
     * Returns root cause explanation, suggested fix (before/after code), estimated impact.
     */
    public CodeIssue analyzeCodeIssue(String issueId) {
        CodeIssue issue = issueRankingService.getIssue(issueId)
                .orElseThrow(() -> new RuntimeException("Issue not found: " + issueId));

        StringBuilder prompt = new StringBuilder();
        prompt.append("Analyze this JVM performance issue and provide a fix.\n\n");
        prompt.append("## Issue\n");
        prompt.append("- Severity: ").append(issue.getSeverity()).append("\n");
        prompt.append("- Category: ").append(issue.getCategory()).append("\n");
        prompt.append("- Title: ").append(issue.getTitle()).append("\n");
        prompt.append("- Description: ").append(issue.getDescription()).append("\n");
        prompt.append("- Method: ").append(issue.getMethod()).append("\n");
        prompt.append("- File: ").append(issue.getFilePath()).append("\n");

        prompt.append("\n## Profiling Metrics\n");
        if (issue.getCpuPercent() > 0) prompt.append("- CPU: ").append(issue.getCpuPercent()).append("%\n");
        if (issue.getAllocationBytes() > 0) prompt.append("- Allocation: ").append(formatBytes(issue.getAllocationBytes())).append("\n");
        if (issue.getThreadCount() > 0) prompt.append("- Threads: ").append(issue.getThreadCount()).append("\n");
        if (issue.getGcPauseMs() > 0) prompt.append("- GC Pause: ").append(issue.getGcPauseMs()).append("ms\n");

        if (issue.getSourceSnippet() != null && !issue.getSourceSnippet().isEmpty()) {
            prompt.append("\n## Source Code\n```java\n");
            prompt.append(issue.getSourceSnippet());
            prompt.append("```\n");
        }

        prompt.append("\nRespond ONLY with valid JSON (no markdown fences):\n");
        prompt.append("{\n");
        prompt.append("  \"rootCause\": \"<1-3 sentence explanation of the root cause>\",\n");
        prompt.append("  \"beforeCode\": \"<the problematic code snippet>\",\n");
        prompt.append("  \"afterCode\": \"<the fixed code snippet>\",\n");
        prompt.append("  \"estimatedImpact\": \"<expected performance improvement>\"\n");
        prompt.append("}");

        String rootCause;
        String beforeCode;
        String afterCode;
        String estimatedImpact;

        if (apiKey != null && !apiKey.isBlank()) {
            try {
                String systemPrompt = "You are HeapWatch AI Advisor, an expert Java performance engineer. " +
                        "Analyze the performance issue and provide a concrete code fix. " +
                        "The beforeCode should be the problematic code and afterCode should be the corrected version. " +
                        "Be specific and practical.";

                JsonArray messages = new JsonArray();
                JsonObject userMsg = new JsonObject();
                userMsg.addProperty("role", "user");
                userMsg.addProperty("content", prompt.toString());
                messages.add(userMsg);

                JsonObject body = new JsonObject();
                body.addProperty("model", model);
                body.addProperty("max_tokens", 2048);
                body.addProperty("system", systemPrompt);
                body.add("messages", messages);

                Request request = new Request.Builder()
                        .url("https://api.anthropic.com/v1/messages")
                        .header("x-api-key", apiKey)
                        .header("anthropic-version", "2023-06-01")
                        .header("content-type", "application/json")
                        .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
                        .build();

                try (Response resp = httpClient.newCall(request).execute()) {
                    if (resp.isSuccessful() && resp.body() != null) {
                        String responseBody = resp.body().string();
                        JsonObject json = gson.fromJson(responseBody, JsonObject.class);
                        String aiText = json.getAsJsonArray("content").get(0).getAsJsonObject().get("text").getAsString();

                        // Parse AI response
                        String cleaned = aiText.trim();
                        if (cleaned.startsWith("```")) {
                            cleaned = cleaned.replaceFirst("```[a-z]*\\n?", "");
                            cleaned = cleaned.replaceAll("```$", "").trim();
                        }
                        JsonObject result = gson.fromJson(cleaned, JsonObject.class);

                        rootCause = getStr(result, "rootCause", "Analysis pending.");
                        beforeCode = getStr(result, "beforeCode", issue.getSourceSnippet());
                        afterCode = getStr(result, "afterCode", "// Fix not generated");
                        estimatedImpact = getStr(result, "estimatedImpact", "Performance improvement expected.");

                        issue.setRootCause(rootCause);
                        issue.setBeforeCode(beforeCode);
                        issue.setAfterCode(afterCode);
                        issue.setEstimatedImpact(estimatedImpact);
                        issue.setSuggestedFix(afterCode);
                        issue.setAnalyzed(true);
                        issueRankingService.updateIssue(issue);
                        return issue;
                    }
                }
            } catch (Exception e) {
                log.error("AI code analysis failed, falling back to heuristic", e);
            }
        }

        // Fallback: heuristic analysis
        return analyzeCodeIssueLocally(issue);
    }

    /**
     * Local heuristic-based code analysis when no AI API key is configured.
     */
    private CodeIssue analyzeCodeIssueLocally(CodeIssue issue) {
        String category = issue.getCategory();

        switch (category) {
            case "MEMORY":
                issue.setRootCause("Unbounded collection growth detected. Objects are added to a collection " +
                        "without any eviction or size limit, causing the heap to fill over time.");
                issue.setBeforeCode("// Current: unbounded add\nLEAK.add(new byte[100_000]);");
                issue.setAfterCode("// Fixed: bounded with eviction\nif (LEAK.size() > MAX_SIZE) {\n    LEAK.remove(0);\n}\nLEAK.add(new byte[100_000]);");
                issue.setEstimatedImpact("Eliminates memory leak, prevents OutOfMemoryError. Heap usage stays bounded.");
                break;
            case "CPU":
                issue.setRootCause("Inefficient algorithm with O(n^2) complexity detected. " +
                        "A quadratic sorting or search operation is consuming excessive CPU cycles.");
                issue.setBeforeCode("// Current: O(n^2) bubble sort\nfor (int i = 0; i < arr.length; i++)\n  for (int j = 0; j < arr.length-1; j++)\n    if (arr[j] > arr[j+1]) swap(arr, j, j+1);");
                issue.setAfterCode("// Fixed: O(n log n) built-in sort\nArrays.sort(arr);");
                issue.setEstimatedImpact("~99% CPU reduction for sort operations. O(n^2) -> O(n log n).");
                break;
            case "THREADS":
                issue.setRootCause("Lock ordering inconsistency detected. Multiple threads acquire locks " +
                        "in different orders, causing deadlock or severe contention.");
                issue.setBeforeCode("// Thread 1: lockA -> lockB\nsynchronized(lockA) {\n  synchronized(lockB) { ... }\n}\n// Thread 2: lockB -> lockA\nsynchronized(lockB) {\n  synchronized(lockA) { ... }\n}");
                issue.setAfterCode("// Fixed: consistent lock ordering\n// Both threads: lockA -> lockB\nsynchronized(lockA) {\n  synchronized(lockB) { ... }\n}");
                issue.setEstimatedImpact("Eliminates deadlocks and contention. Thread throughput improvement of 5-10x.");
                break;
            case "GC":
                issue.setRootCause("Rapid allocation of short-lived objects creates excessive GC pressure. " +
                        "Young generation fills quickly, triggering frequent minor GC collections.");
                issue.setBeforeCode("// Current: allocate new byte[] every iteration\nwhile (true) {\n  byte[] buf = new byte[1024 * 1024];\n  process(buf);\n}");
                issue.setAfterCode("// Fixed: reuse byte buffer\nbyte[] buf = new byte[1024 * 1024];\nwhile (true) {\n  Arrays.fill(buf, (byte) 0);\n  process(buf);\n}");
                issue.setEstimatedImpact("50-80% reduction in GC pauses. Allocation rate drops dramatically.");
                break;
            default:
                issue.setRootCause("Performance issue detected. Further analysis recommended.");
                issue.setBeforeCode(issue.getSourceSnippet() != null ? issue.getSourceSnippet() : "// Source not available");
                issue.setAfterCode("// Optimization recommended - see root cause analysis");
                issue.setEstimatedImpact("Performance improvement expected after optimization.");
        }

        issue.setSuggestedFix(issue.getAfterCode());
        issue.setAnalyzed(true);
        issueRankingService.updateIssue(issue);
        return issue;
    }

    /**
     * One-click comprehensive diagnosis for a specific JVM process.
     * Gathers metrics, heap histogram, alerts, and history trends,
     * then either uses Claude AI or local heuristics for analysis.
     */
    public DiagnosisReport diagnose(int pid) {
        JvmProcess jvm = discoveryService.getJvm(pid)
                .orElseThrow(() -> new RuntimeException("JVM process not found: " + pid));
        jvm.computeStatus();

        // Gather comprehensive data
        String heapHistogram = getHeapHistogram(pid);
        List<Map<String, Object>> alerts = getRecentAlertsForPid(pid);
        Map<String, Object> history = metricsHistoryService.getHistory(pid);
        String threadDump = getThreadDumpSummary(pid);

        if (apiKey != null && !apiKey.isBlank()) {
            return diagnoseWithAi(jvm, heapHistogram, alerts, history, threadDump);
        } else {
            return diagnoseLocally(jvm, heapHistogram, alerts, history, threadDump);
        }
    }

    private DiagnosisReport diagnoseWithAi(JvmProcess jvm, String heapHistogram,
                                            List<Map<String, Object>> alerts,
                                            Map<String, Object> history,
                                            String threadDump) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("Analyze this JVM process and provide a comprehensive diagnosis.\n\n");
        prompt.append("## Process Info\n");
        prompt.append(String.format("- Name: %s (PID %d)\n", jvm.getDisplayName(), jvm.getPid()));
        prompt.append(String.format("- Status: %s\n", jvm.getStatus()));
        prompt.append(String.format("- Heap: %s / %s (%.1f%%)\n",
                formatBytes(jvm.getHeapUsedBytes()), formatBytes(jvm.getHeapMaxBytes()),
                jvm.getHeapUsagePercent()));
        prompt.append(String.format("- Threads: %d\n", jvm.getThreadCount()));
        prompt.append(String.format("- Deadlocked: %d\n", jvm.getDeadlockedThreads()));

        prompt.append("\n## Heap Histogram (top classes by size)\n");
        prompt.append(heapHistogram);

        prompt.append("\n## Thread Dump Summary\n");
        prompt.append(threadDump);

        if (!alerts.isEmpty()) {
            prompt.append("\n## Recent Alerts\n");
            for (Map<String, Object> alert : alerts) {
                prompt.append(String.format("- [%s] %s\n", alert.get("severity"), alert.get("message")));
            }
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> snapshots = (List<Map<String, Object>>) history.getOrDefault("snapshots", List.of());
        if (!snapshots.isEmpty()) {
            prompt.append("\n## Metrics Trend (last ").append(snapshots.size()).append(" snapshots)\n");
            // Show first and last few snapshots to show trend
            int size = snapshots.size();
            if (size > 5) {
                prompt.append("First: heap=").append(snapshots.get(0).get("heapPercent")).append("%, ");
                prompt.append("threads=").append(snapshots.get(0).get("threadCount")).append("\n");
                prompt.append("Latest: heap=").append(snapshots.get(size - 1).get("heapPercent")).append("%, ");
                prompt.append("threads=").append(snapshots.get(size - 1).get("threadCount")).append("\n");
            }
        }

        prompt.append("\nRespond ONLY with valid JSON in this exact format (no markdown, no code fences):\n");
        prompt.append("{\n");
        prompt.append("  \"healthScore\": <0-100>,\n");
        prompt.append("  \"healthAssessment\": \"<1-2 sentence overall assessment>\",\n");
        prompt.append("  \"issues\": [\n");
        prompt.append("    {\"severity\": \"CRITICAL|WARNING|INFO\", \"category\": \"MEMORY|CPU|THREADS|GC\", ");
        prompt.append("\"title\": \"...\", \"description\": \"...\", \"affectedMethod\": \"...\", \"impactScore\": <1-10>}\n");
        prompt.append("  ],\n");
        prompt.append("  \"recommendations\": [\n");
        prompt.append("    {\"title\": \"...\", \"description\": \"...\", \"affectedMethod\": \"...\", ");
        prompt.append("\"suggestedFix\": \"...\", \"estimatedImpact\": \"...\"}\n");
        prompt.append("  ]\n");
        prompt.append("}");

        try {
            String systemPrompt = "You are HeapWatch AI Advisor, an expert Java performance engineer. " +
                    "Analyze the JVM data and provide a structured diagnosis. " +
                    "Be specific about method names and concrete fixes. " +
                    "If you see patterns like LeakyApp, CpuHogApp, ThreadContentionApp, or GcPressureApp, " +
                    "provide relevant method-level recommendations for those demo apps.";

            JsonArray messages = new JsonArray();
            JsonObject userMsg = new JsonObject();
            userMsg.addProperty("role", "user");
            userMsg.addProperty("content", prompt.toString());
            messages.add(userMsg);

            JsonObject body = new JsonObject();
            body.addProperty("model", model);
            body.addProperty("max_tokens", 4096);
            body.addProperty("system", systemPrompt);
            body.add("messages", messages);

            Request request = new Request.Builder()
                    .url("https://api.anthropic.com/v1/messages")
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", "2023-06-01")
                    .header("content-type", "application/json")
                    .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
                    .build();

            try (Response resp = httpClient.newCall(request).execute()) {
                if (resp.isSuccessful() && resp.body() != null) {
                    String responseBody = resp.body().string();
                    JsonObject json = gson.fromJson(responseBody, JsonObject.class);
                    String aiText = json.getAsJsonArray("content").get(0).getAsJsonObject().get("text").getAsString();
                    return parseAiDiagnosis(jvm, aiText);
                }
            }
        } catch (Exception e) {
            log.error("AI diagnosis failed, falling back to local", e);
        }

        // Fallback to local diagnosis
        return diagnoseLocally(jvm, heapHistogram, alerts, history, threadDump);
    }

    private DiagnosisReport parseAiDiagnosis(JvmProcess jvm, String aiText) {
        try {
            // Strip markdown code fences if present
            String cleaned = aiText.trim();
            if (cleaned.startsWith("```")) {
                cleaned = cleaned.replaceFirst("```[a-z]*\\n?", "");
                cleaned = cleaned.replaceAll("```$", "").trim();
            }

            JsonObject json = gson.fromJson(cleaned, JsonObject.class);

            List<DiagnosisReport.DiagnosisIssue> issues = new ArrayList<>();
            if (json.has("issues")) {
                for (JsonElement el : json.getAsJsonArray("issues")) {
                    JsonObject iss = el.getAsJsonObject();
                    issues.add(DiagnosisReport.DiagnosisIssue.builder()
                            .severity(getStr(iss, "severity", "INFO"))
                            .category(getStr(iss, "category", "MEMORY"))
                            .title(getStr(iss, "title", ""))
                            .description(getStr(iss, "description", ""))
                            .affectedMethod(getStr(iss, "affectedMethod", ""))
                            .impactScore(getInt(iss, "impactScore", 5))
                            .build());
                }
            }

            List<DiagnosisReport.CodeRecommendation> recs = new ArrayList<>();
            if (json.has("recommendations")) {
                for (JsonElement el : json.getAsJsonArray("recommendations")) {
                    JsonObject rec = el.getAsJsonObject();
                    recs.add(DiagnosisReport.CodeRecommendation.builder()
                            .title(getStr(rec, "title", ""))
                            .description(getStr(rec, "description", ""))
                            .affectedMethod(getStr(rec, "affectedMethod", ""))
                            .suggestedFix(getStr(rec, "suggestedFix", ""))
                            .estimatedImpact(getStr(rec, "estimatedImpact", ""))
                            .build());
                }
            }

            return DiagnosisReport.builder()
                    .pid(jvm.getPid())
                    .processName(jvm.getDisplayName())
                    .timestamp(Instant.now().toString())
                    .healthScore(getInt(json, "healthScore", 50))
                    .healthAssessment(getStr(json, "healthAssessment", "Analysis complete."))
                    .issues(issues)
                    .recommendations(recs)
                    .snapshot(buildSnapshot(jvm))
                    .build();
        } catch (Exception e) {
            log.warn("Failed to parse AI diagnosis JSON: {}", e.getMessage());
            // Return a report with the raw text as assessment
            return DiagnosisReport.builder()
                    .pid(jvm.getPid())
                    .processName(jvm.getDisplayName())
                    .timestamp(Instant.now().toString())
                    .healthScore(50)
                    .healthAssessment(aiText.length() > 500 ? aiText.substring(0, 500) : aiText)
                    .issues(List.of())
                    .recommendations(List.of())
                    .snapshot(buildSnapshot(jvm))
                    .build();
        }
    }

    /**
     * Local heuristic-based diagnosis when no AI API key is configured.
     */
    private DiagnosisReport diagnoseLocally(JvmProcess jvm, String heapHistogram,
                                             List<Map<String, Object>> alerts,
                                             Map<String, Object> history,
                                             String threadDump) {
        List<DiagnosisReport.DiagnosisIssue> issues = new ArrayList<>();
        List<DiagnosisReport.CodeRecommendation> recs = new ArrayList<>();
        int healthScore = 100;

        // Memory analysis
        if (jvm.getHeapUsagePercent() > 90) {
            healthScore -= 40;
            issues.add(DiagnosisReport.DiagnosisIssue.builder()
                    .severity("CRITICAL")
                    .category("MEMORY")
                    .title("Heap usage critically high")
                    .description(String.format("Heap at %.1f%% (%s / %s). Risk of OutOfMemoryError.",
                            jvm.getHeapUsagePercent(),
                            formatBytes(jvm.getHeapUsedBytes()),
                            formatBytes(jvm.getHeapMaxBytes())))
                    .impactScore(9)
                    .build());
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Investigate memory leak")
                    .description("Take a heap dump and analyze top object types for unbounded growth")
                    .suggestedFix("Check for collections (List, Map) that grow without bounds. Add size limits or LRU eviction.")
                    .estimatedImpact("Prevents OutOfMemoryError crash")
                    .build());
        } else if (jvm.getHeapUsagePercent() > 75) {
            healthScore -= 15;
            issues.add(DiagnosisReport.DiagnosisIssue.builder()
                    .severity("WARNING")
                    .category("MEMORY")
                    .title("Elevated heap usage")
                    .description(String.format("Heap at %.1f%%. Monitor for growth trend.",
                            jvm.getHeapUsagePercent()))
                    .impactScore(5)
                    .build());
        }

        // Thread analysis
        if (jvm.getDeadlockedThreads() > 0) {
            healthScore -= 30;
            issues.add(DiagnosisReport.DiagnosisIssue.builder()
                    .severity("CRITICAL")
                    .category("THREADS")
                    .title("Deadlock detected")
                    .description(jvm.getDeadlockedThreads() + " deadlocked thread(s) found")
                    .impactScore(10)
                    .build());
        }

        if (jvm.getThreadCount() > 100) {
            healthScore -= 10;
            issues.add(DiagnosisReport.DiagnosisIssue.builder()
                    .severity("WARNING")
                    .category("THREADS")
                    .title("High thread count")
                    .description(jvm.getThreadCount() + " threads active. May indicate thread pool saturation or thread leak.")
                    .impactScore(6)
                    .build());
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Review thread pool configuration")
                    .description("High thread count may indicate unbounded thread creation or pool saturation")
                    .suggestedFix("Use bounded thread pools (Executors.newFixedThreadPool) and monitor queue depth")
                    .estimatedImpact("Reduces context switching overhead and memory usage")
                    .build());
        }

        // Thread dump analysis for contention
        if (threadDump.contains("BLOCKED")) {
            int blockedCount = countOccurrences(threadDump, "BLOCKED");
            if (blockedCount > 2) {
                healthScore -= 15;
                issues.add(DiagnosisReport.DiagnosisIssue.builder()
                        .severity("WARNING")
                        .category("THREADS")
                        .title("Thread contention detected")
                        .description(blockedCount + " threads in BLOCKED state. Lock contention is impacting throughput.")
                        .impactScore(7)
                        .build());
                recs.add(DiagnosisReport.CodeRecommendation.builder()
                        .title("Reduce lock contention")
                        .description("Multiple threads blocked waiting for locks")
                        .suggestedFix("Consider using ConcurrentHashMap, ReadWriteLock, or lock-free data structures. Minimize synchronized block scope.")
                        .estimatedImpact("Improved throughput and reduced latency")
                        .build());
            }
        }

        // Heap histogram analysis
        if (heapHistogram.contains("byte[]") || heapHistogram.contains("[B")) {
            // Check if byte arrays dominate
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Check byte array allocations")
                    .description("byte[] is prominent in heap histogram. Common in apps with String buffers or I/O caching.")
                    .suggestedFix("Consider pooling byte buffers or using direct ByteBuffer for I/O-heavy operations")
                    .estimatedImpact("Reduced GC pressure from large temporary allocations")
                    .build());
        }

        // Process-specific recommendations based on known demo apps
        String name = jvm.getDisplayName().toLowerCase();
        if (name.contains("leaky")) {
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Unbounded collection growth in LeakyApp")
                    .description("LeakyApp.LEAK list grows without bounds, adding 100KB every 2 seconds")
                    .affectedMethod("LeakyApp.main (scheduled leak task)")
                    .suggestedFix("Add a maximum size check: if (LEAK.size() > MAX_SIZE) LEAK.remove(0);")
                    .estimatedImpact("Eliminates memory leak, prevents OOM")
                    .build());
        } else if (name.contains("cpuhog")) {
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Inefficient sort algorithm in CpuHogApp")
                    .description("Using O(n^2) bubble sort on 10,000 elements generates excessive CPU load")
                    .affectedMethod("CpuHogApp.inefficientSort()")
                    .suggestedFix("Replace bubble sort with Arrays.sort() (O(n log n) TimSort)")
                    .estimatedImpact("~99% CPU reduction for sort operations")
                    .build());
        } else if (name.contains("threadcontention")) {
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("Lock ordering issue in ThreadContentionApp")
                    .description("lockOrderAB and lockOrderBA acquire locks in different orders, causing near-deadlocks")
                    .affectedMethod("ThreadContentionApp.lockOrderAB() / lockOrderBA()")
                    .suggestedFix("Establish consistent lock ordering (always acquire lockA before lockB)")
                    .estimatedImpact("Eliminates contention timeouts and potential deadlocks")
                    .build());
        } else if (name.contains("gcpressure")) {
            recs.add(DiagnosisReport.CodeRecommendation.builder()
                    .title("High allocation rate in GcPressureApp")
                    .description("Rapid allocation of short-lived byte arrays creates excessive GC pressure")
                    .affectedMethod("GcPressureApp.youngGenChurn()")
                    .suggestedFix("Use object pooling for frequently allocated byte arrays. Consider ByteBuffer.allocateDirect() for I/O buffers.")
                    .estimatedImpact("50-80% reduction in GC pauses")
                    .build());
        }

        // Alert-based issues
        long criticalAlerts = alerts.stream()
                .filter(a -> "CRITICAL".equals(a.get("severity")))
                .count();
        if (criticalAlerts > 0) {
            healthScore -= (int) (criticalAlerts * 10);
        }

        healthScore = Math.max(0, Math.min(100, healthScore));

        String assessment;
        if (healthScore >= 80) {
            assessment = "JVM is generally healthy. Minor optimizations may improve performance.";
        } else if (healthScore >= 50) {
            assessment = "JVM has notable performance issues that should be addressed. See recommendations below.";
        } else {
            assessment = "JVM is in poor health with critical issues requiring immediate attention.";
        }

        return DiagnosisReport.builder()
                .pid(jvm.getPid())
                .processName(jvm.getDisplayName())
                .timestamp(Instant.now().toString())
                .healthScore(healthScore)
                .healthAssessment(assessment)
                .issues(issues)
                .recommendations(recs)
                .snapshot(buildSnapshot(jvm))
                .build();
    }

    private DiagnosisReport.JvmSnapshot buildSnapshot(JvmProcess jvm) {
        return DiagnosisReport.JvmSnapshot.builder()
                .heapUsedBytes(jvm.getHeapUsedBytes())
                .heapMaxBytes(jvm.getHeapMaxBytes())
                .heapUsagePercent(jvm.getHeapUsagePercent())
                .threadCount(jvm.getThreadCount())
                .cpuPercent(jvm.getCpuPercent())
                .status(jvm.getStatus())
                .gcCollectionCount(jvm.getGcCollectionCount())
                .gcCollectionTimeMs(jvm.getGcCollectionTimeMs())
                .build();
    }

    private String getHeapHistogram(int pid) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), "GC.class_histogram")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(10, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
                return "Timeout getting heap histogram";
            }
            StringBuilder sb = new StringBuilder();
            int lineCount = 0;
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null && lineCount < 30) {
                    sb.append(line).append("\n");
                    lineCount++;
                }
            }
            return sb.toString();
        } catch (Exception e) {
            return "Could not get heap histogram: " + e.getMessage();
        }
    }

    private String getThreadDumpSummary(int pid) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), "Thread.print")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(10, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
                return "Timeout getting thread dump";
            }
            StringBuilder sb = new StringBuilder();
            int threadCount = 0, runnable = 0, blocked = 0, waiting = 0;
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.startsWith("\"")) threadCount++;
                    if (line.contains("RUNNABLE")) runnable++;
                    if (line.contains("BLOCKED")) blocked++;
                    if (line.contains("WAITING") || line.contains("TIMED_WAITING")) waiting++;
                }
            }
            sb.append(String.format("Total threads: %d\n", threadCount));
            sb.append(String.format("RUNNABLE: %d\n", runnable));
            sb.append(String.format("BLOCKED: %d\n", blocked));
            sb.append(String.format("WAITING: %d\n", waiting));
            return sb.toString();
        } catch (Exception e) {
            return "Could not get thread dump: " + e.getMessage();
        }
    }

    private List<Map<String, Object>> getRecentAlertsForPid(int pid) {
        List<Map<String, Object>> all = alertService.getAlerts();
        List<Map<String, Object>> forPid = new ArrayList<>();
        for (Map<String, Object> alert : all) {
            if (alert.containsKey("pid") && ((Number) alert.get("pid")).intValue() == pid) {
                forPid.add(alert);
                if (forPid.size() >= 10) break;
            }
        }
        return forPid;
    }

    private int countOccurrences(String text, String search) {
        int count = 0;
        int idx = 0;
        while ((idx = text.indexOf(search, idx)) != -1) {
            count++;
            idx += search.length();
        }
        return count;
    }

    private String callClaudeApi(String userMessage) {
        try {
            String systemPrompt = buildSystemPrompt();

            JsonArray messages = new JsonArray();
            // Include recent history (last 10 messages)
            int start = Math.max(0, chatHistory.size() - 10);
            for (int i = start; i < chatHistory.size(); i++) {
                ChatMessage msg = chatHistory.get(i);
                JsonObject m = new JsonObject();
                m.addProperty("role", msg.getRole());
                m.addProperty("content", msg.getContent());
                messages.add(m);
            }

            JsonObject body = new JsonObject();
            body.addProperty("model", model);
            body.addProperty("max_tokens", 2048);
            body.addProperty("system", systemPrompt);
            body.add("messages", messages);

            Request request = new Request.Builder()
                    .url("https://api.anthropic.com/v1/messages")
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", "2023-06-01")
                    .header("content-type", "application/json")
                    .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
                    .build();

            try (Response resp = httpClient.newCall(request).execute()) {
                if (!resp.isSuccessful()) {
                    String errorBody = resp.body() != null ? resp.body().string() : "no body";
                    log.error("Claude API error {}: {}", resp.code(), errorBody);
                    return "I'm having trouble connecting to the AI service. Error: " + resp.code();
                }
                String responseBody = resp.body().string();
                JsonObject json = gson.fromJson(responseBody, JsonObject.class);
                return json.getAsJsonArray("content").get(0).getAsJsonObject().get("text").getAsString();
            }
        } catch (Exception e) {
            log.error("Claude API call failed", e);
            return "AI service temporarily unavailable: " + e.getMessage();
        }
    }

    private String generateLocalResponse(String userMessage) {
        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        String lower = userMessage.toLowerCase();

        if (lower.contains("diagnose") || lower.contains("diagnosis")) {
            // Auto-diagnose: pick the most troubled JVM or the first one
            JvmProcess target = jvms.stream()
                    .peek(JvmProcess::computeStatus)
                    .filter(j -> "CRITICAL".equals(j.getStatus()))
                    .findFirst()
                    .orElse(jvms.isEmpty() ? null : jvms.get(0));

            if (target != null) {
                DiagnosisReport report = diagnose(target.getPid());
                StringBuilder sb = new StringBuilder("**Diagnosis Report: " + report.getProcessName() + "**\n\n");
                sb.append("Health Score: **").append(report.getHealthScore()).append("/100**\n\n");
                sb.append(report.getHealthAssessment()).append("\n\n");
                if (!report.getIssues().isEmpty()) {
                    sb.append("**Issues Found:**\n");
                    for (var issue : report.getIssues()) {
                        sb.append(String.format("- [%s] %s: %s\n", issue.getSeverity(), issue.getTitle(), issue.getDescription()));
                    }
                    sb.append("\n");
                }
                if (!report.getRecommendations().isEmpty()) {
                    sb.append("**Recommendations:**\n");
                    for (var rec : report.getRecommendations()) {
                        sb.append(String.format("- **%s**: %s\n", rec.getTitle(), rec.getDescription()));
                        if (rec.getSuggestedFix() != null && !rec.getSuggestedFix().isEmpty()) {
                            sb.append("  Fix: `").append(rec.getSuggestedFix()).append("`\n");
                        }
                    }
                }
                return sb.toString();
            }
            return "No JVM processes found to diagnose.";
        }

        if (lower.contains("status") || lower.contains("overview") || lower.contains("how are")) {
            if (jvms.isEmpty()) {
                return "No JVM processes currently discovered. The discovery service scans every 15 seconds. " +
                       "If you've just started, processes should appear shortly.";
            }
            StringBuilder sb = new StringBuilder("**JVM Status Overview**\n\n");
            for (JvmProcess jvm : jvms) {
                jvm.computeStatus();
                sb.append(String.format("- **%s** (PID %d): %s \u2014 Heap %.1f%% (%s/%s), %d threads\n",
                        jvm.getDisplayName(), jvm.getPid(), jvm.getStatus(),
                        jvm.getHeapUsagePercent(),
                        formatBytes(jvm.getHeapUsedBytes()),
                        formatBytes(jvm.getHeapMaxBytes()),
                        jvm.getThreadCount()));
            }
            long critical = jvms.stream().filter(j -> "CRITICAL".equals(j.getStatus())).count();
            if (critical > 0) {
                sb.append(String.format("\n**%d process(es) in CRITICAL state** \u2014 consider taking a heap dump or starting a JFR recording.\n", critical));
            }
            return sb.toString();
        }

        if (lower.contains("heap") || lower.contains("memory")) {
            return analyzeMemory(jvms);
        }

        if (lower.contains("recommend") || lower.contains("suggest") || lower.contains("what should")) {
            return generateRecommendations(jvms);
        }

        return "I can help you analyze your JVM performance. Try asking:\n" +
               "- \"What's the status of my JVMs?\"\n" +
               "- \"Analyze heap memory usage\"\n" +
               "- \"Diagnose my JVMs\"\n" +
               "- \"What do you recommend?\"\n" +
               "- \"Help me diagnose high CPU\"\n\n" +
               "For full AI-powered analysis, set the ANTHROPIC_API_KEY environment variable.";
    }

    private String analyzeMemory(List<JvmProcess> jvms) {
        if (jvms.isEmpty()) return "No JVMs discovered to analyze.";

        StringBuilder sb = new StringBuilder("**Memory Analysis**\n\n");
        for (JvmProcess jvm : jvms) {
            sb.append(String.format("### %s (PID %d)\n", jvm.getDisplayName(), jvm.getPid()));
            if (jvm.getHeapMaxBytes() > 0) {
                sb.append(String.format("- Heap: %s / %s (%.1f%%)\n",
                        formatBytes(jvm.getHeapUsedBytes()), formatBytes(jvm.getHeapMaxBytes()),
                        jvm.getHeapUsagePercent()));
                if (jvm.getHeapUsagePercent() > 85) {
                    sb.append("- **WARNING**: Heap usage is critically high. Risk of OutOfMemoryError.\n");
                    sb.append("- **Recommendation**: Take a heap dump immediately to identify the leak.\n");
                } else if (jvm.getHeapUsagePercent() > 70) {
                    sb.append("- **Caution**: Heap usage is elevated. Monitor for growth trend.\n");
                }
            } else {
                sb.append("- Heap info not available (jcmd access may be restricted)\n");
            }
            sb.append("\n");
        }
        return sb.toString();
    }

    private String generateRecommendations(List<JvmProcess> jvms) {
        if (jvms.isEmpty()) return "No JVMs to analyze. Start some Java applications first.";

        StringBuilder sb = new StringBuilder("**Recommendations**\n\n");
        boolean hasIssues = false;
        for (JvmProcess jvm : jvms) {
            jvm.computeStatus();
            if ("CRITICAL".equals(jvm.getStatus()) || "WARNING".equals(jvm.getStatus())) {
                hasIssues = true;
                sb.append(String.format("**%s (PID %d)** \u2014 %s\n", jvm.getDisplayName(), jvm.getPid(), jvm.getStatus()));
                if (jvm.getHeapUsagePercent() > 85) {
                    sb.append("1. Take a heap dump to identify memory-hogging objects\n");
                    sb.append("2. Start a JFR ALLOC recording to track allocation hotspots\n");
                    sb.append("3. Check for collection objects that grow unbounded\n\n");
                } else if (jvm.getHeapUsagePercent() > 70) {
                    sb.append("1. Start a JFR CPU recording to profile execution\n");
                    sb.append("2. Monitor heap trend over the next few minutes\n\n");
                }
                if (jvm.getDeadlockedThreads() > 0) {
                    sb.append("- **DEADLOCK DETECTED**: Thread dump needed immediately\n\n");
                }
            }
        }
        if (!hasIssues) {
            sb.append("All JVMs are healthy. No immediate action needed.\n");
            sb.append("Tip: Start a JFR recording proactively to establish a performance baseline.\n");
        }
        return sb.toString();
    }

    private String buildSystemPrompt() {
        List<JvmProcess> jvms = discoveryService.getDiscoveredJvms();
        StringBuilder context = new StringBuilder();
        context.append("You are HeapWatch AI Advisor, an expert Java performance engineer. ");
        context.append("You help users diagnose JVM performance issues, analyze heap dumps, ");
        context.append("interpret JFR recordings, and provide actionable recommendations.\n\n");
        context.append("Current JVM processes:\n");
        for (JvmProcess jvm : jvms) {
            jvm.computeStatus();
            context.append(String.format("- %s (PID %d): heap %.1f%% (%s/%s), %d threads, status=%s\n",
                    jvm.getDisplayName(), jvm.getPid(),
                    jvm.getHeapUsagePercent(),
                    formatBytes(jvm.getHeapUsedBytes()),
                    formatBytes(jvm.getHeapMaxBytes()),
                    jvm.getThreadCount(),
                    jvm.getStatus()));
        }

        // Include recent alerts
        List<Map<String, Object>> alerts = alertService.getAlerts();
        if (!alerts.isEmpty()) {
            context.append("\nRecent alerts:\n");
            for (int i = 0; i < Math.min(5, alerts.size()); i++) {
                context.append(String.format("- [%s] %s\n", alerts.get(i).get("severity"), alerts.get(i).get("message")));
            }
        }

        context.append("\nAvailable tools: JFR recording (CPU, ALLOC, FULL), heap dump, thread dump via jcmd.\n");
        context.append("You can also perform one-click diagnosis that gathers all data automatically.\n");
        context.append("Be concise, specific, and actionable. Reference specific PIDs and metrics.\n");
        context.append("Provide method-level recommendations when possible.\n");
        return context.toString();
    }

    private String formatBytes(long bytes) {
        if (bytes <= 0) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024 * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    private static String getStr(JsonObject obj, String key, String defaultVal) {
        return obj.has(key) && !obj.get(key).isJsonNull() ? obj.get(key).getAsString() : defaultVal;
    }

    private static int getInt(JsonObject obj, String key, int defaultVal) {
        return obj.has(key) && !obj.get(key).isJsonNull() ? obj.get(key).getAsInt() : defaultVal;
    }
}
