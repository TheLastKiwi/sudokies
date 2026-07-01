import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle.dart';

/// Locally-saved puzzles authored in the in-app editor ("My Puzzles"). Stored
/// as a JSON list in shared_preferences, newest first.
class CustomPuzzleStore {
  static const _prefsKey = 'custom_puzzles_v1';

  final SharedPreferences _prefs;
  final List<Puzzle> _puzzles = [];

  CustomPuzzleStore(this._prefs) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      for (final p in jsonDecode(raw) as List) {
        _puzzles.add(Puzzle.fromJson(Map<String, dynamic>.from(p as Map)));
      }
    } catch (_) {
      // Corrupt store — start empty rather than crash.
    }
  }

  List<Puzzle> get puzzles => List.unmodifiable(_puzzles);

  /// Save [puzzle], replacing any existing entry with the same code and moving
  /// it to the front.
  Future<void> add(Puzzle puzzle) async {
    _puzzles.removeWhere((e) => e.code == puzzle.code);
    _puzzles.insert(0, puzzle);
    await _persist();
  }

  Future<void> remove(String code) async {
    _puzzles.removeWhere((e) => e.code == code);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(
        _prefsKey, jsonEncode([for (final p in _puzzles) p.toJson()]));
  }
}
