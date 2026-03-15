package com.heapwatch.service;

import com.heapwatch.model.JvmProcess;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import javax.management.MBeanServerConnection;
import javax.management.ObjectName;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.lang.management.ManagementFactory;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * Discovers running JVM processes using jcmd and the Attach API.
 * Enriches with JMX metrics (heap, CPU, threads, GC).
 * No application restart required — attaches to live JVMs.
 */
@Slf4j
@Service
public class JvmDiscoveryService {

    private final Map<Integer, JvmProcess> discoveredJvms = new ConcurrentHashMap<>();
    private final int selfPid = getSelfPid();
    private final SimpMessagingTemplate messagingTemplate;

    public JvmDiscoveryService(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    public List<JvmProcess> getDiscoveredJvms() {
        return new ArrayList<>(discoveredJvms.values());
    }

    public Optional<JvmProcess> getJvm(int pid) {
        return Optional.ofNullable(discoveredJvms.get(pid));
    }

    @Scheduled(fixedDelayString = "${heapwatch.discovery.interval-seconds:15}000")
    public void discoverAndRefresh() {
        try {
            List<JvmProcess> found = discoverProcesses();
            Set<Integer> currentPids = new HashSet<>();
            for (JvmProcess jvm : found) {
                currentPids.add(jvm.getPid());
                enrichWithJmx(jvm);
                jvm.computeStatus();
                discoveredJvms.put(jvm.getPid(), jvm);
            }
            // Remove stale entries
            discoveredJvms.keySet().removeIf(pid -> !currentPids.contains(pid));
            log.debug("Discovered {} JVM processes", found.size());

            // Broadcast updated JVM list via WebSocket
            try {
                messagingTemplate.convertAndSend("/topic/jvms", getDiscoveredJvms());
            } catch (Exception wsEx) {
                log.debug("WebSocket broadcast failed: {}", wsEx.getMessage());
            }
        } catch (Exception e) {
            log.error("Discovery cycle failed", e);
        }
    }

    private List<JvmProcess> discoverProcesses() {
        List<JvmProcess> processes = new ArrayList<>();
        try {
            // Try jcmd first
            Process proc = new ProcessBuilder("jcmd")
                    .redirectErrorStream(true)
                    .start();
            boolean finished = proc.waitFor(10, TimeUnit.SECONDS);
            if (!finished) {
                proc.destroyForcibly();
                return processes;
            }
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    JvmProcess jvm = parseJcmdLine(line);
                    if (jvm != null) {
                        processes.add(jvm);
                    }
                }
            }
        } catch (Exception e) {
            log.warn("jcmd discovery failed, trying jps fallback: {}", e.getMessage());
            processes = discoverViaJps();
        }
        return processes;
    }

    private List<JvmProcess> discoverViaJps() {
        List<JvmProcess> processes = new ArrayList<>();
        try {
            Process proc = new ProcessBuilder("jps", "-l")
                    .redirectErrorStream(true)
                    .start();
            boolean finished = proc.waitFor(10, TimeUnit.SECONDS);
            if (!finished) {
                proc.destroyForcibly();
                return processes;
            }
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    JvmProcess jvm = parseJcmdLine(line);
                    if (jvm != null) {
                        processes.add(jvm);
                    }
                }
            }
        } catch (Exception e) {
            log.error("jps discovery also failed", e);
        }
        return processes;
    }

    private JvmProcess parseJcmdLine(String line) {
        line = line.trim();
        if (line.isEmpty()) return null;
        String[] parts = line.split("\\s+", 2);
        if (parts.length < 1) return null;
        try {
            int pid = Integer.parseInt(parts[0]);
            String mainClass = parts.length > 1 ? parts[1].trim() : "Unknown";
            if (pid == selfPid) return null;
            if (mainClass.contains("jcmd") || mainClass.contains("jps") || mainClass.equals("--")) return null;
            return JvmProcess.builder()
                    .pid(pid)
                    .mainClass(mainClass)
                    .displayName(friendlyName(mainClass))
                    .attachable(true)
                    .hostName(getHostName())
                    .agentId("local")
                    .build();
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private void enrichWithJmx(JvmProcess jvm) {
        // Try to get JMX info via jcmd commands (no JMX port needed)
        enrichHeapInfo(jvm);
        enrichThreadInfo(jvm);
        enrichVmInfo(jvm);
    }

    private void enrichHeapInfo(JvmProcess jvm) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(jvm.getPid()), "GC.heap_info")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(5, TimeUnit.SECONDS)) { proc.destroyForcibly(); return; }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("total") && line.contains("used")) {
                        var totalMatcher = java.util.regex.Pattern.compile("total\\s+(\\d+)K").matcher(line);
                        var usedMatcher = java.util.regex.Pattern.compile("used\\s+(\\d+)K").matcher(line);
                        if (totalMatcher.find()) jvm.setHeapMaxBytes(Long.parseLong(totalMatcher.group(1)) * 1024);
                        if (usedMatcher.find()) jvm.setHeapUsedBytes(Long.parseLong(usedMatcher.group(1)) * 1024);
                        break;
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Could not get heap info for pid {}: {}", jvm.getPid(), e.getMessage());
        }
    }

    private void enrichThreadInfo(JvmProcess jvm) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(jvm.getPid()), "Thread.print")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(5, TimeUnit.SECONDS)) { proc.destroyForcibly(); return; }
            int threadCount = 0;
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.startsWith("\"")) threadCount++;
                }
            }
            jvm.setThreadCount(threadCount);
        } catch (Exception e) {
            log.debug("Could not get thread info for pid {}", jvm.getPid());
        }
    }

    private void enrichVmInfo(JvmProcess jvm) {
        try {
            Process proc = new ProcessBuilder("jcmd", String.valueOf(jvm.getPid()), "VM.version")
                    .redirectErrorStream(true).start();
            if (!proc.waitFor(5, TimeUnit.SECONDS)) { proc.destroyForcibly(); return; }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("JDK") || line.contains("version")) {
                        jvm.setJvmVersion(line.trim());
                        break;
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Could not get VM version for pid {}", jvm.getPid());
        }
    }

    private String friendlyName(String mainClass) {
        if (mainClass == null || mainClass.trim().isEmpty()) return "Unknown";
        // Strip common prefixes
        String[] parts = mainClass.split("\\.");
        String name = parts[parts.length - 1];
        // Handle JAR paths
        if (name.endsWith(".jar")) {
            return name.replace(".jar", "");
        }
        return name;
    }

    private static int getSelfPid() {
        try {
            String jvmName = ManagementFactory.getRuntimeMXBean().getName();
            return Integer.parseInt(jvmName.split("@")[0]);
        } catch (Exception e) {
            return -1;
        }
    }

    private String getHostName() {
        try {
            return java.net.InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "unknown";
        }
    }
}
