import 'package:dio/dio.dart';

import '../../features/dashboard/models/dashboard_summary.dart';
import '../../features/dashboard/models/device_state.dart';
import '../../features/dashboard/models/sensor_log.dart';
import '../../features/dashboard/models/shelf_current.dart';

class ApiService {
  ApiService({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://10.0.2.2:8000',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  Future<DashboardSummary> getDashboardSummary() async {
    final response = await _dio.get<Map<String, dynamic>>('/dashboard/summary');
    return DashboardSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ShelfCurrent> getShelfCurrent(int shelfId) async {
    final response = await _dio.get<Map<String, dynamic>>('/shelves/$shelfId/current');
    return ShelfCurrent.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<SensorLog>> getShelfSensorLogs(
    int shelfId, {
    int limit = 200,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/shelves/$shelfId/logs',
      queryParameters: <String, dynamic>{'limit': limit},
    );

    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(SensorLog.fromJson)
        .toList(growable: false);
  }

  Future<DeviceState> updateDeviceState(
    int shelfId, {
    int? lightBrightness,
    int? fanSpeed,
    double? targetTemperature,
    bool? heaterOn,
    bool? humidifierOn,
    bool? isAiMode,
  }) async {
    final payload = <String, dynamic>{};
    if (lightBrightness != null) payload['light_brightness'] = lightBrightness;
    if (fanSpeed != null) payload['fan_speed'] = fanSpeed;
    if (targetTemperature != null) payload['target_temperature'] = targetTemperature;
    if (heaterOn != null) payload['heater_on'] = heaterOn;
    if (humidifierOn != null) payload['humidifier_on'] = humidifierOn;
    if (isAiMode != null) payload['is_ai_mode'] = isAiMode;

    final response = await _dio.patch<Map<String, dynamic>>(
      '/shelves/$shelfId/control',
      data: payload,
    );
    return DeviceState.fromJson(response.data ?? <String, dynamic>{});
  }

  /// POST /assistant/chat — AI agronomist reply for a shelf.
  Future<String> chatWithAi(int shelfId, String message) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/assistant/chat',
      data: <String, dynamic>{
        'shelf_id': shelfId,
        'message': message,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final reply = data['reply'];
    if (reply is String) return reply;
    return '';
  }
}

