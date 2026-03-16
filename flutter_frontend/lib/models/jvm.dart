class Jvm {
  final int pid;
  final String displayName;
  final String? mainClass;
  final String? hostName;
  final int heapUsedBytes;
  final int heapMaxBytes;
  final double heapUsagePercent;
  final int threadCount;
  final double cpuUsagePercent;
  final String status;
  final String? jvmVersion;
  final String? lastSeen;

  Jvm({
    required this.pid,
    required this.displayName,
    this.mainClass,
    this.hostName,
    this.heapUsedBytes = 0,
    this.heapMaxBytes = 0,
    this.heapUsagePercent = 0,
    this.threadCount = 0,
    this.cpuUsagePercent = 0,
    this.status = 'HEALTHY',
    this.jvmVersion,
    this.lastSeen,
  });

  factory Jvm.fromJson(Map<String, dynamic> json) {
    return Jvm(
      pid: json['pid'] ?? 0,
      displayName: json['displayName'] ?? 'Unknown',
      mainClass: json['mainClass'],
      hostName: json['hostName'],
      heapUsedBytes: (json['heapUsedBytes'] ?? 0).toInt(),
      heapMaxBytes: (json['heapMaxBytes'] ?? 0).toInt(),
      heapUsagePercent: (json['heapUsagePercent'] ?? 0).toDouble(),
      threadCount: (json['threadCount'] ?? 0).toInt(),
      cpuUsagePercent: (json['cpuUsagePercent'] ?? 0).toDouble(),
      status: json['status'] ?? 'HEALTHY',
      jvmVersion: json['jvmVersion'],
      lastSeen: json['lastSeen'],
    );
  }
}

class JfrRecording {
  final String id;
  final int pid;
  final String processName;
  final String profileType;
  final int durationSeconds;
  final String status;
  final int fileSizeBytes;
  final String? startTime;
  final String? endTime;

  JfrRecording({
    required this.id,
    required this.pid,
    required this.processName,
    required this.profileType,
    required this.durationSeconds,
    required this.status,
    this.fileSizeBytes = 0,
    this.startTime,
    this.endTime,
  });

  factory JfrRecording.fromJson(Map<String, dynamic> json) {
    return JfrRecording(
      id: json['id']?.toString() ?? '',
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? '',
      profileType: json['profileType'] ?? 'CPU',
      durationSeconds: (json['durationSeconds'] ?? 0).toInt(),
      status: json['status'] ?? 'PENDING',
      fileSizeBytes: (json['fileSizeBytes'] ?? 0).toInt(),
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }
}

class HeapDump {
  final String id;
  final int pid;
  final String processName;
  final String status;
  final int fileSizeBytes;
  final String? createdAt;

  HeapDump({
    required this.id,
    required this.pid,
    required this.processName,
    required this.status,
    this.fileSizeBytes = 0,
    this.createdAt,
  });

  factory HeapDump.fromJson(Map<String, dynamic> json) {
    return HeapDump(
      id: json['id']?.toString() ?? '',
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? '',
      status: json['status'] ?? 'PENDING',
      fileSizeBytes: (json['fileSizeBytes'] ?? 0).toInt(),
      createdAt: json['createdAt'],
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final String? timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      timestamp: json['timestamp'],
    );
  }
}

/// JFR recording analysis results
class JfrAnalysis {
  final String recordingId;
  final int pid;
  final String processName;
  final String profileType;
  final int durationSeconds;
  final int fileSizeBytes;
  final List<CpuHotspot> cpuHotspots;
  final List<AllocationHotspot> allocationHotspots;
  final Map<String, dynamic> threadActivity;
  final Map<String, dynamic> gcSummary;

  JfrAnalysis({
    required this.recordingId,
    required this.pid,
    required this.processName,
    required this.profileType,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.cpuHotspots,
    required this.allocationHotspots,
    required this.threadActivity,
    required this.gcSummary,
  });

