enum ShelfStatus {
  ok('OK'),
  warning('WARNING'),
  critical('CRITICAL');

  const ShelfStatus(this.value);
  final String value;

  static ShelfStatus fromString(String raw) {
    switch (raw) {
      case 'OK':
        return ShelfStatus.ok;
      case 'WARNING':
        return ShelfStatus.warning;
      case 'CRITICAL':
        return ShelfStatus.critical;
      default:
        return ShelfStatus.warning;
    }
  }
}

class Shelf {
  const Shelf({
    required this.id,
    required this.name,
    required this.status,
  });

  final int id;
  final String name;
  final ShelfStatus status;

  factory Shelf.fromJson(Map<String, dynamic> json) {
    return Shelf(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      status: ShelfStatus.fromString((json['status'] as String?) ?? 'WARNING'),
    );
  }
}

