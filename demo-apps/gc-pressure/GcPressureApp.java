import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Demo app that creates high GC pressure by rapidly allocating and discarding objects.
 * Exercises both young gen (short-lived objects) and old gen (promoted objects) GC.
 * Used to demonstrate HeapWatch's GC monitoring and analysis capabilities.
 */
public class GcPressureApp {
    private static final AtomicLong totalAllocated = new AtomicLong(0);
    private static final AtomicLong gcCycles = new AtomicLong(0);

    // Small cache that promotes objects to old gen before eviction
    private static final Map<String, byte[]> oldGenCache = new ConcurrentHashMap<>();
    private static final int MAX_CACHE_SIZE = 200;

    // Temporary list for medium-lived objects (survives a few young GCs)
    private static final List<byte[]> mediumLived = new CopyOnWriteArrayList<>();
    private static final int MAX_MEDIUM = 50;

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8094;

        // Start HTTP health endpoint
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> {
            Runtime rt = Runtime.getRuntime();
            String response = String.format(
                "{\"status\":\"up\",\"allocatedMB\":%d,\"heapUsedMB\":%d,\"heapMaxMB\":%d,\"cacheSize\":%d}",
                totalAllocated.get() / (1024 * 1024),
                (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024),
                rt.maxMemory() / (1024 * 1024),
                oldGenCache.size());
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            exchange.getResponseBody().write(response.getBytes());
            exchange.getResponseBody().close();
        });
        server.start();
        System.out.println("GcPressureApp started on port " + port);

        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(4);

        // Task 1: Rapid short-lived allocations (young gen churn)
        scheduler.scheduleAtFixedRate(() -> {
            try {
                youngGenChurn();
            } catch (Exception e) {
                System.err.println("Young gen churn error: " + e.getMessage());
            }
        }, 0, 100, TimeUnit.MILLISECONDS);

        // Task 2: Medium-lived allocations (objects that survive a few GC cycles)
        scheduler.scheduleAtFixedRate(() -> {
            try {
                mediumLifeAllocations();
            } catch (Exception e) {
                System.err.println("Medium life allocation error: " + e.getMessage());
            }
        }, 0, 500, TimeUnit.MILLISECONDS);

        // Task 3: Old gen promotions (cached objects that live longer)
        scheduler.scheduleAtFixedRate(() -> {
            try {
                oldGenPromotion();
            } catch (Exception e) {
                System.err.println("Old gen promotion error: " + e.getMessage());
            }
        }, 0, 1000, TimeUnit.MILLISECONDS);

        // Task 4: Periodic large temporary allocations (triggers full GC)
        scheduler.scheduleAtFixedRate(() -> {
            try {
                largeTemporaryAllocation();
            } catch (Exception e) {
                System.err.println("Large temp allocation error: " + e.getMessage());
            }
        }, 5, 3, TimeUnit.SECONDS);
    }

    /**
     * Rapidly allocates and discards small objects to churn young gen.
     */
    private static void youngGenChurn() {
        Random rand = new Random();
        for (int i = 0; i < 500; i++) {
            // Allocate small byte arrays (1-8 KB) that die immediately
            byte[] temp = new byte[1024 + rand.nextInt(7 * 1024)];
            Arrays.fill(temp, (byte) (i & 0xFF));
            totalAllocated.addAndGet(temp.length);

            // Allocate and discard Strings
            String s = "alloc-" + System.nanoTime() + "-" + rand.nextInt(10000);
            totalAllocated.addAndGet(s.length() * 2L); // approximate

            // Allocate small lists and maps
            List<Integer> list = new ArrayList<>();
            for (int j = 0; j < 100; j++) {
                list.add(rand.nextInt());
            }
            totalAllocated.addAndGet(100 * 16L); // approximate
        }
    }

    /**
     * Creates objects that survive a few young GC cycles before being discarded.
     */
    private static void mediumLifeAllocations() {
        Random rand = new Random();
        // Add medium-lived objects
        byte[] data = new byte[10 * 1024 + rand.nextInt(20 * 1024)]; // 10-30 KB
        Arrays.fill(data, (byte) 0xAB);
        mediumLived.add(data);
        totalAllocated.addAndGet(data.length);

        // Evict oldest if over limit
        while (mediumLived.size() > MAX_MEDIUM) {
            mediumLived.remove(0);
        }
    }

    /**
     * Promotes objects to old gen by caching them for a while.
     */
    private static void oldGenPromotion() {
        Random rand = new Random();
        // Add to cache (these survive long enough to be promoted to old gen)
        String key = "cache-" + (rand.nextInt(MAX_CACHE_SIZE * 2));
        byte[] value = new byte[5 * 1024 + rand.nextInt(15 * 1024)]; // 5-20 KB
        Arrays.fill(value, (byte) 0xCD);
        oldGenCache.put(key, value);
        totalAllocated.addAndGet(value.length);

        // Evict random entries to create old gen garbage
        if (oldGenCache.size() > MAX_CACHE_SIZE) {
            List<String> keys = new ArrayList<>(oldGenCache.keySet());
            Collections.shuffle(keys);
            for (int i = 0; i < keys.size() - MAX_CACHE_SIZE; i++) {
                oldGenCache.remove(keys.get(i));
            }
        }
    }

    /**
     * Periodically allocates large temporary byte arrays to trigger major/full GC.
     */
    private static void largeTemporaryAllocation() {
        Random rand = new Random();
        // Allocate a large temporary array (512 KB - 2 MB)
        int size = 512 * 1024 + rand.nextInt(1536 * 1024);
        byte[] large = new byte[size];
        Arrays.fill(large, (byte) 0xEF);
        totalAllocated.addAndGet(size);

        // Do some work with it to prevent optimization
        long sum = 0;
        for (int i = 0; i < large.length; i += 64) {
            sum += large[i];
        }
        if (sum == Long.MIN_VALUE) System.out.println(sum);

        gcCycles.incrementAndGet();
        if (gcCycles.get() % 10 == 0) {
            Runtime rt = Runtime.getRuntime();
            System.out.printf("GC Pressure: allocated %d MB total, heap %d/%d MB, cache size %d%n",
                totalAllocated.get() / (1024 * 1024),
                (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024),
                rt.maxMemory() / (1024 * 1024),
                oldGenCache.size());
        }
    }
}
