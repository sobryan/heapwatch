import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class ProfilerProvider extends ChangeNotifier {
  final ApiService _api;
  List<JfrRecording> _recordings = [];
  List<HeapDump> _heapDumps = [];
  String _profileType = 'CPU';
  int _duration = 30;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  // Analysis results cache
  final Map<String, JfrAnalysis> _jfrAnalyses = {};
  final Map<String, HeapDumpAnalysis> _heapDumpAnalyses = {};
  String? _analysisLoading; // ID currently loading
  String? _analysisError;

  // Diagnosis
  final Map<int, DiagnosisReport> _diagnosisReports = {};
  int? _diagnosingPid;
  String? _diagnosisError;

  ProfilerProvider(this._api);

  List<JfrRecording> get recordings => _recordings;
  List<HeapDump> get heapDumps => _heapDumps;
  String get profileType => _profileType;
  int get duration => _duration;
  bool get loading => _loading;
  String? get error => _error;
  String? get analysisLoading => _analysisLoading;
  String? get analysisError => _analysisError;
  int? get diagnosingPid => _diagnosingPid;
  String? get diagnosisError => _diagnosisError;

  JfrAnalysis? getJfrAnalysis(String id) => _jfrAnalyses[id];
  HeapDumpAnalysis? getHeapDumpAnalysis(String id) => _heapDumpAnalyses[id];
  DiagnosisReport? getDiagnosisReport(int pid) => _diagnosisReports[pid];

  void startPolling() {
    loadRecordings();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => loadRecordings());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void setProfileType(String type) {
    _profileType = type;
    notifyListeners();
  }

  void setDuration(int dur) {
    _duration = dur;
    notifyListeners();
  }

  Future<void> loadRecordings() async {
    try {
      final recs = await _api.listRecordings();
      final dumps = await _api.listHeapDumps();
      _recordings = recs;
      _heapDumps = dumps;
      _error = null;
      notifyListeners();
    } catch (e) {
      // Silent fail on polling
    }
  }

  Future<void> startJfr(Jvm jvm) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.startJfr(
        pid: jvm.pid,
        processName: jvm.displayName,
        durationSeconds: _duration,
        profileType: _profileType,
      );
      await loadRecordings();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> triggerHeapDump(Jvm jvm) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.triggerHeapDump(
        pid: jvm.pid,
        processName: jvm.displayName,
      );
      await loadRecordings();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> cancelRecording(String id) async {
    try {
      await _api.cancelRecording(id);
      await loadRecordings();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  String downloadUrl(String id) => _api.jfrDownloadUrl(id);

  Future<void> fetchJfrAnalysis(String id) async {
    _analysisLoading = id;
    _analysisError = null;
    notifyListeners();
    try {
      final analysis = await _api.getJfrAnalysis(id);
      _jfrAnalyses[id] = analysis;
    } catch (e) {
      _analysisError = e.toString();
    }
    _analysisLoading = null;
    notifyListeners();
  }

  Future<void> fetchHeapDumpAnalysis(String id) async {
    _analysisLoading = id;
    _analysisError = null;
    notifyListeners();
    try {
      final analysis = await _api.getHeapDumpAnalysis(id);
      _heapDumpAnalyses[id] = analysis;
    } catch (e) {
      _analysisError = e.toString();
    }
    _analysisLoading = null;
    notifyListeners();
  }

  Future<void> runDiagnosis(int pid) async {
    _diagnosingPid = pid;
    _diagnosisError = null;
    notifyListeners();
    try {
      final report = await _api.diagnose(pid);
      _diagnosisReports[pid] = report;
    } catch (e) {
      _diagnosisError = e.toString();
    }
    _diagnosingPid = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
