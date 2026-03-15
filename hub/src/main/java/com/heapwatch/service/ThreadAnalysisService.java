package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Analyzes thread dumps from target JVMs using jcmd Thread.print.
 * Provides thread state distribution, deadlock detection, blocked chain analysis,
 * lock contention metrics, and top stack frames.
 */
@Slf4j
@Service
public class ThreadAnalysisService {

    private static final Pattern THREAD_NAME_PATTERN = Pattern.compile("^\"(.+?)\"");
    private static final Pattern THREAD_STATE_PATTERN = Pattern.compile("java\\.lang\\.Thread\\.State:\\s+(\\S+)");
    private static final Pattern LOCK_PATTERN = Pattern.compile("- waiting to lock <(0x[0-9a-f]+)>.*owned by \"(.+?)\"");
    private static final Pattern HOLDING_LOCK_PATTERN = Pattern.compile("- locked <(0x[0-9a-f]+)>");
    private static final Pattern DEADLOCK_HEADER_PATTERN = Pattern.compile("Found (\\d+) deadlock");

    /**
     * Performs full thread dump analysis on the given PID.
     */
    public Map<String, Object> analyze(int pid) {
        String rawDump = getThreadDump(pid);
        if (rawDump.startsWith("Error:") || rawDump.startsWith("Timeout")) {
            return Map.of("error", rawDump, "pid", pid);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("pid", pid);

        // Parse threads
        List<ThreadInfo> threads = parseThreads(rawDump);
        result.put("totalThreads", threads.size());

        // State distribution
        Map<String, Integer> stateDistribution = computeStateDistribution(threads);
        result.put("stateDistribution", stateDistribution);

        // Deadlock detection
        List<Map<String, Object>> deadlocks = detectDeadlocks(rawDump, threads);
        result.put("deadlocks", deadlocks);
        result.put("deadlockCount", deadlocks.size());

        // Blocked chains
        List<Map<String, Object>> blockedChains = findBlockedChains(threads);
        result.put("blockedChains", blockedChains);

        // Lock contention - most contended monitors
        List<Map<String, Object>> lockContention = findLockContention(threads);
        result.put("lockContention", lockContention);

        // Top stack frames
        List<Map<String, Object>> topFrames = findTopStackFrames(threads);
        result.put("topStackFrames", topFrames);

        return result;
    }

    private String getThreadDump(int pid) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(pid), "Thread.print")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(15, TimeUnit.SECONDS)) {
                proc.destroyForcibly();
                return "Timeout getting thread dump";
            }
            StringBuilder sb = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
            }
            return sb.toString();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    private List<ThreadInfo> parseThreads(String dump) {
        List<ThreadInfo> threads = new ArrayList<>();
        String[] lines = dump.split("\n");
        ThreadInfo current = null;

        for (String line : lines) {
            Matcher nameMatcher = THREAD_NAME_PATTERN.matcher(line);
            if (nameMatcher.find()) {
                if (current != null) {
                    threads.add(current);
                }
                current = new ThreadInfo();
                current.name = nameMatcher.group(1);
                current.stackFrames = new ArrayList<>();
                current.locksHeld = new ArrayList<>();
                current.locksWaiting = new ArrayList<>();
                continue;
            }

            if (current != null) {
                Matcher stateMatcher = THREAD_STATE_PATTERN.matcher(line);
                if (stateMatcher.find()) {
                    current.state = stateMatcher.group(1);
                }

                Matcher lockMatcher = LOCK_PATTERN.matcher(line);
                if (lockMatcher.find()) {
                    current.locksWaiting.add(new LockInfo(lockMatcher.group(1), lockMatcher.group(2)));
                }

                Matcher holdingMatcher = HOLDING_LOCK_PATTERN.matcher(line);
                if (holdingMatcher.find()) {
                    current.locksHeld.add(holdingMatcher.group(1));
                }

                String trimmed = line.trim();
                if (trimmed.startsWith("at ")) {
                    current.stackFrames.add(trimmed.substring(3));
                }
            }
        }
        if (current != null) {
            threads.add(current);
        }
        return threads;
    }

    private Map<String, Integer> computeStateDistribution(List<ThreadInfo> threads) {
        Map<String, Integer> dist = new LinkedHashMap<>();
        dist.put("RUNNABLE", 0);
        dist.put("BLOCKED", 0);
        dist.put("WAITING", 0);
        dist.put("TIMED_WAITING", 0);

        for (ThreadInfo t : threads) {
            if (t.state != null) {
                dist.merge(t.state, 1, Integer::sum);
            }
        }
        return dist;
    }

    private List<Map<String, Object>> detectDeadlocks(String dump, List<ThreadInfo> threads) {
        List<Map<String, Object>> deadlocks = new ArrayList<>();

        // Check if jcmd already detected deadlocks in the dump
        Matcher dlMatcher = DEADLOCK_HEADER_PATTERN.matcher(dump);
        if (dlMatcher.find()) {
            Map<String, Object> dl = new LinkedHashMap<>();
            dl.put("type", "JVM_DETECTED");
            dl.put("message", "JVM detected " + dlMatcher.group(1) + " deadlock(s)");

            // Extract deadlocked thread names
            List<String> involvedThreads = new ArrayList<>();
            boolean inDeadlockSection = false;
            for (String line : dump.split("\n")) {
                if (line.contains("Found") && line.contains("deadlock")) {
                    inDeadlockSection = true;
                    continue;
                }
                if (inDeadlockSection && line.startsWith("\"")) {
                    Matcher nm = THREAD_NAME_PATTERN.matcher(line);
                    if (nm.find()) {
                        involvedThreads.add(nm.group(1));
                    }
                }
            }
            dl.put("threads", involvedThreads);
            deadlocks.add(dl);
        }

        // Manual circular-wait detection
        Map<String, String> waitGraph = new LinkedHashMap<>(); // thread -> blockedBy
        for (ThreadInfo t : threads) {
            if ("BLOCKED".equals(t.state) && !t.locksWaiting.isEmpty()) {
                waitGraph.put(t.name, t.locksWaiting.get(0).owner);
            }
        }

        // Find cycles
        Set<String> visited = new HashSet<>();
        for (String start : waitGraph.keySet()) {
            if (visited.contains(start)) continue;
            List<String> chain = new ArrayList<>();
            String node = start;
            Set<String> path = new LinkedHashSet<>();
            while (node != null && !path.contains(node)) {
                path.add(node);
                chain.add(node);
                node = waitGraph.get(node);
            }
            if (node != null && path.contains(node)) {
                // Found a cycle
                int cycleStart = chain.indexOf(node);
                List<String> cycle = chain.subList(cycleStart, chain.size());
                if (cycle.size() >= 2) {
                    Map<String, Object> dl = new LinkedHashMap<>();
                    dl.put("type", "CIRCULAR_WAIT");
                    dl.put("message", "Circular wait chain detected: " + String.join(" -> ", cycle) + " -> " + cycle.get(0));
                    dl.put("threads", cycle);
                    deadlocks.add(dl);
                }
                visited.addAll(cycle);
            }
            visited.addAll(path);
        }

        return deadlocks;
    }

    private List<Map<String, Object>> findBlockedChains(List<ThreadInfo> threads) {
        List<Map<String, Object>> chains = new ArrayList<>();

        for (ThreadInfo t : threads) {
            if ("BLOCKED".equals(t.state) && !t.locksWaiting.isEmpty()) {
                Map<String, Object> chain = new LinkedHashMap<>();
                chain.put("blockedThread", t.name);
                chain.put("waitingForLock", t.locksWaiting.get(0).address);
                chain.put("blockedBy", t.locksWaiting.get(0).owner);
                if (!t.stackFrames.isEmpty()) {
                    chain.put("blockedAt", t.stackFrames.get(0));
                }
                chains.add(chain);
            }
        }

        return chains;
    }

    private List<Map<String, Object>> findLockContention(List<ThreadInfo> threads) {
        // Count how many threads are waiting on each lock
        Map<String, Integer> lockWaitCounts = new LinkedHashMap<>();
        Map<String, String> lockOwners = new LinkedHashMap<>();

        for (ThreadInfo t : threads) {
            for (LockInfo lock : t.locksWaiting) {
                lockWaitCounts.merge(lock.address, 1, Integer::sum);
                lockOwners.putIfAbsent(lock.address, lock.owner);
            }
        }

        List<Map<String, Object>> contention = new ArrayList<>();
        lockWaitCounts.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                .limit(10)
                .forEach(e -> {
                    Map<String, Object> entry = new LinkedHashMap<>();
                    entry.put("lockAddress", e.getKey());
                    entry.put("waitingThreads", e.getValue());
                    entry.put("owner", lockOwners.getOrDefault(e.getKey(), "unknown"));
                    contention.add(entry);
                });

        return contention;
    }

    private List<Map<String, Object>> findTopStackFrames(List<ThreadInfo> threads) {
        Map<String, Integer> frameCounts = new LinkedHashMap<>();

        for (ThreadInfo t : threads) {
            // Only count the top 3 frames for each thread
            int limit = Math.min(3, t.stackFrames.size());
            for (int i = 0; i < limit; i++) {
                String frame = t.stackFrames.get(i);
                // Skip common JDK internal frames
                if (frame.startsWith("java.lang.Object.wait") ||
                    frame.startsWith("java.lang.Thread.sleep") ||
                    frame.startsWith("sun.misc.Unsafe.park") ||
                    frame.startsWith("jdk.internal.misc.Unsafe.park")) {
                    continue;
                }
                frameCounts.merge(frame, 1, Integer::sum);
            }
        }

        List<Map<String, Object>> topFrames = new ArrayList<>();
        frameCounts.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                .limit(15)
                .forEach(e -> {
                    Map<String, Object> entry = new LinkedHashMap<>();
                    entry.put("method", e.getKey());
                    entry.put("count", e.getValue());
                    topFrames.add(entry);
                });

        return topFrames;
    }

    // Internal data classes
    private static class ThreadInfo {
        String name;
        String state;
        List<String> stackFrames;
        List<String> locksHeld;
        List<LockInfo> locksWaiting;
    }

    private static class LockInfo {
        String address;
        String owner;

        LockInfo(String address, String owner) {
            this.address = address;
            this.owner = owner;
        }
    }
}
