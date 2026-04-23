import 'package:flutter/material.dart';

import 'database_service.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  await DatabaseService.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: _increaseTextThemeByOne(base.textTheme),
        primaryTextTheme: _increaseTextThemeByOne(base.primaryTextTheme),
      ),
      home: const LoginPage(),
    );
  }
}

TextTheme _increaseTextThemeByOne(TextTheme theme) {
  TextStyle? bump(TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(fontSize: (style.fontSize ?? 14) + 5);
  }

  return theme.copyWith(
    displayLarge: bump(theme.displayLarge),
    displayMedium: bump(theme.displayMedium),
    displaySmall: bump(theme.displaySmall),
    headlineLarge: bump(theme.headlineLarge),
    headlineMedium: bump(theme.headlineMedium),
    headlineSmall: bump(theme.headlineSmall),
    titleLarge: bump(theme.titleLarge),
    titleMedium: bump(theme.titleMedium),
    titleSmall: bump(theme.titleSmall),
    bodyLarge: bump(theme.bodyLarge),
    bodyMedium: bump(theme.bodyMedium),
    bodySmall: bump(theme.bodySmall),
    labelLarge: bump(theme.labelLarge),
    labelMedium: bump(theme.labelMedium),
    labelSmall: bump(theme.labelSmall),
  );
}
