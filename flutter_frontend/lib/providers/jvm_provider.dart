import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class JvmProvider extends ChangeNotifier {
  final ApiService _api;
  List<Jvm> _jvms = [];
  Jvm? _selectedJvm;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  JvmProvider(this._api) {
    loadJvms();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => loadJvms());
  }

  List<Jvm> get jvms => _jvms;
  Jvm? get selectedJvm => _selectedJvm;
  bool get loading => _loading;
  String? get error => _error;

  int get healthyCount => _jvms.where((j) => j.status == 'HEALTHY').length;
  int get warningCount => _jvms.where((j) => j.status == 'WARNING').length;
  int get criticalCount => _jvms.where((j) => j.status == 'CRITICAL').length;
  int get needsAttentionCount => warningCount + criticalCount;
  int get totalHeapUsed => _jvms.fold(0, (s, j) => s + j.heapUsedBytes);
  int get totalThreads => _jvms.fold(0, (s, j) => s + j.threadCount);

  String get overallStatus {
    if (criticalCount > 0) return 'red';
    if (warningCount > 0) return 'yellow';
    return 'green';
  }

  Future<void> loadJvms() async {
    try {
      final data = await _api.listJvms();
      _jvms = data;
      _error = null;
      // Update selected JVM if it exists
      if (_selectedJvm != null) {
        final updated = _jvms.where((j) => j.pid == _selectedJvm!.pid);
        if (updated.isNotEmpty) {
          _selectedJvm = updated.first;
        }
      }
      notifyListeners();
    } catch (e) {
      if (_jvms.isEmpty) {
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> refreshJvms() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.refreshJvms();
      _jvms = data;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void selectJvm(Jvm jvm) {
    _selectedJvm = jvm;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
