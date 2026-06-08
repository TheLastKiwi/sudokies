import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../engine/step.dart';
import 'firebase_config.dart';
import 'puzzle.dart';

class PuzzleNotFound implements Exception {
  final String message;
  PuzzleNotFound(this.message);
  @override
  String toString() => message;
}

/// Loads puzzles from Firebase (when configured) with the bundled starter set
/// as an offline fallback.
class PuzzleRepository {
  final http.Client _client;
  final Random _rng = Random();
  Map<Difficulty, List<Puzzle>> _starter = {};
  bool _loaded = false;

  PuzzleRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<void> _ensureStarter() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/puzzles/starter.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = (json['puzzles'] as Map<String, dynamic>?) ?? {};
    final map = {for (final d in Difficulty.values) d: <Puzzle>[]};
    puzzles.forEach((key, value) {
      final tier = difficultyFromId(key);
      for (final p in (value as List)) {
        map[tier]!.add(Puzzle.fromJson(Map<String, dynamic>.from(p as Map)));
      }
    });
    _starter = map;
    _loaded = true;
  }

  /// All starter puzzles flattened (used by repository fallbacks / lookups).
  Future<List<Puzzle>> _allStarter() async {
    await _ensureStarter();
    return [for (final list in _starter.values) ...list];
  }

  /// A random puzzle of the given [difficulty]. Tries Firebase, falls back to
  /// the bundled starter set.
  Future<Puzzle> randomByDifficulty(Difficulty difficulty) async {
    if (firebaseConfigured) {
      try {
        final p = await _randomFromFirebase(difficulty);
        if (p != null) return p;
      } catch (_) {
        // fall through to starter set
      }
    }
    await _ensureStarter();
    final list = _starter[difficulty] ?? const [];
    if (list.isEmpty) {
      throw PuzzleNotFound('No ${difficulty.label} puzzles available offline.');
    }
    return list[_rng.nextInt(list.length)];
  }

  /// Look up a puzzle by its 6-char code (case-insensitive).
  Future<Puzzle> byCode(String code) async {
    final norm = code.trim().toUpperCase();
    if (firebaseConfigured) {
      try {
        final res = await _client
            .get(Uri.parse('$firebaseDbUrl/puzzles/$norm.json'));
        if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return Puzzle.fromJson(json);
        }
      } catch (_) {
        // fall through to starter set
      }
    }
    final all = await _allStarter();
    for (final p in all) {
      if (p.code == norm) return p;
    }
    throw PuzzleNotFound('No puzzle found for code "$norm".');
  }

  Future<Puzzle?> _randomFromFirebase(Difficulty difficulty) async {
    final idxRes = await _client
        .get(Uri.parse('$firebaseDbUrl/index/${difficulty.id}.json'));
    if (idxRes.statusCode != 200 || idxRes.body == 'null') return null;
    final idx = jsonDecode(idxRes.body) as Map<String, dynamic>;
    if (idx.isEmpty) return null;
    final codes = idx.keys.toList();
    final code = codes[_rng.nextInt(codes.length)];
    final res =
        await _client.get(Uri.parse('$firebaseDbUrl/puzzles/$code.json'));
    if (res.statusCode != 200 || res.body == 'null') return null;
    return Puzzle.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
