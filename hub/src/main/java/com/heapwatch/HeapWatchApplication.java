package com.heapwatch;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class HeapWatchApplication {
    public static void main(String[] args) {
        SpringApplication.run(HeapWatchApplication.class, args);
    }
}
