import 'package:flutter/foundation.dart';
import '../models/jvm.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _error;

  ChatProvider(this._api);

  List<ChatMessage> get messages => _messages;
  bool get sending => _sending;
  String? get error => _error;

  Future<void> loadHistory() async {
    try {
      _messages = await _api.getChatHistory();
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now().toIso8601String(),
    );
    _messages = [..._messages, userMsg];
    _sending = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.sendChat(text);
      _messages = [..._messages, response];
    } catch (e) {
      _messages = [
        ..._messages,
        ChatMessage(
          role: 'assistant',
          content: 'Error connecting to AI service.',
          timestamp: DateTime.now().toIso8601String(),
        ),
      ];
      _error = e.toString();
    }
    _sending = false;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      await _api.clearChatHistory();
      _messages = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
