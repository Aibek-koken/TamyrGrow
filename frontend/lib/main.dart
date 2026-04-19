import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_service.dart';
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
        ChangeNotifierProvider<ControlProvider>(
          create: (context) => ControlProvider(
            api: context.read<ApiService>(),
            shelfId: 1,
          )..load(),
        ),
      ],
      child: const SmartHydroponicsApp(),
    ),
  );
}

