/// Pushes the already-built puzzle bank to the Realtime Database.
///
/// Unlike `build_bank.dart --upload`, this does not regenerate anything: it
/// reads the committed assets and uploads exactly those, so share codes people
/// already hold keep working. Two bulk writes instead of one request per
/// puzzle.
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

const _starterAsset = 'assets/puzzles/starter.json';
const _techniquesAsset = 'assets/techniques.json';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final auth = args
      .firstWhere((a) => a.startsWith('--auth='), orElse: () => '')
      .replaceFirst('--auth=', '');

  if (!firebaseConfigured && !dryRun) {
    stderr.writeln('firebaseDbUrl is empty in lib/data/firebase_config.dart.');
    exit(1);
  }

  // --- Reshape the bundled bank into the tree the app reads ---
  final starter = _readJson(_starterAsset);
  final puzzles = <String, dynamic>{};
  final index = <String, Map<String, bool>>{};

  (starter['puzzles'] as Map<String, dynamic>).forEach((tier, list) {
    index[tier] = {};
    for (final entry in (list as List)) {
      final puzzle = Map<String, dynamic>.from(entry as Map);
      final code = puzzle['code'] as String;
      if (puzzles.containsKey(code)) {
        stderr.writeln('Duplicate code $code in $_starterAsset — aborting.');
        exit(1);
      }
      puzzles[code] = puzzle;
      index[tier]![code] = true;
    }
  });

  final techniques = File(_techniquesAsset).existsSync()
      ? _readJson(_techniquesAsset)['techniques']
      : null;

  for (final tier in index.keys) {
    stdout.writeln('  $tier: ${index[tier]!.length}');
  }
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
