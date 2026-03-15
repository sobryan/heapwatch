import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Demo app that creates thread contention and near-deadlock conditions.
 * Multiple threads compete for shared locks, simulating lock contention
 * and thread pool saturation.
 * Used to demonstrate HeapWatch's thread monitoring capabilities.
 */
public class ThreadContentionApp {
    private static final AtomicLong operationCount = new AtomicLong(0);
    private static final AtomicLong contentionCount = new AtomicLong(0);

    // Shared locks that threads compete for
    private static final ReentrantLock lockA = new ReentrantLock();
    private static final ReentrantLock lockB = new ReentrantLock();
    private static final ReentrantLock lockC = new ReentrantLock();
    private static final Object monitorX = new Object();
    private static final Object monitorY = new Object();

    // Shared mutable state protected by locks
    private static final Map<String, Integer> sharedMap = new HashMap<>();
    private static final List<String> sharedList = new ArrayList<>();

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8093;

        // Start HTTP health endpoint
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> {
            String response = String.format(
                "{\"status\":\"up\",\"threads\":%d,\"operations\":%d,\"contentions\":%d}",
                Thread.activeCount(), operationCount.get(), contentionCount.get());
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            exchange.getResponseBody().write(response.getBytes());
            exchange.getResponseBody().close();
        });
        server.start();
        System.out.println("ThreadContentionApp started on port " + port);

        // Create a bounded thread pool that will get saturated
        ExecutorService pool = Executors.newFixedThreadPool(8);

        // Submit more tasks than threads to create saturation
        for (int i = 0; i < 12; i++) {
            final int taskId = i;
            pool.submit(() -> {
                System.out.println("Contention thread " + taskId + " started");
                while (true) {
                    try {
                        switch (taskId % 4) {
                            case 0 -> lockOrderAB(taskId);
                            case 1 -> lockOrderBA(taskId);
                            case 2 -> monitorContention(taskId);
                            case 3 -> mixedContention(taskId);
                        }
                        operationCount.incrementAndGet();
                        // Brief pause to prevent total CPU saturation
                        Thread.sleep(50 + (taskId * 10));
                    } catch (InterruptedException e) {
                        break;
                    }
                }
            });
        }
    }

    /**
     * Acquires locks in order A -> B, creating contention with lockOrderBA.
     */
    private static void lockOrderAB(int taskId) throws InterruptedException {
        if (!lockA.tryLock(200, TimeUnit.MILLISECONDS)) {
            contentionCount.incrementAndGet();
            return;
        }
        try {
            // Simulate work while holding lock A
            doWork(50);
            if (!lockB.tryLock(200, TimeUnit.MILLISECONDS)) {
                contentionCount.incrementAndGet();
                return;
            }
            try {
                // Critical section with both locks
                sharedMap.put("thread-" + taskId, sharedMap.getOrDefault("thread-" + taskId, 0) + 1);
                doWork(100);
            } finally {
                lockB.unlock();
            }
        } finally {
            lockA.unlock();
        }
    }

    /**
     * Acquires locks in order B -> A (reverse), creating near-deadlock with lockOrderAB.
     * Uses tryLock with timeout to avoid actual deadlock.
     */
    private static void lockOrderBA(int taskId) throws InterruptedException {
        if (!lockB.tryLock(200, TimeUnit.MILLISECONDS)) {
            contentionCount.incrementAndGet();
            return;
        }
        try {
            doWork(50);
            if (!lockA.tryLock(200, TimeUnit.MILLISECONDS)) {
                contentionCount.incrementAndGet();
                return;
            }
            try {
                sharedMap.put("thread-" + taskId, sharedMap.getOrDefault("thread-" + taskId, 0) + 1);
                doWork(100);
            } finally {
                lockA.unlock();
            }
        } finally {
            lockB.unlock();
        }
    }

    /**
     * Uses synchronized blocks to create monitor contention.
     */
    private static void monitorContention(int taskId) throws InterruptedException {
        synchronized (monitorX) {
            doWork(80);
            synchronized (monitorY) {
                sharedList.add("op-" + taskId + "-" + System.nanoTime());
                // Prevent unbounded growth
                if (sharedList.size() > 1000) {
                    sharedList.subList(0, 500).clear();
                }
                doWork(60);
            }
        }
    }

    /**
     * Mixed lock and monitor contention with lock C.
     */
    private static void mixedContention(int taskId) throws InterruptedException {
        if (!lockC.tryLock(200, TimeUnit.MILLISECONDS)) {
            contentionCount.incrementAndGet();
            return;
        }
        try {
            synchronized (monitorY) {
                sharedMap.merge("mixed-" + (taskId % 3), 1, Integer::sum);
                doWork(120);
            }
        } finally {
            lockC.unlock();
        }
    }

    /**
     * Simulates CPU work by doing busy computation for approximately the given milliseconds.
     */
    private static void doWork(int approxMs) {
        long end = System.nanoTime() + (approxMs * 1_000_000L);
        long sum = 0;
        while (System.nanoTime() < end) {
            for (int i = 0; i < 1000; i++) {
                sum += i * i;
            }
        }
        // Prevent optimization
        if (sum == Long.MIN_VALUE) System.out.println(sum);
    }
}
