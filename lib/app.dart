import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/history_store.dart';
import 'data/puzzle_repository.dart';
import 'data/technique_library.dart';
import 'state/settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

/// Displayed version label. Bump alongside `version` in pubspec.yaml.
const String appVersion = 'v0.1.3';

/// Shared app-wide services, created once at startup.
class Services {
  final SharedPreferences prefs;
  final Settings settings;
  final PuzzleRepository repository;
  final TechniqueLibrary library;
  final HistoryStore history;

  Services({
    required this.prefs,
    required this.settings,
    required this.repository,
    required this.library,
    required this.history,
  });

  static Future<Services> create() async {
    final prefs = await SharedPreferences.getInstance();
    final library = await TechniqueLibrary.load();
    return Services(
      prefs: prefs,
      settings: Settings(prefs),
      repository: PuzzleRepository(),
      library: library,
      history: HistoryStore(prefs),
    );
  }
}

/// Provides [Services] to the widget tree.
class AppScope extends InheritedWidget {
  final Services services;
  const AppScope({super.key, required this.services, required super.child});

  static Services of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

class SudokiesApp extends StatelessWidget {
  final Services services;
  const SudokiesApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Sudokies',
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
