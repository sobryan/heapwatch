## Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /build/flutter
COPY flutter_frontend/pubspec.yaml flutter_frontend/pubspec.lock ./
RUN flutter pub get

COPY flutter_frontend/ ./
RUN flutter build web --release

## Stage 2: Build Spring Boot hub
FROM eclipse-temurin:17-jdk AS builder

# Copy Flutter web build into Spring Boot static resources
WORKDIR /build/hub
COPY hub/gradlew hub/build.gradle hub/settings.gradle ./
COPY hub/gradle ./gradle
RUN ./gradlew --no-daemon dependencies 2>/dev/null || true

COPY hub/src ./src

# Copy Flutter build output into static resources
COPY --from=flutter-builder /build/flutter/build/web/ ./src/main/resources/static/

RUN ./gradlew --no-daemon bootJar -x test

# Compile demo apps
WORKDIR /build/demo
COPY demo-apps/leaky-app/LeakyApp.java ./leaky-app/
COPY demo-apps/cpu-hog/CpuHogApp.java ./cpu-hog/
COPY demo-apps/thread-contention/ThreadContentionApp.java ./thread-contention/
COPY demo-apps/gc-pressure/GcPressureApp.java ./gc-pressure/
RUN javac leaky-app/LeakyApp.java
RUN javac cpu-hog/CpuHogApp.java
RUN javac thread-contention/ThreadContentionApp.java
RUN javac gc-pressure/GcPressureApp.java

## Stage 3: Runtime
FROM eclipse-temurin:17-jdk

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Hub JAR (now includes Flutter web assets)
COPY --from=builder /build/hub/build/libs/heapwatch-hub.jar ./hub.jar

# Demo apps
COPY --from=builder /build/demo/leaky-app/*.class ./demo/leaky-app/
COPY --from=builder /build/demo/cpu-hog/*.class ./demo/cpu-hog/
COPY --from=builder /build/demo/thread-contention/*.class ./demo/thread-contention/
COPY --from=builder /build/demo/gc-pressure/*.class ./demo/gc-pressure/

# Startup script
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
