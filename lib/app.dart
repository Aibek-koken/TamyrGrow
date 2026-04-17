import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';

class SmartHydroponicsApp extends StatelessWidget {
  const SmartHydroponicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Hydroponics Digital Twin',
      theme: AppTheme.darkTech(textTheme),
      home: const AppShell(),
    );
  }
}

