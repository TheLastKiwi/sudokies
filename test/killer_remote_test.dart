import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sudokies/data/firebase_config.dart';
import 'package:sudokies/data/puzzle_repository.dart';
import 'package:sudokies/engine/step.dart';

/// The app ships 30 Killer puzzles per tier while Firebase holds all 50, so
/// these cover that seam: an online player must be able to draw one of the 20
/// that never shipped, and every way the network can fail has to land back on
/// the bundled bank rather than surfacing an error mid-game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final full = _bank('tool/data/killer_full.json');
  final bundled = _bank('assets/puzzles/killer.json');
  final fullEasy = _codes(full, 'easy');
  final bundledEasy = _codes(bundled, 'easy');

  /// A Killer puzzle that exists in Firebase but was never bundled — the whole
  /// point of trimming the asset.
  final remoteOnly = full['easy']!
      .firstWhere((p) => !bundledEasy.contains(p['code'] as String));
  final remoteOnlyCode = remoteOnly['code'] as String;

  test('the bundled bank is a subset of the uploaded bank', () {
    // Guards tool/trim_bank.dart: a bundled code with no Firebase counterpart
    // would be a share code that resolves on one device and 404s on another.
    for (final tier in bundled.keys) {
      expect(
        _codes(bundled, tier).difference(_codes(full, tier)),
        isEmpty,
        reason: '$tier has bundled codes missing from the full bank',
      );
    }
  });

  test('draws a Killer puzzle that only exists remotely', () async {
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/index/killer/easy.json')) {
          // One code in the index, so the random pick is forced.
          return http.Response(jsonEncode({remoteOnlyCode: true}), 200);
        }
        if (path.endsWith('/puzzles/$remoteOnlyCode.json')) {
          return http.Response(jsonEncode(remoteOnly), 200);
        }
        return http.Response('null', 200);
      }),
    );

    final puzzle = await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(puzzle.code, remoteOnlyCode);
    expect(bundledEasy, isNot(contains(puzzle.code)),
        reason: 'should have come from Firebase, not the bundle');
    expect(puzzle.variant?.type, 'killer');
  });

  test('an empty remote index falls back to the bundled bank', () async {
    final repo = PuzzleRepository(
      client: MockClient((_) async => http.Response('null', 200)),
    );
    final puzzle = await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(bundledEasy, contains(puzzle.code));
  });

  test('a network failure falls back to the bundled bank', () async {
    final repo = PuzzleRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final puzzle = await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(bundledEasy, contains(puzzle.code));
  });

  test('a timeout falls back to the bundled bank', () async {
    final repo = PuzzleRepository(
      client: MockClient((_) async => throw TimeoutException('slow')),
    );
    final puzzle = await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(bundledEasy, contains(puzzle.code));
  });

  test('a puzzle missing from /puzzles falls back rather than throwing',
      () async {
    // Index lists a code, but the puzzle node is gone — a half-finished upload.
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/index/killer/easy.json')) {
          return http.Response(jsonEncode({remoteOnlyCode: true}), 200);
        }
        return http.Response('null', 200);
      }),
    );
    final puzzle = await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(bundledEasy, contains(puzzle.code));
  });

  test('exhausting every code remotely and locally reports exhaustion',
      () async {
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/index/killer/easy.json')) {
          return http.Response(
              jsonEncode({for (final c in fullEasy) c: true}), 200);
        }
        return http.Response('null', 200);
      }),
    );
    await expectLater(
      repo.randomKillerByDifficulty(Difficulty.easy, exclude: fullEasy),
      throwsA(isA<PuzzlesExhausted>()),
    );
  });

  test('excluding the whole bundle still finds a remote puzzle', () async {
    // The case that motivated the split: a player who has played every shipped
    // puzzle should keep getting fresh ones instead of a replay prompt.
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/index/killer/easy.json')) {
          return http.Response(
              jsonEncode({for (final c in fullEasy) c: true}), 200);
        }
        final code = path.split('/').last.replaceAll('.json', '');
        final match = full['easy']!.firstWhere((p) => p['code'] == code);
        return http.Response(jsonEncode(match), 200);
      }),
    );
    final puzzle =
        await repo.randomKillerByDifficulty(Difficulty.easy, exclude: bundledEasy);
    expect(bundledEasy, isNot(contains(puzzle.code)));
    expect(fullEasy, contains(puzzle.code));
  });

  test('the tier index is fetched once per session, not per game', () async {
    var indexHits = 0;
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/index/killer/easy.json')) {
          indexHits++;
          return http.Response(jsonEncode({remoteOnlyCode: true}), 200);
        }
        return http.Response(jsonEncode(remoteOnly), 200);
      }),
    );
    await repo.randomKillerByDifficulty(Difficulty.easy);
    await repo.randomKillerByDifficulty(Difficulty.easy);
    await repo.randomKillerByDifficulty(Difficulty.easy);
    expect(indexHits, 1);
  });

  test('Killer and classic indexes do not share a cache', () async {
    // Both live under /index; a shared cache keyed only by tier would serve
    // classic codes to the Killer picker.
    final requested = <String>[];
    final repo = PuzzleRepository(
      client: MockClient((req) async {
        requested.add(req.url.path);
        return http.Response('null', 200);
      }),
    );
    await repo.randomKillerByDifficulty(Difficulty.easy);
    await repo.randomByDifficulty(Difficulty.easy);
    expect(requested, contains(endsWith('/index/killer/easy.json')));
    expect(requested, contains(endsWith('/index/easy.json')));
  });

  test('a bundled Killer code resolves offline', () async {
    // Killer codes are shareable and resolve from Firebase, so one that arrives
    // while the player is offline must still find the bundled puzzle.
    final code = bundledEasy.first;
    final repo = PuzzleRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final puzzle = await repo.byCode(code);
    expect(puzzle.code, code);
    expect(puzzle.variant?.type, 'killer');
  });

  test('a lowercase bundled Killer code resolves offline', () async {
    final code = bundledEasy.first;
    final repo = PuzzleRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect((await repo.byCode(code.toLowerCase())).code, code);
  });

  test('an unknown code still throws offline', () async {
    final repo = PuzzleRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      repo.byCode('ZZZZZZ'),
      throwsA(isA<PuzzleNotFound>()),
    );
  });

  test('firebaseDbUrl is set, so the remote path is actually live', () {
    // If the URL were ever cleared these tests would pass vacuously by always
    // taking the offline branch.
    expect(firebaseConfigured, isTrue);
  });
}

Map<String, List<Map<String, dynamic>>> _bank(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final puzzles = json['puzzles'] as Map<String, dynamic>;
  return {
    for (final entry in puzzles.entries)
      entry.key: [
        for (final p in (entry.value as List))
          Map<String, dynamic>.from(p as Map)
      ],
  };
}

Set<String> _codes(Map<String, List<Map<String, dynamic>>> bank, String tier) =>
    {for (final p in bank[tier] ?? const []) p['code'] as String};
