import 'device_state.dart';
import 'sensor_log.dart';
import 'shelf.dart';

class ShelfCurrent {
  const ShelfCurrent({
    required this.shelf,
    required this.latestSensor,
    required this.deviceState,
    required this.vpd,
  });

  final Shelf shelf;
  final SensorLog? latestSensor;
  final DeviceState? deviceState;
  final double? vpd;

  factory ShelfCurrent.fromJson(Map<String, dynamic> json) {
    final shelfJson = (json['shelf'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final sensorJson =
        (json['latest_sensor'] as Map?)?.cast<String, dynamic>();
    final deviceJson =
        (json['device_state'] as Map?)?.cast<String, dynamic>();

    return ShelfCurrent(
      shelf: Shelf.fromJson(shelfJson),
      latestSensor: sensorJson == null ? null : SensorLog.fromJson(sensorJson),
      deviceState: deviceJson == null ? null : DeviceState.fromJson(deviceJson),
      vpd: (json['vpd'] as num?)?.toDouble(),
    );
  }
}

