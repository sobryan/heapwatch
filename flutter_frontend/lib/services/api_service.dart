import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jvm.dart';

class ApiService {
  static const String baseUrl = '';

  Future<Map<String, String>> _headers() async {
    return {'Content-Type': 'application/json'};
  }

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    http.Response res;

    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers);
        break;
      case 'POST':
        res = await http.post(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        res = await http.put(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unknown method: $method');
    }

    if (res.statusCode == 204) return null;

    if (res.statusCode >= 400) {
      String message;
      try {
        final data = jsonDecode(res.body);
        message = data['detail'] ?? data['message'] ?? 'Request failed: ${res.statusCode}';
      } catch (_) {
        message = 'Request failed: ${res.statusCode}';
      }
      throw Exception(message);
    }

    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  // JVMs
  Future<List<Jvm>> listJvms() async {
    final data = await _request('GET', '/api/jvms');
    return (data as List).map((j) => Jvm.fromJson(j)).toList();
  }

  Future<Jvm> getJvm(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid');
    return Jvm.fromJson(data);
  }

  Future<List<Jvm>> refreshJvms() async {
    final data = await _request('POST', '/api/jvms/refresh');
    return (data as List).map((j) => Jvm.fromJson(j)).toList();
  }

  // JFR Recordings
  Future<JfrRecording> startJfr({
    required int pid,
    required String processName,
    required int durationSeconds,
    required String profileType,
  }) async {
    final data = await _request('POST', '/api/profiler/jfr', body: {
      'pid': pid,
      'processName': processName,
      'durationSeconds': durationSeconds,
      'profileType': profileType,
    });
    return JfrRecording.fromJson(data);
  }

  Future<List<JfrRecording>> listRecordings() async {
    final data = await _request('GET', '/api/profiler/jfr');
    return (data as List).map((r) => JfrRecording.fromJson(r)).toList();
  }

  Future<void> cancelRecording(String id) async {
    await _request('DELETE', '/api/profiler/jfr/$id');
  }

  String jfrDownloadUrl(String id) => '$baseUrl/api/profiler/jfr/$id/download';

  // Heap Dumps
  Future<HeapDump> triggerHeapDump({
    required int pid,
    required String processName,
  }) async {
    final data = await _request('POST', '/api/profiler/heapdump', body: {
      'pid': pid,
      'processName': processName,
    });
    return HeapDump.fromJson(data);
  }

  Future<List<HeapDump>> listHeapDumps() async {
    final data = await _request('GET', '/api/profiler/heapdump');
    return (data as List).map((d) => HeapDump.fromJson(d)).toList();
  }

  // JFR Analysis
  Future<JfrAnalysis> getJfrAnalysis(String id) async {
    final data = await _request('GET', '/api/profiler/jfr/$id/analysis');
    return JfrAnalysis.fromJson(data);
  }

  // Heap Dump Analysis
  Future<HeapDumpAnalysis> getHeapDumpAnalysis(String id) async {
    final data = await _request('GET', '/api/profiler/heapdump/$id/analysis');
    return HeapDumpAnalysis.fromJson(data);
  }

  // Metrics History
  Future<MetricsHistory> getMetricsHistory(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid/history');
    return MetricsHistory.fromJson(data);
  }

  // Alerts
  Future<Map<String, dynamic>> getAlerts() async {
    final data = await _request('GET', '/api/alerts');
    return Map<String, dynamic>.from(data);
  }

  Future<int> getActiveAlertCount() async {
    final data = await _request('GET', '/api/alerts');
    return (data['activeCount'] ?? 0).toInt();
  }

  Future<List<AlertRule>> getAlertRules() async {
    final data = await _request('GET', '/api/alerts/rules');
    return (data as List).map((r) => AlertRule.fromJson(r)).toList();
  }

  Future<AlertRule> addAlertRule(Map<String, dynamic> rule) async {
    final data = await _request('POST', '/api/alerts/rules', body: rule);
    return AlertRule.fromJson(data);
  }

  Future<void> clearAlerts() async {
    await _request('DELETE', '/api/alerts');
  }

  // Diagnose
  Future<DiagnosisReport> diagnose(int pid) async {
    final data = await _request('POST', '/api/diagnose/$pid');
    return DiagnosisReport.fromJson(data);
  }

  // Thread Analysis
  Future<Map<String, dynamic>> getThreadAnalysis(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid/threads');
    return Map<String, dynamic>.from(data);
  }

  // GC Analysis
  Future<Map<String, dynamic>> getGcAnalysis(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid/gc');
    return Map<String, dynamic>.from(data);
  }

  // Snapshots
  Future<Map<String, dynamic>> captureSnapshot(int pid) async {
    final data = await _request('POST', '/api/jvms/$pid/snapshot');
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> listSnapshots(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid/snapshots');
    return (data as List).map((s) => Map<String, dynamic>.from(s)).toList();
  }

  Future<Map<String, dynamic>> compareSnapshots(int snapshot1, int snapshot2) async {
    final data = await _request('GET', '/api/compare?snapshot1=$snapshot1&snapshot2=$snapshot2');
    return Map<String, dynamic>.from(data);
  }

  // Settings
  Future<Map<String, dynamic>> getSettings() async {
    final data = await _request('GET', '/api/settings');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final data = await _request('PUT', '/api/settings', body: settings);
    return Map<String, dynamic>.from(data);
  }

  // Chat
  Future<ChatMessage> sendChat(String message) async {
    final data = await _request('POST', '/api/chat', body: {'message': message});
    return ChatMessage.fromJson(data);
  }

  Future<List<ChatMessage>> getChatHistory() async {
    final data = await _request('GET', '/api/chat/history');
    return (data as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  Future<void> clearChatHistory() async {
    await _request('DELETE', '/api/chat/history');
  }

  // Histogram Diff
  Future<Map<String, dynamic>> captureHeapBaseline(int pid) async {
    final data = await _request('POST', '/api/jvms/$pid/heap-baseline');
    return Map<String, dynamic>.from(data);
  }

  Future<HistogramDiff> getHeapDiff(int pid) async {
    final data = await _request('GET', '/api/jvms/$pid/heap-diff');
    return HistogramDiff.fromJson(data);
  }

  // Notifications
  Future<Map<String, dynamic>> getNotifications() async {
    final data = await _request('GET', '/api/notifications');
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteNotification(String id) async {
    await _request('DELETE', '/api/notifications/$id');
  }

  Future<void> markAllNotificationsRead() async {
    await _request('POST', '/api/notifications/read-all');
  }

  Future<int> getUnreadNotificationCount() async {
    final data = await _request('GET', '/api/notifications/unread-count');
    return (data['unreadCount'] ?? 0).toInt();
  }
}
