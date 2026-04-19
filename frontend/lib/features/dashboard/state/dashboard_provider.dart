import 'package:flutter/foundation.dart';

import '../../../core/network/api_service.dart';
import '../models/dashboard_summary.dart';
import '../models/shelf.dart';
import '../models/shelf_current.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({required ApiService api}) : _api = api;

  final ApiService _api;

  bool _loading = false;
  String? _error;
  DashboardSummary? _summary;
  final Map<int, ShelfCurrent> _currentByShelfId = {};
  int? _selectedShelfId;

  bool get isLoading => _loading;
  String? get error => _error;
  DashboardSummary? get summary => _summary;
  Map<int, ShelfCurrent> get currentByShelfId => _currentByShelfId;

  /// Globally selected shelf (AI chat, control, etc.). Defaults to the first shelf after load.
  int? get selectedShelfId => _selectedShelfId;

  Shelf? get selectedShelf {
    final id = _selectedShelfId;
    final shelves = _summary?.shelves;
    if (id == null || shelves == null) return null;
    for (final s in shelves) {
      if (s.id == id) return s;
    }
    return null;
  }

  void selectShelf(int shelfId) {
    if (_selectedShelfId == shelfId) return;
    _selectedShelfId = shelfId;
    notifyListeners();
  }

  void _ensureDefaultShelfSelection() {
    final shelves = _summary?.shelves;
    if (shelves == null || shelves.isEmpty) return;
    final valid = _selectedShelfId != null && shelves.any((s) => s.id == _selectedShelfId);
    if (_selectedShelfId == null || !valid) {
      _selectedShelfId = shelves.first.id;
    }
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final summary = await _api.getDashboardSummary();
      _summary = summary;
      _ensureDefaultShelfSelection();
      notifyListeners();

      await Future.wait(
        summary.shelves.map((shelf) async {
          final current = await _api.getShelfCurrent(shelf.id);
          _currentByShelfId[shelf.id] = current;
        }),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

