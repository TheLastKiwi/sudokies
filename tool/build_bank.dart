/// Offline bank builder. Generates puzzles, grades them by the hardest
/// required technique, assigns 6-char codes, mines one clean example per
/// technique, writes the bundled assets, and (if Firebase is configured)
/// uploads everything to the Realtime Database.
///
/// Run:  dart run tool/build_bank.dart [--easy=8 --medium=8 --hard=6 \
///         --expert=4 --extreme=3 --maxAttempts=6000 --upload]
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sudokies/engine/generator.dart';
import 'package:sudokies/engine/solver.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/strategies/strategy.dart';
import 'package:sudokies/data/firebase_config.dart';

const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _makeCode(Random rng, Set<String> used) {
  while (true) {
    final code = [for (var i = 0; i < 6; i++) _alphabet[rng.nextInt(_alphabet.length)]].join();
    if (used.add(code)) return code;
  }
}

Map<String, int> _parseArgs(List<String> args) {
  final defaults = {
    'easy': 300,
    'medium': 300,
    'hard': 300,
    'expert': 300,
    'extreme': 300,
    'maxAttempts': 2000000,
  };
  for (final a in args) {
    final m = RegExp(r'^--(\w+)=(\d+)$').firstMatch(a);
    if (m != null) defaults[m.group(1)!] = int.parse(m.group(2)!);
  }
  return defaults;
}

Future<void> main(List<String> args) async {
  final cfg = _parseArgs(args);
  final upload = args.contains('--upload');
  final rng = Random();
  final gen = Generator();

  final quotas = {
    Difficulty.easy: cfg['easy']!,
    Difficulty.medium: cfg['medium']!,
    Difficulty.hard: cfg['hard']!,
    Difficulty.expert: cfg['expert']!,
    Difficulty.extreme: cfg['extreme']!,
  };
  final buckets = {for (final d in Difficulty.values) d: <Map<String, String>>[]};
  final usedCodes = <String>{};
  final examples = <String, String>{}; // strategyId -> example board

  final maxAttempts = cfg['maxAttempts']!;
  var attempts = 0;
  final sw = Stopwatch()..start();

  bool full() => Difficulty.values.every((d) => buckets[d]!.length >= quotas[d]!);

  while (!full() && attempts < maxAttempts) {
    attempts++;
    // Random removal cap spreads puzzles across difficulty tiers.
    final maxRem = 40 + rng.nextInt(25); // remove 40..64 clues
    final p = gen.generate(maxRemovals: maxRem);
    final result = solveLogically(
      p.board,
      onStep: (id, board) => examples.putIfAbsent(id, () => board),
    );
    if (!result.solved || result.tier == null) continue;
    final tier = result.tier!;
    if (buckets[tier]!.length >= quotas[tier]!) continue;
    final code = _makeCode(rng, usedCodes);
    buckets[tier]!.add({
      'code': code,
      'board': p.board,
      'solution': p.solution,
      'difficulty': tier.id,
    });
    stdout.write('\r${_progress(buckets, quotas)}  attempts=$attempts  '
        'examples=${examples.length}/${allStrategies.length}   ');
  }
  stdout.writeln();
  stdout.writeln('Done in ${sw.elapsed.inSeconds}s after $attempts attempts.');

  // --- Write starter asset ---
  final starter = {
    'version': 1,
    'puzzles': {
      for (final d in Difficulty.values) d.id: buckets[d],
    },
  };
  File('assets/puzzles/starter.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(starter),
  );
  stdout.writeln('Wrote assets/puzzles/starter.json');

  // --- Write techniques asset (mined examples) ---
  final techniques = [
    for (final s in allStrategies)
      {
        'id': s.id,
        'name': s.name,
        'tier': s.tier.id,
        'rank': s.rank,
        'description': s.description,
        'exampleBoard': examples[s.id] ?? '',
      },
  ];
  File('assets/techniques.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert({'version': 1, 'techniques': techniques}),
  );
  final missing = allStrategies.where((s) => (examples[s.id] ?? '').isEmpty);
  stdout.writeln('Wrote assets/techniques.json'
      '${missing.isEmpty ? '' : ' (no example found for: ${missing.map((s) => s.id).join(', ')})'}');

  // --- Optional upload ---
  if (upload) {
    if (!firebaseConfigured) {
      stdout.writeln('Skipping upload: firebaseDbUrl is empty in '
          'lib/data/firebase_config.dart');
    } else {
      await _upload(buckets, techniques);
    }
  } else {
    stdout.writeln('(pass --upload to push to Firebase)');
  }
}

String _progress(
  Map<Difficulty, List<Map<String, String>>> buckets,
  Map<Difficulty, int> quotas,
) =>
    Difficulty.values
        .map((d) => '${d.id.substring(0, 1).toUpperCase()}:'
            '${buckets[d]!.length}/${quotas[d]}')
        .join(' ');

Future<void> _upload(
  Map<Difficulty, List<Map<String, String>>> buckets,
  List<Map<String, dynamic>> techniques,
) async {
  final base = firebaseDbUrl;
  var count = 0;
  for (final list in buckets.values) {
    for (final p in list) {
      final code = p['code']!;
      await http.put(Uri.parse('$base/puzzles/$code.json'),
          body: jsonEncode(p));
      await http.put(
          Uri.parse('$base/index/${p['difficulty']}/$code.json'),
          body: jsonEncode(true));
      count++;
    }
  }
  await http.put(Uri.parse('$base/techniques.json'),
      body: jsonEncode(techniques));
  stdout.writeln('Uploaded $count puzzles + techniques to $base');
}
