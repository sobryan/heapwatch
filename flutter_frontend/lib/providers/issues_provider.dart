import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class IssuesProvider extends ChangeNotifier {
  final ApiService _api;

  List<CodeIssue> _issues = [];
  RepoStatus? _repoStatus;
  List<PrPlan> _prPlans = [];

  bool _loading = false;
  bool _connecting = false;
  String? _analyzingId;
  String? _creatingPrId;
  String? _error;
  CodeIssue? _selectedIssue;

  IssuesProvider(this._api);

  List<CodeIssue> get issues => _issues;
  RepoStatus? get repoStatus => _repoStatus;
  List<PrPlan> get prPlans => _prPlans;
  bool get loading => _loading;
  bool get connecting => _connecting;
  String? get analyzingId => _analyzingId;
  String? get creatingPrId => _creatingPrId;
  String? get error => _error;
  CodeIssue? get selectedIssue => _selectedIssue;

  int get criticalCount => _issues.where((i) => i.severity == 'CRITICAL').length;
  int get highCount => _issues.where((i) => i.severity == 'HIGH').length;
  int get mediumCount => _issues.where((i) => i.severity == 'MEDIUM').length;
  int get lowCount => _issues.where((i) => i.severity == 'LOW').length;

  void selectIssue(CodeIssue? issue) {
    _selectedIssue = issue;
    notifyListeners();
  }

  Future<void> loadRepoStatus() async {
    try {
      _repoStatus = await _api.getRepoStatus();
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> connectRepo(String repoUrl, {String branch = 'main'}) async {
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      _repoStatus = await _api.connectRepo(repoUrl, branch: branch);
      if (_repoStatus!.connected) {
        await loadIssues();
      } else {
        _error = _repoStatus!.error;
      }
    } catch (e) {
      _error = e.toString();
    }
    _connecting = false;
    notifyListeners();
  }

  Future<void> loadIssues() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // First try map-issues (which triggers fresh mapping)
      if (_repoStatus?.connected == true) {
        _issues = await _api.mapIssues();
      }
      // Also load any previously stored issues
      if (_issues.isEmpty) {
        _issues = await _api.getIssues();
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> analyzeIssue(String id) async {
    _analyzingId = id;
    _error = null;
    notifyListeners();
    try {
      final analyzed = await _api.analyzeIssue(id);
      // Update the issue in the list
      final idx = _issues.indexWhere((i) => i.id == id);
      if (idx >= 0) {
        _issues[idx] = analyzed;
      }
      if (_selectedIssue?.id == id) {
        _selectedIssue = analyzed;
      }
    } catch (e) {
      _error = e.toString();
    }
    _analyzingId = null;
    notifyListeners();
  }

  Future<void> createPr(String issueId) async {
    _creatingPrId = issueId;
    _error = null;
    notifyListeners();
    try {
      final plan = await _api.createPr(issueId);
      _prPlans.add(plan);
      // Reload issue to get updated PR info
      final updated = await _api.getIssue(issueId);
      final idx = _issues.indexWhere((i) => i.id == issueId);
      if (idx >= 0) {
        _issues[idx] = updated;
      }
      if (_selectedIssue?.id == issueId) {
        _selectedIssue = updated;
      }
    } catch (e) {
      _error = e.toString();
    }
    _creatingPrId = null;
    notifyListeners();
  }

  Future<void> loadPrPlans() async {
    try {
      _prPlans = await _api.getPrPlans();
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }
}
