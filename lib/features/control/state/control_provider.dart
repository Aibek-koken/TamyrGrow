import 'package:flutter/foundation.dart';

import '../../../core/network/api_service.dart';
import '../../dashboard/models/device_state.dart';
import '../../dashboard/models/shelf_current.dart';

class ControlProvider extends ChangeNotifier {
  ControlProvider({
    required ApiService api,
    required int shelfId,
  })  : _api = api,
        _shelfId = shelfId;

  final ApiService _api;
  final int _shelfId;

  bool _loading = false;
  String? _error;
  DeviceState? _deviceState;
  ShelfCurrent? _current;

  bool get isLoading => _loading;
  String? get error => _error;
  int get shelfId => _shelfId;
  ShelfCurrent? get current => _current;
  DeviceState? get deviceState => _deviceState;
  bool get isAiMode => _deviceState?.isAiMode ?? true;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final current = await _api.getShelfCurrent(_shelfId);
      _current = current;
      _deviceState = current.deviceState;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleAiMode(bool enabled) async {
    _error = null;
    notifyListeners();

    try {
      final updated = await _api.updateDeviceState(_shelfId, isAiMode: enabled);
      _deviceState = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setLightBrightness(int value) async {
    _error = null;
    notifyListeners();
    _deviceState = _deviceState == null
        ? null
        : DeviceState(
            shelfId: _deviceState!.shelfId,
            lightBrightness: value,
            fanSpeed: _deviceState!.fanSpeed,
            targetTemperature: _deviceState!.targetTemperature,
            heaterOn: _deviceState!.heaterOn,
            humidifierOn: _deviceState!.humidifierOn,
            isAiMode: _deviceState!.isAiMode,
          );
    notifyListeners();

    final updated = await _api.updateDeviceState(_shelfId, lightBrightness: value);
    _deviceState = updated;
    notifyListeners();
  }

  Future<void> setFanSpeed(int speed) async {
    final updated = await _api.updateDeviceState(_shelfId, fanSpeed: speed);
    _deviceState = updated;
    notifyListeners();
  }

  Future<void> setTargetTemperature(double celsius) async {
    final updated = await _api.updateDeviceState(_shelfId, targetTemperature: celsius);
    _deviceState = updated;
    notifyListeners();
  }

  Future<void> emergencyStop() async {
    _error = null;
    notifyListeners();

    if (isAiMode) {
      await toggleAiMode(false);
    }

    final updated = await _api.updateDeviceState(
      _shelfId,
      lightBrightness: 0,
      fanSpeed: 0,
      heaterOn: false,
      humidifierOn: false,
    );
    _deviceState = updated;
    notifyListeners();
  }
}

