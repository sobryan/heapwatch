import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class SreProvider extends ChangeNotifier {
  final ApiService _api;

  List<SreIncident> _incidents = [];
  SreIncident? _selectedIncident;
  Map<String, dynamic> _status = {};
  List<AlertIntegrationChannel> _integrations = [];
  bool _loading = false;
  String? _error;
  Timer? _timer;

  SreProvider(this._api) {
    loadAll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => loadAll());
  }

  List<SreIncident> get incidents => _incidents;
  SreIncident? get selectedIncident => _selectedIncident;
  Map<String, dynamic> get status => _status;
  List<AlertIntegrationChannel> get integrations => _integrations;
  bool get loading => _loading;
  String? get error => _error;

  bool get isRunning => _status['running'] == true;
  int get totalScans => (_status['totalScans'] ?? 0).toInt();
  int get anomaliesDetected => (_status['anomaliesDetected'] ?? 0).toInt();
  int get openIncidents => (_status['openIncidents'] ?? 0).toInt();
  String? get lastScanTime => _status['lastScanTime']?.toString();

  Future<void> loadAll() async {
    try {
      final results = await Future.wait([
        _api.getSreStatus(),
        _api.getSreIncidents(),
      ]);
      _status = results[0] as Map<String, dynamic>;
      _incidents = results[1] as List<SreIncident>;
      _error = null;
      notifyListeners();
    } catch (e) {
      // Silent fail on polling
    }
  }

  Future<void> loadIncidents() async {
    try {
      _incidents = await _api.getSreIncidents();
      _error = null;
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> loadStatus() async {
    try {
      _status = await _api.getSreStatus();
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> selectIncident(String id) async {
    _loading = true;
    notifyListeners();
    try {
      _selectedIncident = await _api.getSreIncident(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void clearSelectedIncident() {
    _selectedIncident = null;
    notifyListeners();
  }

  Future<void> resolveIncident(String id) async {
    _loading = true;
    notifyListeners();
    try {
      await _api.resolveSreIncident(id);
      await loadAll();
      if (_selectedIncident?.id == id) {
        _selectedIncident = await _api.getSreIncident(id);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> toggleAgent() async {
    try {
      final result = await _api.toggleSreAgent();
      _status['running'] = result['running'];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Integration management
  Future<void> loadIntegrations() async {
    try {
      _integrations = await _api.getAlertIntegrations();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addIntegration(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    try {
      await _api.addAlertIntegration(data);
      await loadIntegrations();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateIntegration(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateAlertIntegration(id, data);
      await loadIntegrations();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteIntegration(String id) async {
    try {
      await _api.deleteAlertIntegration(id);
      await loadIntegrations();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> testIntegration(String id) async {
    try {
      final result = await _api.testAlertIntegration(id);
      await loadIntegrations();
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
