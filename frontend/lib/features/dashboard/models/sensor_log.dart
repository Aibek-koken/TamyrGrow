class SensorLog {
  const SensorLog({
    required this.id,
    required this.shelfId,
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.tvoc,
    required this.timestamp,
  });

  final int id;
  final int shelfId;
  final double temperature;
  final double humidity;
  final int co2;
  final int tvoc;
  final DateTime timestamp;

  factory SensorLog.fromJson(Map<String, dynamic> json) {
    return SensorLog(
      id: json['id'] as int,
      shelfId: json['shelf_id'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      co2: json['co2'] as int,
      tvoc: json['tvoc'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

