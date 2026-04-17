import 'shelf.dart';

class DashboardSummary {
  const DashboardSummary({required this.shelves});

  final List<Shelf> shelves;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['shelves'] as List<dynamic>? ?? const []);
    return DashboardSummary(
      shelves: raw
          .map((e) => Shelf.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