  factory JfrAnalysis.fromJson(Map<String, dynamic> json) {
    final cpuList = (json['cpuHotspots'] as List? ?? [])
        .map((e) => CpuHotspot.fromJson(e as Map<String, dynamic>))
        .toList();
    final allocList = (json['allocationHotspots'] as List? ?? [])
        .map((e) => AllocationHotspot.fromJson(e as Map<String, dynamic>))
        .toList();
    return JfrAnalysis(
      recordingId: json['recordingId'] ?? '',
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? '',
      profileType: json['profileType'] ?? '',
      durationSeconds: (json['durationSeconds'] ?? 0).toInt(),
      fileSizeBytes: (json['fileSizeBytes'] ?? 0).toInt(),
      cpuHotspots: cpuList,
      allocationHotspots: allocList,
      threadActivity: Map<String, dynamic>.from(json['threadActivity'] ?? {}),
      gcSummary: Map<String, dynamic>.from(json['gcSummary'] ?? {}),
    );
  }
}

class CpuHotspot {
  final String? method;
  final int samples;
  final String? note;
  final String? error;

  CpuHotspot({this.method, this.samples = 0, this.note, this.error});

  factory CpuHotspot.fromJson(Map<String, dynamic> json) {
    return CpuHotspot(
      method: json['method'],
      samples: (json['samples'] ?? 0).toInt(),
      note: json['note'],
      error: json['error'],
    );
  }
}

class AllocationHotspot {
  final String? className;
  final int allocationCount;
  final int totalBytes;
  final String? totalFormatted;
  final String? note;
  final String? error;

  AllocationHotspot({
    this.className,
    this.allocationCount = 0,
    this.totalBytes = 0,
    this.totalFormatted,
    this.note,
    this.error,
  });

  factory AllocationHotspot.fromJson(Map<String, dynamic> json) {
    return AllocationHotspot(
      className: json['className'],
      allocationCount: (json['allocationCount'] ?? 0).toInt(),
      totalBytes: (json['totalBytes'] ?? 0).toInt(),
      totalFormatted: json['totalFormatted'],
      note: json['note'],
      error: json['error'],
    );
  }
}

/// Heap dump analysis results
class HeapDumpAnalysis {
  final String dumpId;
  final int pid;
  final String processName;
  final int fileSizeBytes;
  final String fileSizeFormatted;
  final List<HeapObject> topObjectsBySize;
  final Map<String, dynamic> summary;
  final List<LeakSuspect> leakSuspects;

  HeapDumpAnalysis({
    required this.dumpId,
    required this.pid,
    required this.processName,
    required this.fileSizeBytes,
    required this.fileSizeFormatted,
    required this.topObjectsBySize,
    required this.summary,
    required this.leakSuspects,
  });

  factory HeapDumpAnalysis.fromJson(Map<String, dynamic> json) {
    final objects = (json['topObjectsBySize'] as List? ?? [])
        .map((e) => HeapObject.fromJson(e as Map<String, dynamic>))
        .toList();
    final suspects = (json['leakSuspects'] as List? ?? [])
        .map((e) => LeakSuspect.fromJson(e as Map<String, dynamic>))
        .toList();
    return HeapDumpAnalysis(
      dumpId: json['dumpId'] ?? '',
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? '',
      fileSizeBytes: (json['fileSizeBytes'] ?? 0).toInt(),
      fileSizeFormatted: json['fileSizeFormatted'] ?? '',
      topObjectsBySize: objects,
      summary: Map<String, dynamic>.from(json['summary'] ?? {}),
      leakSuspects: suspects,
    );
  }
}

class HeapObject {
  final int rank;
  final int instances;
  final int bytes;
  final String className;
  final String? bytesFormatted;
  final String? note;
  final String? error;

  HeapObject({
    this.rank = 0,
    this.instances = 0,
    this.bytes = 0,
    this.className = '',
    this.bytesFormatted,
    this.note,
    this.error,
  });

