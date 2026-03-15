import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class AlertProvider extends ChangeNotifier {
  final ApiService _api;
  List<Alert> _alerts = [];
  List<AlertRule> _rules = [];
  int _activeCount = 0;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  AlertProvider(this._api) {
    loadAlerts();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => loadAlerts());
  }

  List<Alert> get alerts => _alerts;
  List<AlertRule> get rules => _rules;
  int get activeCount => _activeCount;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAlerts() async {
    try {
      final data = await _api.getAlerts();
      final alertList = (data['alerts'] as List? ?? [])
          .map((a) => Alert.fromJson(a as Map<String, dynamic>))
          .toList();
      _alerts = alertList;
      _activeCount = (data['activeCount'] ?? 0).toInt();
      _error = null;
      notifyListeners();
    } catch (e) {
      // Silent fail on polling
    }
  }

  Future<void> loadRules() async {
    try {
      _rules = await _api.getAlertRules();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addRule({
    required String name,
    required String metric,
    required String operator,
    required double threshold,
    required String severity,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _api.addAlertRule({
        'name': name,
        'metric': metric,
        'operator': operator,
        'threshold': threshold,
        'severity': severity,
      });
      await loadRules();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> clearAlerts() async {
    try {
      await _api.clearAlerts();
      _alerts = [];
      _activeCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
