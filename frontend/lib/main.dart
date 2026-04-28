import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_service.dart';
import 'features/analytics/state/live_analytics_provider.dart';
import 'features/assistant/state/assistant_provider.dart';
import 'features/control/state/control_provider.dart';
import 'features/dashboard/state/dashboard_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
            api: context.read<ApiService>(),
          )..load(),
        ),
        ChangeNotifierProvider<LiveAnalyticsProvider>(
          create: (context) => LiveAnalyticsProvider(
            api: context.read<ApiService>(),
            dashboard: context.read<DashboardProvider>(),
          )..start(),
        ),
        ChangeNotifierProvider<ControlProvider>(
          create: (context) => ControlProvider(
            api: context.read<ApiService>(),
            shelfId: 1,
          )..load(),
        ),
        ChangeNotifierProvider<AssistantProvider>(
          create: (context) => AssistantProvider(
            api: context.read<ApiService>(),
          ),
        ),
      ],
      child: const SmartHydroponicsApp(),
    ),
  );
}

