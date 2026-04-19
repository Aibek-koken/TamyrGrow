import 'package:dio/dio.dart';
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
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final detail = _fastApiDetail(e.response?.data);
      if (code == 503) {
        _error = detail ??
            'GROQ_API_KEY не задан на сервере. Добавьте ключ в backend/.env и перезапустите API.';
        _messages.add(
          ChatMessage(
            text:
                'Ассистент недоступен: на бэкенде не настроен ключ Groq (GROQ_API_KEY). '
                'Укажите ключ в файле backend/.env в корне проекта и перезапустите сервер '
                '(при Docker: docker compose up -d --build после сохранения .env).',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else if (code == 401) {
        _error = detail;
        _messages.add(
          ChatMessage(
            text: detail ??
                'Неверный ключ Groq. Создайте ключ на https://console.groq.com/keys '
                '(строка начинается с gsk_), вставьте в backend/.env как GROQ_API_KEY=… '
                'и перезапустите uvicorn. Ключи xAI/Grok здесь не подходят.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        _error = detail ?? e.message ?? e.toString();
        _messages.add(
          ChatMessage(
            text: _friendlyHttpError(code, detail),
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

String? _fastApiDetail(Object? data) {
  if (data is Map<String, dynamic>) {
    final d = data['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty && d.first is Map) {
      final msg = (d.first as Map)['msg'];
      if (msg is String) return msg;
    }
  }
  return null;
}

String _friendlyHttpError(int? code, String? detail) {
  if (detail != null && detail.isNotEmpty) return detail;
  if (code == 502) {
    return 'Сервис Groq вернул ошибку. Проверьте ключ на console.groq.com и лимиты API.';
  }
  if (code == 429) {
    return 'Слишком много запросов к Groq. Подождите немного и попробуйте снова.';
  }
  return 'Не удалось связаться с ассистентом. Проверьте сеть и адрес API.';
}
