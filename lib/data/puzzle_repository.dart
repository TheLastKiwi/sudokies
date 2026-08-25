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

/// Thrown when every puzzle in a tier has already been attempted, so the
/// caller can offer to replay the tier instead of dead-ending on New Game.
class PuzzlesExhausted implements Exception {
  final Difficulty difficulty;
  PuzzlesExhausted(this.difficulty);
  @override
  String toString() =>
      'Every ${difficulty.label} puzzle has already been attempted.';
}

/// How long a Firebase request may run before the bundled bank is used
/// instead. Without this a captive portal or half-open socket leaves New Game
/// spinning rather than falling back.
const Duration _netTimeout = Duration(seconds: 5);

/// Loads puzzles from Firebase (when configured) with the bundled starter set
/// as an offline fallback.
class PuzzleRepository {
  final http.Client _client;
  final Random _rng = Random();
  Map<Difficulty, List<Puzzle>> _starter = {};
  bool _loaded = false;
  Map<Difficulty, List<Puzzle>> _killer = {};
  bool _killerLoaded = false;

  /// Tier code lists fetched from Firebase, cached for the session. Picking an
  /// unattempted puzzle needs the whole candidate list, and without this cache
  /// every New Game would re-download it.
  final Map<Difficulty, List<String>> _indexCache = {};

  PuzzleRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<void> _ensureStarter() async {
    if (_loaded) return;
    _starter = await _loadBank('assets/puzzles/starter.json');
    _loaded = true;
  }

  /// The bundled Killer bank, keyed by tier. Local-only (Killer puzzles carry
  /// arbitrary cage rules and are not served from Firebase).
  Future<void> _ensureKiller() async {
    if (_killerLoaded) return;
    _killer = await _loadBank('assets/puzzles/killer.json');
    _killerLoaded = true;
  }

  Future<Map<Difficulty, List<Puzzle>>> _loadBank(String asset) async {
    final raw = await rootBundle.loadString(asset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = (json['puzzles'] as Map<String, dynamic>?) ?? {};
    final map = {for (final d in Difficulty.values) d: <Puzzle>[]};
    puzzles.forEach((key, value) {
      final tier = difficultyFromId(key);
      for (final p in (value as List)) {
        map[tier]!.add(Puzzle.fromJson(Map<String, dynamic>.from(p as Map)));
      }
    });
    return map;
  }

  /// A random bundled Killer puzzle of the given [difficulty], skipping any
  /// code in [exclude]. Throws [PuzzlesExhausted] once the tier is used up.
  Future<Puzzle> randomKillerByDifficulty(
    Difficulty difficulty, {
    Set<String> exclude = const {},
  }) async {
    await _ensureKiller();
    final list = _killer[difficulty] ?? const [];
    if (list.isEmpty) {
      throw PuzzleNotFound(
          'No ${difficulty.label} Killer puzzles available offline.');
    }
    final fresh = [
      for (final p in list)
        if (!exclude.contains(p.code)) p
    ];
    if (fresh.isEmpty) throw PuzzlesExhausted(difficulty);
    return fresh[_rng.nextInt(fresh.length)];
  }

  /// Tiers that actually have bundled Killer puzzles (Killer omits Extreme), so
  /// a variant picker can show only the difficulties that exist.
  Future<List<Difficulty>> killerTiers() async {
    await _ensureKiller();
    return [
      for (final d in Difficulty.values)
        if ((_killer[d] ?? const []).isNotEmpty) d
    ];
  }

  /// All starter puzzles flattened (used by repository fallbacks / lookups).
  Future<List<Puzzle>> _allStarter() async {
    await _ensureStarter();
    return [for (final list in _starter.values) ...list];
  }

  /// A random puzzle of the given [difficulty], skipping any code in [exclude]
  /// so the player isn't handed one they have already seen. Tries Firebase,
  /// falls back to the bundled starter set.
  ///
  /// Throws [PuzzlesExhausted] when every puzzle in the tier is excluded, which
  /// the caller can turn into a "replay this tier?" prompt.
  Future<Puzzle> randomByDifficulty(
    Difficulty difficulty, {
    Set<String> exclude = const {},
  }) async {
    if (firebaseConfigured) {
      try {
        final p = await _randomFromFirebase(difficulty, exclude);
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
    final fresh = [
      for (final p in list)
        if (!exclude.contains(p.code)) p
    ];
    // Remote exhaustion falls through to here, so the local bank is the single
    // place that decides a tier is finished.
    if (fresh.isEmpty) throw PuzzlesExhausted(difficulty);
    return fresh[_rng.nextInt(fresh.length)];
  }

  /// Look up a puzzle by its 6-char code (case-insensitive).
  Future<Puzzle> byCode(String code) async {
    final norm = code.trim().toUpperCase();
    if (firebaseConfigured) {
      try {
        final res = await _client
            .get(Uri.parse('$firebaseDbUrl/puzzles/$norm.json'))
            .timeout(_netTimeout);
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

  Future<Puzzle?> _randomFromFirebase(
      Difficulty difficulty, Set<String> exclude) async {
    final codes = await _tierIndex(difficulty);
    if (codes == null || codes.isEmpty) return null;
    final fresh = [
      for (final c in codes)
        if (!exclude.contains(c)) c
    ];
    // Exhausted remotely: return null so the local bank gets the final say.
    if (fresh.isEmpty) return null;
    final code = fresh[_rng.nextInt(fresh.length)];
    final res = await _client
        .get(Uri.parse('$firebaseDbUrl/puzzles/$code.json'))
        .timeout(_netTimeout);
    if (res.statusCode != 200 || res.body == 'null') return null;
    return Puzzle.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// The tier's full code list from `/index/<tier>`, fetched once per session.
  Future<List<String>?> _tierIndex(Difficulty difficulty) async {
    final cached = _indexCache[difficulty];
    if (cached != null) return cached;
    final res = await _client
        .get(Uri.parse('$firebaseDbUrl/index/${difficulty.id}.json'))
        .timeout(_netTimeout);
    if (res.statusCode != 200 || res.body == 'null') return null;
    final idx = jsonDecode(res.body) as Map<String, dynamic>;
    if (idx.isEmpty) return null;
    final codes = idx.keys.toList();
    _indexCache[difficulty] = codes;
    return codes;
  }
}
