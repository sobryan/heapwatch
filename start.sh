#!/bin/bash
set -e

PORT="${PORT:-8080}"

echo "=== HeapWatch Demo Starting ==="
echo "Hub port: $PORT"

# Start demo apps in background with constrained heap
echo "Starting LeakyApp (PID will be logged)..."
java -Xmx128m -Xms64m -cp /app/demo/leaky-app LeakyApp 8091 &
LEAKY_PID=$!
echo "LeakyApp started with PID $LEAKY_PID"

echo "Starting CpuHogApp (PID will be logged)..."
java -Xmx128m -Xms64m -cp /app/demo/cpu-hog CpuHogApp 8092 &
CPU_PID=$!
echo "CpuHogApp started with PID $CPU_PID"

echo "Starting ThreadContentionApp (PID will be logged)..."
java -Xmx128m -Xms64m -cp /app/demo/thread-contention ThreadContentionApp 8093 &
THREAD_PID=$!
echo "ThreadContentionApp started with PID $THREAD_PID"

echo "Starting GcPressureApp (PID will be logged)..."
java -Xmx128m -Xms64m -cp /app/demo/gc-pressure GcPressureApp 8094 &
GC_PID=$!
echo "GcPressureApp started with PID $GC_PID"

# Give demo apps a moment to start
sleep 2

# Start HeapWatch hub (foreground)
echo "Starting HeapWatch Hub on port $PORT..."
exec java -Xmx512m \
    -Dserver.port="$PORT" \
    -jar /app/hub.jar
