import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.*;

/**
 * Demo app that generates CPU load with inefficient operations.
 * Used to demonstrate HeapWatch's CPU profiling capabilities.
 */
public class CpuHogApp {
    private static volatile boolean running = true;

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8092;

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> {
            String response = "{\"status\":\"up\",\"threads\":" + Thread.activeCount() + "}";
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            exchange.getResponseBody().write(response.getBytes());
            exchange.getResponseBody().close();
        });
        server.start();
        System.out.println("CpuHogApp started on port " + port);

        // Spawn CPU-intensive threads
        int numThreads = 2;
        ExecutorService pool = Executors.newFixedThreadPool(numThreads);

        for (int i = 0; i < numThreads; i++) {
            final int threadId = i;
            pool.submit(() -> {
                System.out.println("CPU thread " + threadId + " started");
                while (running) {
                    // Inefficient sort — generates CPU flame
                    inefficientSort(10000);
                    // Brief pause to avoid 100% CPU
                    try { Thread.sleep(100); } catch (InterruptedException e) { break; }
                }
            });
        }
    }

    /**
     * Deliberately inefficient bubble sort to generate CPU hotspot.
     */
    private static void inefficientSort(int size) {
        Random rand = new Random();
        int[] arr = new int[size];
        for (int i = 0; i < size; i++) arr[i] = rand.nextInt();

        // Bubble sort O(n^2)
        for (int i = 0; i < arr.length - 1; i++) {
            for (int j = 0; j < arr.length - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    int tmp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = tmp;
                }
            }
        }
    }
}
