// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_hydroponics_digital_twin/core/network/api_service.dart';
import 'package:smart_hydroponics_digital_twin/features/dashboard/presentation/dashboard_screen.dart';
import 'package:smart_hydroponics_digital_twin/features/dashboard/state/dashboard_provider.dart';

void main() {
  testWidgets('Dashboard renders empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>(create: (_) => ApiService()),
          ChangeNotifierProvider<DashboardProvider>(
            create: (context) => DashboardProvider(api: context.read<ApiService>()),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No shelves found'), findsOneWidget);
  });
}
