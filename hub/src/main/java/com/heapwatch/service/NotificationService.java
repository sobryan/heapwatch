package com.heapwatch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * In-memory notification center that stores events for:
 * alert triggers, recording completions, diagnosis completions.
 */
@Slf4j
@Service
public class NotificationService {

    private static final int MAX_NOTIFICATIONS = 200;

    private final List<Map<String, Object>> notifications = new CopyOnWriteArrayList<>();
    private final AtomicInteger unreadCount = new AtomicInteger(0);

    /**
     * Add a notification.
     * @param type ALERT, RECORDING, DIAGNOSIS, HEAP_DUMP
     * @param title Short title
     * @param message Descriptive message
     * @param severity INFO, WARNING, CRITICAL
     */
    public void addNotification(String type, String title, String message, String severity) {
        Map<String, Object> notification = new LinkedHashMap<>();
        notification.put("id", UUID.randomUUID().toString().substring(0, 8));
        notification.put("type", type);
        notification.put("title", title);
        notification.put("message", message);
        notification.put("severity", severity);
        notification.put("timestamp", Instant.now().toString());
        notification.put("read", false);

        notifications.add(0, notification); // newest first
        unreadCount.incrementAndGet();

        // Evict old
        while (notifications.size() > MAX_NOTIFICATIONS) {
            Map<String, Object> removed = notifications.remove(notifications.size() - 1);
            if (!Boolean.TRUE.equals(removed.get("read"))) {
                unreadCount.decrementAndGet();
            }
        }

        log.debug("Notification added: [{}] {} - {}", type, title, message);
    }

    public Map<String, Object> getNotifications() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("notifications", new ArrayList<>(notifications));
        result.put("unreadCount", Math.max(0, unreadCount.get()));
        result.put("totalCount", notifications.size());
        return result;
    }

    public boolean deleteNotification(String id) {
        Iterator<Map<String, Object>> it = notifications.iterator();
        while (it.hasNext()) {
            Map<String, Object> n = it.next();
            if (id.equals(n.get("id"))) {
                notifications.remove(n);
                if (!Boolean.TRUE.equals(n.get("read"))) {
                    unreadCount.decrementAndGet();
                }
                return true;
            }
        }
        return false;
    }

    public void markAllRead() {
        for (Map<String, Object> n : notifications) {
            n.put("read", true);
        }
        unreadCount.set(0);
    }

    public int getUnreadCount() {
        return Math.max(0, unreadCount.get());
    }
}
