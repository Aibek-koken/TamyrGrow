import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/dashboard/models/sensor_log.dart';
import 'api_service.dart';

class WsSensorStream {
  WsSensorStream({required ApiService api}) : _api = api;

  final ApiService _api;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<SensorLog>.broadcast();

  Stream<SensorLog> get stream => _controller.stream;

  Future<void> connectShelf(int shelfId) async {
    await disconnect();

    final uri = _api.buildWsUri('/ws/shelves/$shelfId/sensors');
    _channel = WebSocketChannel.connect(uri);

    _subscription = _channel!.stream.listen(
      (event) {
        try {
          final raw = event is String ? event : utf8.decode(event as List<int>);
          final jsonMap = (jsonDecode(raw) as Map).cast<String, dynamic>();
          final type = jsonMap['type'];
          if (type != 'sensor_log') return;
          final payload = (jsonMap['payload'] as Map).cast<String, dynamic>();
          _controller.add(SensorLog.fromJson(payload));
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (Object err, StackTrace st) {
        _controller.addError(err, st);
      },
      onDone: () {
        // Let provider decide reconnect strategy.
      },
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();

    final ch = _channel;
    _channel = null;
    await ch?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}

