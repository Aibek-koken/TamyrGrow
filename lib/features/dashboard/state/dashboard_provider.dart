import 'package:flutter/foundation.dart';

import '../../../core/network/api_service.dart';
import '../models/dashboard_summary.dart';
import '../models/shelf_current.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({required ApiService api}) : _api = api;

  final ApiService _api;

  bool _loading = false;
  String? _error;
  DashboardSummary? _summary;
  final Map<int, ShelfCurrent> _currentByShelfId = {};

  bool get isLoading => _loading;
  String? get error => _error;
  DashboardSummary? get summary => _summary;
  Map<int, ShelfCurrent> get currentByShelfId => _currentByShelfId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final summary = await _api.getDashboardSummary();
      _summary = summary;
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

