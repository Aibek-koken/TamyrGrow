class DeviceState {
  const DeviceState({
    required this.shelfId,
    required this.lightBrightness,
    required this.fanSpeed,
    required this.targetTemperature,
    required this.heaterOn,
    required this.humidifierOn,
    required this.isAiMode,
  });

  final int shelfId;
  final int lightBrightness;
  final int fanSpeed;
  final double targetTemperature;
  final bool heaterOn;
  final bool humidifierOn;
  final bool isAiMode;

  factory DeviceState.fromJson(Map<String, dynamic> json) {
    return DeviceState(
      shelfId: json['shelf_id'] as int,
      lightBrightness: json['light_brightness'] as int,
      fanSpeed: json['fan_speed'] as int,
      targetTemperature: (json['target_temperature'] as num).toDouble(),
      heaterOn: json['heater_on'] as bool,
      humidifierOn: json['humidifier_on'] as bool,
      isAiMode: json['is_ai_mode'] as bool,
    );
  }
}

