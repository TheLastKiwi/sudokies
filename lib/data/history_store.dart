import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firebase_config.dart';
import 'history_record.dart';

/// Persists puzzle attempts/completions locally (shared_preferences) and, when
/// Firebase and anonymous sign-in are configured, mirrors them to
/// `history/<uid>/<code>` — a subtree only that signed-in account can touch.
///
/// Local storage is always the source of truth; the mirror is a convenience, so
/// every remote failure is swallowed.
class HistoryStore {
  static const _prefsKey = 'history_records_v1';
  static const _timeout = Duration(seconds: 8);

  final SharedPreferences _prefs;
  final AuthService? _auth;
  final http.Client _client;
  final Map<String, HistoryRecord> _records = {};

  HistoryStore(this._prefs, {AuthService? auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client() {
    _load();
  }

  static Future<HistoryStore> create({
    AuthService? auth,
    http.Client? client,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return HistoryStore(prefs, auth: auth, client: client);
  }

  /// The anonymous account this history mirrors under, or null when sync is off
  /// or sign-in has not succeeded yet.
  String? get uid => _auth?.uid;

  void _load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    for (final r in list) {
      final rec = HistoryRecord.fromJson(Map<String, dynamic>.from(r as Map));
      _records[rec.code] = rec;
    }
  }

  List<HistoryRecord> get records {
    final list = _records.values.toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  HistoryRecord? forCode(String code) => _records[code.toUpperCase()];

  /// Every code the player has opened, finished or not. Used to exclude
  /// puzzles from New Game so they are never handed the same one twice.
  Set<String> get attemptedCodes => _records.keys.toSet();

  /// Codes the player actually solved — a subset of [attemptedCodes].
  Set<String> get completedCodes => {
        for (final r in _records.values)
          if (r.isCompleted) r.code
      };

  Future<void> upsert(HistoryRecord record) async {
    _records[record.code] = record;
    await _persistLocal();
    _pushRemote(record); // fire-and-forget
  }

  Future<void> _persistLocal() async {
    final list = [for (final r in _records.values) r.toJson()];
    await _prefs.setString(_prefsKey, jsonEncode(list));
  }

  /// Mirrors one record into the signed-in account's own subtree. Signs in
  /// lazily on the first push, so a cold start never blocks on the network.
  Future<void> _pushRemote(HistoryRecord record) async {
    final auth = _auth;
    if (auth == null || !auth.enabled || !firebaseConfigured) return;
    try {
      final token = await auth.idToken();
      final id = auth.uid;
      if (token == null || id == null) return; // offline, or sign-in failed
      await _client
          .put(
            Uri.parse('$firebaseDbUrl/history/$id/${record.code}.json'
                '?auth=$token'),
            body: jsonEncode(record.toJson()),
          )
          .timeout(_timeout);
    } catch (_) {
      // The local write already succeeded; nothing to surface.
    }
  }
}