  factory HeapObject.fromJson(Map<String, dynamic> json) {
    return HeapObject(
      rank: (json['rank'] ?? 0).toInt(),
      instances: (json['instances'] ?? 0).toInt(),
      bytes: (json['bytes'] ?? 0).toInt(),
      className: json['className'] ?? '',
      bytesFormatted: json['bytesFormatted'],
      note: json['note'],
      error: json['error'],
    );
  }
}

class LeakSuspect {
  final String className;
  final String reason;
  final String severity;
  final String recommendation;

  LeakSuspect({
    required this.className,
    required this.reason,
    required this.severity,
    required this.recommendation,
  });

  factory LeakSuspect.fromJson(Map<String, dynamic> json) {
    return LeakSuspect(
      className: json['className'] ?? '',
      reason: json['reason'] ?? '',
      severity: json['severity'] ?? 'INFO',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

/// Metrics snapshot for time-series trending
class MetricsSnapshot {
  final String timestamp;
  final int heapUsed;
  final int heapMax;
  final double heapPercent;
  final int threadCount;
  final double cpuPercent;
  final int gcCount;
  final int gcTimeMs;

  MetricsSnapshot({
    required this.timestamp,
    this.heapUsed = 0,
    this.heapMax = 0,
    this.heapPercent = 0,
    this.threadCount = 0,
    this.cpuPercent = 0,
    this.gcCount = 0,
    this.gcTimeMs = 0,
  });

  factory MetricsSnapshot.fromJson(Map<String, dynamic> json) {
    return MetricsSnapshot(
      timestamp: json['timestamp'] ?? '',
      heapUsed: (json['heapUsed'] ?? 0).toInt(),
      heapMax: (json['heapMax'] ?? 0).toInt(),
      heapPercent: (json['heapPercent'] ?? 0).toDouble(),
      threadCount: (json['threadCount'] ?? 0).toInt(),
      cpuPercent: (json['cpuPercent'] ?? 0).toDouble(),
      gcCount: (json['gcCount'] ?? 0).toInt(),
      gcTimeMs: (json['gcTimeMs'] ?? 0).toInt(),
    );
  }
}

class MetricsHistory {
  final int pid;
  final String processName;
  final int snapshotCount;
  final int intervalSeconds;
  final List<MetricsSnapshot> snapshots;

  MetricsHistory({
    required this.pid,
    required this.processName,
    this.snapshotCount = 0,
    this.intervalSeconds = 15,
    this.snapshots = const [],
  });

  factory MetricsHistory.fromJson(Map<String, dynamic> json) {
    final snaps = (json['snapshots'] as List? ?? [])
        .map((e) => MetricsSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
    return MetricsHistory(
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? 'Unknown',
      snapshotCount: (json['snapshotCount'] ?? 0).toInt(),
      intervalSeconds: (json['intervalSeconds'] ?? 15).toInt(),
      snapshots: snaps,
    );
  }
}

/// Alert triggered by threshold rules
class Alert {
  final String id;
  final String ruleId;
  final String ruleName;
  final int pid;
  final String processName;
  final String metric;
  final double value;
  final double threshold;
  final String severity;
  final String timestamp;
  final String message;

  Alert({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.pid,
    required this.processName,
    required this.metric,
    required this.value,
    required this.threshold,
    required this.severity,
    required this.timestamp,
    required this.message,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? '',
      ruleId: json['ruleId'] ?? '',
      ruleName: json['ruleName'] ?? '',
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? '',
      metric: json['metric'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      threshold: (json['threshold'] ?? 0).toDouble(),
      severity: json['severity'] ?? 'INFO',
      timestamp: json['timestamp'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

/// Comprehensive diagnosis report from one-click diagnose
class DiagnosisReport {
  final int pid;
  final String processName;
  final String timestamp;
  final int healthScore;
  final String healthAssessment;
  final List<DiagnosisIssue> issues;
  final List<CodeRecommendation> recommendations;
  final JvmSnapshot? snapshot;

  DiagnosisReport({
    required this.pid,
    required this.processName,
    required this.timestamp,
    required this.healthScore,
    required this.healthAssessment,
    required this.issues,
    required this.recommendations,
    this.snapshot,
  });

  factory DiagnosisReport.fromJson(Map<String, dynamic> json) {
    final issuesList = (json['issues'] as List? ?? [])
        .map((e) => DiagnosisIssue.fromJson(e as Map<String, dynamic>))
        .toList();
    final recsList = (json['recommendations'] as List? ?? [])
        .map((e) => CodeRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
    return DiagnosisReport(
      pid: (json['pid'] ?? 0).toInt(),
      processName: json['processName'] ?? 'Unknown',
      timestamp: json['timestamp'] ?? '',
      healthScore: (json['healthScore'] ?? 0).toInt(),
      healthAssessment: json['healthAssessment'] ?? '',
      issues: issuesList,
      recommendations: recsList,
      snapshot: json['snapshot'] != null
          ? JvmSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DiagnosisIssue {
  final String severity;
  final String category;
  final String title;
  final String description;
  final String? affectedMethod;
  final int impactScore;

  DiagnosisIssue({
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.affectedMethod,
    this.impactScore = 5,
  });

  factory DiagnosisIssue.fromJson(Map<String, dynamic> json) {
    return DiagnosisIssue(
      severity: json['severity'] ?? 'INFO',
      category: json['category'] ?? 'MEMORY',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      affectedMethod: json['affectedMethod'],
      impactScore: (json['impactScore'] ?? 5).toInt(),
    );
  }
}

class CodeRecommendation {
  final String title;
  final String description;
  final String? affectedMethod;
  final String? suggestedFix;
  final String? estimatedImpact;

  CodeRecommendation({
    required this.title,
    required this.description,
    this.affectedMethod,
    this.suggestedFix,
    this.estimatedImpact,
  });

  factory CodeRecommendation.fromJson(Map<String, dynamic> json) {
    return CodeRecommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      affectedMethod: json['affectedMethod'],
      suggestedFix: json['suggestedFix'],
      estimatedImpact: json['estimatedImpact'],
    );
  }
}

class JvmSnapshot {
  final int heapUsedBytes;
  final int heapMaxBytes;
  final double heapUsagePercent;
  final int threadCount;
  final double cpuPercent;
  final String status;
  final int gcCollectionCount;
  final int gcCollectionTimeMs;

  JvmSnapshot({
    this.heapUsedBytes = 0,
    this.heapMaxBytes = 0,
    this.heapUsagePercent = 0,
    this.threadCount = 0,
    this.cpuPercent = 0,
    this.status = 'HEALTHY',
    this.gcCollectionCount = 0,
    this.gcCollectionTimeMs = 0,
  });

  factory JvmSnapshot.fromJson(Map<String, dynamic> json) {
    return JvmSnapshot(
      heapUsedBytes: (json['heapUsedBytes'] ?? 0).toInt(),
      heapMaxBytes: (json['heapMaxBytes'] ?? 0).toInt(),
      heapUsagePercent: (json['heapUsagePercent'] ?? 0).toDouble(),
      threadCount: (json['threadCount'] ?? 0).toInt(),
      cpuPercent: (json['cpuPercent'] ?? 0).toDouble(),
      status: json['status'] ?? 'HEALTHY',
      gcCollectionCount: (json['gcCollectionCount'] ?? 0).toInt(),
      gcCollectionTimeMs: (json['gcCollectionTimeMs'] ?? 0).toInt(),
    );
  }
}

/// Notification from the notification center
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String severity;
  final String timestamp;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'INFO',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'INFO',
      timestamp: json['timestamp'] ?? '',
      read: json['read'] ?? false,
    );
  }
}

/// Histogram diff result
class HistogramDiffEntry {
  final String className;
  final int baselineInstances;
  final int baselineBytes;
  final int currentInstances;
  final int currentBytes;
  final int deltaInstances;
  final int deltaBytes;
  final String currentBytesFormatted;
  final String deltaBytesFormatted;

  HistogramDiffEntry({
    required this.className,
    this.baselineInstances = 0,
    this.baselineBytes = 0,
    this.currentInstances = 0,
    this.currentBytes = 0,
    this.deltaInstances = 0,
    this.deltaBytes = 0,
    this.currentBytesFormatted = '',
    this.deltaBytesFormatted = '',
  });

  factory HistogramDiffEntry.fromJson(Map<String, dynamic> json) {
    return HistogramDiffEntry(
      className: json['className'] ?? '',
      baselineInstances: (json['baselineInstances'] ?? 0).toInt(),
      baselineBytes: (json['baselineBytes'] ?? 0).toInt(),
      currentInstances: (json['currentInstances'] ?? 0).toInt(),
      currentBytes: (json['currentBytes'] ?? 0).toInt(),
      deltaInstances: (json['deltaInstances'] ?? 0).toInt(),
      deltaBytes: (json['deltaBytes'] ?? 0).toInt(),
      currentBytesFormatted: json['currentBytesFormatted'] ?? '',
      deltaBytesFormatted: json['deltaBytesFormatted'] ?? '',
    );
  }
}

class HistogramDiff {
  final int pid;
  final String baselineTimestamp;
  final String currentTimestamp;
  final List<HistogramDiffEntry> growing;
  final List<HistogramDiffEntry> shrinking;
  final List<HistogramDiffEntry> newClasses;

  HistogramDiff({
    required this.pid,
    required this.baselineTimestamp,
    required this.currentTimestamp,
    required this.growing,
    required this.shrinking,
    required this.newClasses,
  });

  factory HistogramDiff.fromJson(Map<String, dynamic> json) {
    return HistogramDiff(
      pid: (json['pid'] ?? 0).toInt(),
      baselineTimestamp: json['baselineTimestamp'] ?? '',
      currentTimestamp: json['currentTimestamp'] ?? '',
      growing: (json['growing'] as List? ?? [])
          .map((e) => HistogramDiffEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      shrinking: (json['shrinking'] as List? ?? [])
          .map((e) => HistogramDiffEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      newClasses: (json['newClasses'] as List? ?? [])
          .map((e) => HistogramDiffEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Code issue identified by profiling and mapped to source code
class CodeIssue {
  final String id;
  final String severity; // CRITICAL, HIGH, MEDIUM, LOW
  final String category; // MEMORY, CPU, THREADS, GC, ALGORITHM
  final String title;
  final String description;
  final String? method;
  final String? filePath;
  final int lineStart;
  final int lineEnd;
  final String? sourceSnippet;
  final double cpuPercent;
  final int allocationBytes;
  final int threadCount;
  final int gcPauseMs;
  final int impactScore;
  final String? rootCause;
  final String? suggestedFix;
  final String? beforeCode;
  final String? afterCode;
  final String? estimatedImpact;
  final bool analyzed;
  final String? prBranch;
  final String? prTitle;
  final String? prBody;
  final String? prDiff;
  final bool prCreated;

  CodeIssue({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.method,
    this.filePath,
    this.lineStart = 0,
    this.lineEnd = 0,
    this.sourceSnippet,
    this.cpuPercent = 0,
    this.allocationBytes = 0,
    this.threadCount = 0,
    this.gcPauseMs = 0,
    this.impactScore = 5,
    this.rootCause,
    this.suggestedFix,
    this.beforeCode,
    this.afterCode,
    this.estimatedImpact,
    this.analyzed = false,
    this.prBranch,
    this.prTitle,
    this.prBody,
    this.prDiff,
    this.prCreated = false,
  });

  factory CodeIssue.fromJson(Map<String, dynamic> json) {
    return CodeIssue(
      id: json['id'] ?? '',
      severity: json['severity'] ?? 'LOW',
      category: json['category'] ?? 'MEMORY',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      method: json['method'],
      filePath: json['filePath'],
      lineStart: (json['lineStart'] ?? 0).toInt(),
      lineEnd: (json['lineEnd'] ?? 0).toInt(),
      sourceSnippet: json['sourceSnippet'],
      cpuPercent: (json['cpuPercent'] ?? 0).toDouble(),
      allocationBytes: (json['allocationBytes'] ?? 0).toInt(),
      threadCount: (json['threadCount'] ?? 0).toInt(),
      gcPauseMs: (json['gcPauseMs'] ?? 0).toInt(),
      impactScore: (json['impactScore'] ?? 5).toInt(),
      rootCause: json['rootCause'],
      suggestedFix: json['suggestedFix'],
      beforeCode: json['beforeCode'],
      afterCode: json['afterCode'],
      estimatedImpact: json['estimatedImpact'],
      analyzed: json['analyzed'] ?? false,
      prBranch: json['prBranch'],
      prTitle: json['prTitle'],
      prBody: json['prBody'],
      prDiff: json['prDiff'],
      prCreated: json['prCreated'] ?? false,
    );
  }
}

/// Repository connection status
class RepoStatus {
  final String? repoUrl;
  final String? branch;
  final String? localPath;
  final bool connected;
  final int indexedFiles;
  final int indexedClasses;
  final String? lastIndexed;
  final String? error;

  RepoStatus({
    this.repoUrl,
    this.branch,
    this.localPath,
    this.connected = false,
    this.indexedFiles = 0,
    this.indexedClasses = 0,
    this.lastIndexed,
    this.error,
  });

  factory RepoStatus.fromJson(Map<String, dynamic> json) {
    return RepoStatus(
      repoUrl: json['repoUrl'],
      branch: json['branch'],
      localPath: json['localPath'],
      connected: json['connected'] ?? false,
      indexedFiles: (json['indexedFiles'] ?? 0).toInt(),
      indexedClasses: (json['indexedClasses'] ?? 0).toInt(),
      lastIndexed: json['lastIndexed'],
      error: json['error'],
    );
  }
}

/// PR plan generated for a code fix
class PrPlan {
  final String issueId;
  final String status;
  final String branch;
  final String prTitle;
  final String prBody;
  final String commitMessage;
  final String diff;
  final String? filePath;
  final String? severity;
  final String? category;
  final String? createdAt;
  final String? beforeCode;
  final String? afterCode;
  final String? estimatedImpact;

  PrPlan({
    required this.issueId,
    required this.status,
    required this.branch,
    required this.prTitle,
    required this.prBody,
    required this.commitMessage,
    required this.diff,
    this.filePath,
    this.severity,
    this.category,
    this.createdAt,
    this.beforeCode,
    this.afterCode,
    this.estimatedImpact,
  });

  factory PrPlan.fromJson(Map<String, dynamic> json) {
    return PrPlan(
      issueId: json['issueId'] ?? '',
      status: json['status'] ?? 'PLANNED',
      branch: json['branch'] ?? '',
      prTitle: json['prTitle'] ?? '',
      prBody: json['prBody'] ?? '',
      commitMessage: json['commitMessage'] ?? '',
      diff: json['diff'] ?? '',
      filePath: json['filePath'],
      severity: json['severity'],
      category: json['category'],
      createdAt: json['createdAt'],
      beforeCode: json['beforeCode'],
      afterCode: json['afterCode'],
      estimatedImpact: json['estimatedImpact'],
    );
  }
}

/// Alert rule configuration
class AlertRule {
  final String id;
  final String name;
  final String metric;
  final String operator;
  final double threshold;
  final String severity;
  final bool enabled;

  AlertRule({
    required this.id,
    required this.name,
    required this.metric,
    required this.operator,
    required this.threshold,
    required this.severity,
    this.enabled = true,
  });

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      metric: json['metric'] ?? '',
      operator: json['operator'] ?? '>',
      threshold: (json['threshold'] ?? 0).toDouble(),
      severity: json['severity'] ?? 'WARNING',
      enabled: json['enabled'] ?? true,
    );
  }
}
