import 'package:flutter/material.dart';

import '../pages/developer_entry_page.dart';

/// Avvio isolato della Developer UI durante lo sviluppo.
///
/// Esempio:
/// flutter run -t lib/developer/preview/developer_preview_app.dart
void main() {
  runApp(const DeveloperPreviewApp());
}

class DeveloperPreviewApp extends StatelessWidget {
  const DeveloperPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudentLab Developer Preview',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF071522),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF27D8FF),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
        ),
      ),
      home: const DeveloperEntryPage(),
    );
  }
}
