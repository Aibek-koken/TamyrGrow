import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_service.dart';
import '../../../core/network/ws_sensor_stream.dart';
import '../../dashboard/models/sensor_log.dart';
import '../../dashboard/models/shelf_current.dart';
import '../../dashboard/state/dashboard_provider.dart';

class LiveAnalyticsProvider extends ChangeNotifier {
  LiveAnalyticsProvider({
    required ApiService api,
    required DashboardProvider dashboard,
    int historyLimit = 240,
  })  : _api = api,
        _dashboard = dashboard,
        _historyLimit = historyLimit,
        _ws = WsSensorStream(api: api);

  final ApiService _api;
  final DashboardProvider _dashboard;
  final int _historyLimit;
  final WsSensorStream _ws;

  int? _shelfId;
  bool _loading = false;
  String? _error;
  ShelfCurrent? _current;
  final List<SensorLog> _logs = [];

  StreamSubscription<SensorLog>? _wsSub;
  Timer? _reconnectTimer;

  bool get isLoading => _loading;
  String? get error => _error;
  int? get shelfId => _shelfId;
  ShelfCurrent? get current => _current;
  List<SensorLog> get logs => List.unmodifiable(_logs);

  Future<void> selectShelf(int shelfId) async {
    if (_shelfId == shelfId) return;
    _shelfId = shelfId;
    _error = null;
    _current = null;
    _logs.clear();
    notifyListeners();
    await start();
  }

  Future<void> start() async {
    final shelfId = _shelfId ?? _dashboard.selectedShelfId;
    if (shelfId == null) return;
    _shelfId = shelfId;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getShelfCurrent(shelfId),
        _api.getShelfSensorLogs(shelfId, limit: _historyLimit),
      ]);
      _current = results[0] as ShelfCurrent;
      _logs
        ..clear()
        ..addAll(results[1] as List<SensorLog>);
      _trimLogs();

      await _connectWs();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _connectWs() async {
    final shelfId = _shelfId;
    if (shelfId == null) return;

    await _wsSub?.cancel();
    _wsSub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _ws.connectShelf(shelfId);
      _wsSub = _ws.stream.listen(
        (log) {
          if (log.shelfId != shelfId) return;
          _logs.add(log);
          _trimLogs();
          _dashboard.applyLiveSensorLog(log);
          notifyListeners();
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _reconnectTimer = null;
      await _connectWs();
    });
  }

  void _trimLogs() {
    final overflow = _logs.length - _historyLimit;
    if (overflow <= 0) return;
    _logs.removeRange(0, overflow);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws.dispose();
    super.dispose();
  }
}

