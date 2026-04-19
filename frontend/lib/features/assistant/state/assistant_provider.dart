import 'package:flutter/foundation.dart';

import '../../../core/network/api_service.dart';
import '../models/chat_message.dart';

class AssistantProvider extends ChangeNotifier {
  AssistantProvider({required ApiService api}) : _api = api;

  final ApiService _api;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  int? _contextShelfId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// When the user selects another shelf, reset the thread and show a fresh greeting.
  void ensureShelfContext(int shelfId, String shelfLabel) {
    if (_contextShelfId == shelfId) return;
    _contextShelfId = shelfId;
    _error = null;
    _messages.clear();
    _messages.add(
      ChatMessage(
        text: "I'm ready to analyze Shelf [$shelfId] · $shelfLabel. How can I help?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> sendMessage(String text, int shelfId) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _error = null;
    _messages.add(
      ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _isLoading = true;
    notifyListeners();

    try {
      final reply = await _api.chatWithAi(shelfId, trimmed);
      if (reply.trim().isEmpty) {
        _error = 'Empty response from assistant.';
        _messages.add(
          ChatMessage(
            text: 'Sorry — I could not get a reply. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: reply.trim(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _error = e.toString();
      _messages.add(
        ChatMessage(
          text: 'Could not reach the assistant. Check your connection and API.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
