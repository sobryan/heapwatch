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

  // Thread Analysis
  final Map<int, Map<String, dynamic>> _threadAnalyses = {};
  int? _threadAnalysisPid;
  String? _threadAnalysisError;

  // GC Analysis
  final Map<int, Map<String, dynamic>> _gcAnalyses = {};
  int? _gcAnalysisPid;
  String? _gcAnalysisError;

  // Histogram Diff
  final Map<int, HistogramDiff> _histogramDiffs = {};
  final Set<int> _hasBaseline = {};
  int? _baselinePid;
  int? _diffPid;
  String? _histogramError;

  // Snapshots
  final Map<int, List<Map<String, dynamic>>> _snapshots = {};
  Map<String, dynamic>? _comparisonResult;
  bool _snapshotLoading = false;
  String? _snapshotError;

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
  int? get threadAnalysisPid => _threadAnalysisPid;
  String? get threadAnalysisError => _threadAnalysisError;
  int? get gcAnalysisPid => _gcAnalysisPid;
  String? get gcAnalysisError => _gcAnalysisError;
  int? get baselinePid => _baselinePid;
  int? get diffPid => _diffPid;
  String? get histogramError => _histogramError;
  bool get snapshotLoading => _snapshotLoading;
  String? get snapshotError => _snapshotError;
  Map<String, dynamic>? get comparisonResult => _comparisonResult;

  JfrAnalysis? getJfrAnalysis(String id) => _jfrAnalyses[id];
  HeapDumpAnalysis? getHeapDumpAnalysis(String id) => _heapDumpAnalyses[id];
  DiagnosisReport? getDiagnosisReport(int pid) => _diagnosisReports[pid];
  Map<String, dynamic>? getThreadAnalysis(int pid) => _threadAnalyses[pid];
  Map<String, dynamic>? getGcAnalysis(int pid) => _gcAnalyses[pid];
  List<Map<String, dynamic>> getSnapshots(int pid) => _snapshots[pid] ?? [];
  HistogramDiff? getHistogramDiff(int pid) => _histogramDiffs[pid];
  bool hasBaseline(int pid) => _hasBaseline.contains(pid);

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

  Future<void> fetchThreadAnalysis(int pid) async {
    _threadAnalysisPid = pid;
    _threadAnalysisError = null;
    notifyListeners();
    try {
      final analysis = await _api.getThreadAnalysis(pid);
      _threadAnalyses[pid] = analysis;
    } catch (e) {
      _threadAnalysisError = e.toString();
    }
    _threadAnalysisPid = null;
    notifyListeners();
  }

  Future<void> fetchGcAnalysis(int pid) async {
    _gcAnalysisPid = pid;
    _gcAnalysisError = null;
    notifyListeners();
    try {
      final analysis = await _api.getGcAnalysis(pid);
      _gcAnalyses[pid] = analysis;
    } catch (e) {
      _gcAnalysisError = e.toString();
    }
    _gcAnalysisPid = null;
    notifyListeners();
  }

  Future<void> captureSnapshot(int pid) async {
    _snapshotLoading = true;
    _snapshotError = null;
    notifyListeners();
    try {
      await _api.captureSnapshot(pid);
      await loadSnapshots(pid);
    } catch (e) {
      _snapshotError = e.toString();
    }
    _snapshotLoading = false;
    notifyListeners();
  }

  Future<void> loadSnapshots(int pid) async {
    try {
      final snaps = await _api.listSnapshots(pid);
      _snapshots[pid] = snaps;
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> compareSnapshots(int snap1, int snap2) async {
    _snapshotLoading = true;
    _snapshotError = null;
    notifyListeners();
    try {
      _comparisonResult = await _api.compareSnapshots(snap1, snap2);
    } catch (e) {
      _snapshotError = e.toString();
    }
    _snapshotLoading = false;
    notifyListeners();
  }

  void clearComparison() {
    _comparisonResult = null;
    notifyListeners();
  }

  Future<void> captureHeapBaseline(int pid) async {
    _baselinePid = pid;
    _histogramError = null;
    notifyListeners();
    try {
      await _api.captureHeapBaseline(pid);
      _hasBaseline.add(pid);
    } catch (e) {
      _histogramError = e.toString();
    }
    _baselinePid = null;
    notifyListeners();
  }

  Future<void> fetchHeapDiff(int pid) async {
    _diffPid = pid;
    _histogramError = null;
    notifyListeners();
    try {
      final diff = await _api.getHeapDiff(pid);
      _histogramDiffs[pid] = diff;
    } catch (e) {
      _histogramError = e.toString();
    }
    _diffPid = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
