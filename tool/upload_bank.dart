/// Pushes the full puzzle banks to the Realtime Database.
///
/// Unlike `build_bank.dart`, this does not regenerate anything: it reads the
/// committed banks in `tool/data/` and uploads exactly those, so share codes
/// people already hold keep working. Three bulk writes instead of one request
/// per puzzle.
///
/// Both banks share one flat `/puzzles/<code>` namespace — codes are unique
/// across variants, so `byCode` lookups resolve a Killer share code the same
/// way they resolve a classic one. Only the tier indexes are kept apart:
/// classic at `/index/<tier>`, Killer at `/index/killer/<tier>`. They go up in
/// a single PUT to `/index` because writing the subtrees separately would have
/// each one clobber the other.
///
/// Run:  dart run tool/upload_bank.dart [--dry-run] [--auth=SECRET]
///
/// Writes are rejected by the shipped rules (`database.rules.json` locks
/// everything to read-only), so either pass --auth, or temporarily set
/// `".write": true` at the root in the console, run this, and set it back.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sudokies/data/firebase_config.dart';

const _classicBank = 'tool/data/starter_full.json';
const _killerBank = 'tool/data/killer_full.json';
const _techniquesAsset = 'assets/techniques.json';

/// Where the Killer tier index hangs inside `/index`. Nested rather than a new
/// top-level node so the existing `".read": true` on `/index` already covers
/// it and the rules need no second deploy.
const _killerIndexKey = 'killer';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final auth = args
      .firstWhere((a) => a.startsWith('--auth='), orElse: () => '')
      .replaceFirst('--auth=', '');

  if (!firebaseConfigured && !dryRun) {
    stderr.writeln('firebaseDbUrl is empty in lib/data/firebase_config.dart.');
    exit(1);
  }

  // --- Reshape both banks into the tree the app reads ---
  final puzzles = <String, dynamic>{};
  final index = <String, dynamic>{};

  final classic = _collect(_classicBank, puzzles);
  classic.forEach((tier, codes) => index[tier] = codes);

  final killer = _collect(_killerBank, puzzles);
  if (killer.isNotEmpty) index[_killerIndexKey] = killer;

  final techniques = File(_techniquesAsset).existsSync()
      ? _readJson(_techniquesAsset)['techniques']
      : null;

  stdout.writeln('classic');
  classic.forEach((tier, codes) => stdout.writeln('  $tier: ${codes.length}'));
  stdout.writeln('killer');
  killer.forEach((tier, codes) => stdout.writeln('  $tier: ${codes.length}'));
  stdout.writeln('${puzzles.length} puzzles'
      '${techniques == null ? '' : ' + ${(techniques as List).length} techniques'}');

  if (dryRun) {
    stdout.writeln('\n--dry-run: nothing uploaded. Payload sizes:');
    stdout.writeln('  /puzzles  ${_kb(puzzles)}');
    stdout.writeln('  /index    ${_kb(index)}');
    if (techniques != null) stdout.writeln('  /techniques ${_kb(techniques)}');
    return;
  }

  final query = auth.isEmpty ? '' : '?auth=$auth';
  Future<void> put(String path, Object body) async {
    final res = await http.put(
      Uri.parse('$firebaseDbUrl/$path.json$query'),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      stderr.writeln('\nPUT /$path failed: ${res.statusCode} ${res.body}');
      if (res.statusCode == 401) {
        stderr.writeln('Rules are read-only. Pass --auth=SECRET, or set '
            '".write": true at the root for the duration of the upload.');
      }
      exit(1);
    }
    stdout.writeln('  wrote /$path');
  }

  stdout.writeln('\nUploading to $firebaseDbUrl');
  await put('puzzles', puzzles);
  await put('index', index);
  if (techniques != null) await put('techniques', techniques);
  stdout.writeln('Done.');
}

/// Reads one bank, adds every puzzle to the shared [puzzles] map, and returns
/// its `tier -> {code: true}` index. Aborts on a duplicate code: the flat
/// namespace means a collision would silently overwrite a live puzzle and
/// break whatever share codes point at it.
Map<String, Map<String, bool>> _collect(
  String path,
  Map<String, dynamic> puzzles,
) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — run from the repo root.');
    exit(1);
  }
  final bank = _readJson(path);
  final index = <String, Map<String, bool>>{};

  (bank['puzzles'] as Map<String, dynamic>).forEach((tier, list) {
    index[tier] = {};
    for (final entry in (list as List)) {
      final puzzle = Map<String, dynamic>.from(entry as Map);
      final code = puzzle['code'] as String;
      if (puzzles.containsKey(code)) {
        stderr.writeln('Duplicate code $code in $path — aborting.');
        exit(1);
      }
      puzzles[code] = puzzle;
      index[tier]![code] = true;
    }
  });
  return index;
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — run from the repo root.');
    exit(1);
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _kb(Object body) =>
    '${(utf8.encode(jsonEncode(body)).length / 1024).toStringAsFixed(1)} KB';
