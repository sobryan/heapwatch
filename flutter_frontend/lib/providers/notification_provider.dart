import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  Timer? _timer;

  NotificationProvider(this._api) {
    loadNotifications();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => loadNotifications());
  }

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  Future<void> loadNotifications() async {
    try {
      final data = await _api.getNotifications();
      final list = (data['notifications'] as List? ?? [])
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      _notifications = list;
      _unreadCount = (data['unreadCount'] ?? 0).toInt();
      notifyListeners();
    } catch (e) {
      // Silent fail on polling
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
      await loadNotifications();
    } catch (e) {
      // ignore
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      _unreadCount = 0;
      notifyListeners();
      await loadNotifications();
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
