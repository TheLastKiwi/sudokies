/// Offline Killer-bank builder. Generates Killer puzzles with [KillerGenerator],
/// which grades each by the hardest technique the logical solver needs, buckets
/// them by tier, and writes the full bank to `tool/data/killer_full.json`.
/// `tool/trim_bank.dart` then cuts it down to the shipped asset.
///
/// Killer techniques span Easy..Expert (no Killer technique reaches the Extreme
/// band), so the bank deliberately omits Extreme. If a tier can't be filled
/// within the attempt/time budget the tool reports the shortfall rather than
/// blocking.
///
/// Run:  dart run tool/build_killer_bank.dart \
///         [--easy=50 --medium=50 --hard=50 --expert=50 \
///          --maxSeconds=900 --seed=0]
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sudokies/engine/killer_generator.dart';
import 'package:sudokies/engine/solver.dart';
import 'package:sudokies/engine/step.dart';

const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Tiers the Killer bank targets (Extreme is intentionally excluded).
const List<Difficulty> _tiers = [
  Difficulty.easy,
  Difficulty.medium,
  Difficulty.hard,
  Difficulty.expert,
];

String _makeCode(Random rng, Set<String> used) {
  while (true) {
    final code =
        [for (var i = 0; i < 6; i++) _alphabet[rng.nextInt(_alphabet.length)]]
            .join();
    if (used.add(code)) return code;
  }
}

Map<String, int> _parseArgs(List<String> args) {
  final defaults = {
    'easy': 50,
    'medium': 50,
    'hard': 50,
    'expert': 50,
    'maxSeconds': 900,
    'seed': -1,
  };
  for (final a in args) {
    final m = RegExp(r'^--(\w+)=(-?\d+)$').firstMatch(a);
    if (m != null) defaults[m.group(1)!] = int.parse(m.group(2)!);
  }
  return defaults;
}

void main(List<String> args) {
  final cfg = _parseArgs(args);
  final seed = cfg['seed']! >= 0 ? cfg['seed'] : null;
  final rng = Random(seed);
  final gen = KillerGenerator(seed);

  final quotas = {
    Difficulty.easy: cfg['easy']!,
    Difficulty.medium: cfg['medium']!,
    Difficulty.hard: cfg['hard']!,
    Difficulty.expert: cfg['expert']!,
  };
  final buckets = {for (final d in _tiers) d: <Map<String, dynamic>>[]};
  final usedCodes = <String>{};
  final usedSolutions = <String>{};

  final maxSeconds = cfg['maxSeconds']!;
  final sw = Stopwatch()..start();
  var attempts = 0;

  bool full() => _tiers.every((d) => buckets[d]!.length >= quotas[d]!);
  bool need(Difficulty d) => buckets[d]!.length < quotas[d]!;

  while (!full() && sw.elapsed.inSeconds < maxSeconds) {
    attempts++;
    // Cage size steers difficulty: bigger cages demand harder techniques, small
    // cages give tight combinations that solve with cage-sums alone. Aim it at
    // whichever tier still needs puzzles.
    final maxSize = (need(Difficulty.hard) || need(Difficulty.expert))
        ? 4 + rng.nextInt(3) // 4..6 : reach Hard/Expert
        : need(Difficulty.easy)
            ? 3 // smallest cages : maximise Easy yield
            : 4;
    final p = gen.generate(maxAttempts: 80, maxSize: maxSize);
    // Grade authoritatively here, and reject anything the logical solver can't
    // fully crack from its stored board — the generator's givens fallback can
    // otherwise emit an unsolvable puzzle, which the hint engine would choke on.
    final r = solveLogically(p.board, constraints: p.variant!.constraints);
    if (!r.solved || r.tier == null) continue;
    final tier = r.tier!;
    if (!_tiers.contains(tier)) continue; // skip the rare Extreme carving
    if (buckets[tier]!.length >= quotas[tier]!) continue;
    if (!usedSolutions.add(p.solution)) continue; // de-duplicate
    final json = p.toJson();
    json['code'] = _makeCode(rng, usedCodes);
    json['difficulty'] = tier.id;
    buckets[tier]!.add(json);
    stdout.write('\r${_progress(buckets, quotas)}  attempts=$attempts  '
        '${sw.elapsed.inSeconds}s   ');
  }
  stdout.writeln();
  stdout.writeln('Done in ${sw.elapsed.inSeconds}s after $attempts attempts.');

  final out = {
    'version': 1,
    'puzzles': {for (final d in _tiers) d.id: buckets[d]},
  };
  final file = File('tool/data/killer_full.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Wrote ${file.path}');

  final shortfalls = [
    for (final d in _tiers)
      if (buckets[d]!.length < quotas[d]!)
        '${d.label} ${buckets[d]!.length}/${quotas[d]}'
  ];
  if (shortfalls.isEmpty) {
    stdout.writeln('All tiers filled: '
        '${_tiers.map((d) => '${d.label} ${buckets[d]!.length}').join(', ')}.');
  } else {
    stdout.writeln('Best-effort — under quota: ${shortfalls.join(', ')}.');
  }
}

String _progress(
  Map<Difficulty, List<Map<String, dynamic>>> buckets,
  Map<Difficulty, int> quotas,
) =>
    _tiers
        .map((d) => '${d.id.substring(0, 1).toUpperCase()}:'
            '${buckets[d]!.length}/${quotas[d]}')
        .join(' ');
