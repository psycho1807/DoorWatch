import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs.dart';
import '../features/setup/setup_screen.dart';
import '../features/setup/entities_screen.dart';
import '../features/doorbell/doorbell_screen.dart';
import '../features/history/history_screen.dart';
import '../features/face_recognition/faces_screen.dart';
import '../features/settings/settings_screen.dart';

class DoorWatchApp extends StatelessWidget {
  const DoorWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DoorWatch',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: _router,
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF1E88E5);   // Bleu HA
    const background = Color(0xFF0D1117); // Noir profond
    const surface = Color(0xFF161B22);    // Surface sombre

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: Color(0xFF42A5F5),
        surface: surface,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  GoRouter get _router => GoRouter(
        initialLocation: Prefs.haUrl.isEmpty ? '/setup' : '/',
        routes: [
          GoRoute(
            path: '/setup',
            builder: (_, __) => const SetupScreen(),
            routes: [
              GoRoute(
                path: 'entities',
                builder: (_, __) => const EntitiesScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/',
            builder: (_, __) => const DoorbellScreen(),
            routes: [
              GoRoute(
                path: 'history',
                builder: (_, __) => const HistoryScreen(),
              ),
              GoRoute(
                path: 'faces',
                builder: (_, __) => const FacesScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      );
}
