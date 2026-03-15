import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.*;

/**
 * Demo app that leaks memory gradually.
 * Used to demonstrate HeapWatch's heap monitoring and alerting.
 */
public class LeakyApp {
    private static final List<byte[]> LEAK = new CopyOnWriteArrayList<>();
    private static final int LEAK_SIZE_BYTES = 1024 * 100; // 100KB per tick
    private static final int LEAK_INTERVAL_MS = 2000;

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8091;

        // Start HTTP server so Cloud Run health checks pass
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> {
            String response = "{\"status\":\"up\",\"leakedMB\":" +
                    (LEAK.size() * LEAK_SIZE_BYTES / (1024 * 1024)) + "}";
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            exchange.getResponseBody().write(response.getBytes());
            exchange.getResponseBody().close();
        });
        server.start();
        System.out.println("LeakyApp started on port " + port);

        // Leak memory gradually
        ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(() -> {
            byte[] chunk = new byte[LEAK_SIZE_BYTES];
            Arrays.fill(chunk, (byte) 0x42);
            LEAK.add(chunk);
            if (LEAK.size() % 50 == 0) {
                System.out.printf("Leaked %d MB total%n", LEAK.size() * LEAK_SIZE_BYTES / (1024 * 1024));
            }
        }, 0, LEAK_INTERVAL_MS, TimeUnit.MILLISECONDS);
    }
}
