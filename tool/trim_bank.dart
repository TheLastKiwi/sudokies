/// Cuts the full puzzle banks down to the subset that ships inside the app.
///
/// The full banks (`tool/data/*_full.json`) are committed but not bundled —
/// every puzzle in them lives in Firebase. The app asset only needs enough to
/// stay playable with no network at all, so this writes the first [_perTier]
/// puzzles of each tier into `assets/puzzles/`.
///
/// Selection is evenly spaced across each tier rather than the first N, so the
/// shipped subset isn't biased toward whatever the generator happened to emit
/// first. It uses no RNG: re-running produces a byte-identical asset, which
/// keeps the bundled codes stable across builds so share codes people already
/// hold keep resolving.
///
/// Run:  dart run tool/trim_bank.dart [--count=30] [--dry-run]
library;

import 'dart:convert';
import 'dart:io';

/// How many puzzles per tier ship in the app bundle.
const int _perTier = 30;

const _banks = <({String full, String asset, String label})>[
  (
    full: 'tool/data/starter_full.json',
    asset: 'assets/puzzles/starter.json',
    label: 'classic',
  ),
  (
    full: 'tool/data/killer_full.json',
    asset: 'assets/puzzles/killer.json',
    label: 'killer',
  ),
];

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final count = int.tryParse(
        args
            .firstWhere((a) => a.startsWith('--count='), orElse: () => '')
            .replaceFirst('--count=', ''),
      ) ??
      _perTier;

  if (count < 1) {
    stderr.writeln('--count must be at least 1.');
    exit(1);
  }

  for (final bank in _banks) {
    final source = _readJson(bank.full);
    final tiers = (source['puzzles'] as Map<String, dynamic>);

    final trimmed = <String, dynamic>{};
    final shortfalls = <String>[];
    tiers.forEach((tier, list) {
      final all = list as List;
      final picked = _spread(all, count);
      trimmed[tier] = picked;
      if (all.length < count) shortfalls.add('$tier ${all.length}/$count');
    });

    final out = {'version': source['version'] ?? 1, 'puzzles': trimmed};
    final text = const JsonEncoder.withIndent('  ').convert(out);

    final kept = trimmed.values.fold<int>(0, (n, l) => n + (l as List).length);
    final total = tiers.values.fold<int>(0, (n, l) => n + (l as List).length);
    stdout.writeln('${bank.label}: $kept of $total puzzles '
        '(${_kb(text)}) -> ${bank.asset}');
    for (final tier in trimmed.keys) {
      stdout.writeln('  $tier: ${(trimmed[tier] as List).length}');
    }
    if (shortfalls.isNotEmpty) {
      stdout.writeln('  short of --count: ${shortfalls.join(', ')}');
    }

    if (!dryRun) {
      final file = File(bank.asset);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
    }
  }

  if (dryRun) {
    stdout.writeln('\n--dry-run: no assets written.');
  } else {
    stdout.writeln('\nWrote the shipped assets. The full banks in tool/data/ '
        'are unchanged — upload them with tool/upload_bank.dart.');
  }
}

/// [count] items spread evenly across [all], in source order.
///
/// Index `i * len ~/ count` walks the list at a constant stride, so the picks
/// span the whole tier and stay distinct for any `count <= all.length`. Returns
/// every item when the tier is smaller than [count].
List<dynamic> _spread(List<dynamic> all, int count) {
  if (all.length <= count) return List<dynamic>.from(all);
  return [
    for (var i = 0; i < count; i++) all[i * all.length ~/ count],
  ];
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — run from the repo root.');
    exit(1);
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _kb(String text) =>
    '${(utf8.encode(text).length / 1024).toStringAsFixed(0)} KB';
