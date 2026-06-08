import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';
import 'history_record.dart';

/// Persists puzzle attempts/completions locally (shared_preferences) and, when
/// Firebase is configured, mirrors them to `history/<deviceId>/<code>`.
class HistoryStore {
  static const _prefsKey = 'history_records_v1';
  static const _deviceKey = 'device_id_v1';

  final SharedPreferences _prefs;
  final http.Client _client;
  late final String deviceId;
  final Map<String, HistoryRecord> _records = {};

  HistoryStore(this._prefs, {http.Client? client})
      : _client = client ?? http.Client() {
    deviceId = _prefs.getString(_deviceKey) ?? _newDeviceId();
    _load();
  }

  static Future<HistoryStore> create({http.Client? client}) async {
    final prefs = await SharedPreferences.getInstance();
    return HistoryStore(prefs, client: client);
  }

  String _newDeviceId() {
    final rng = Random.secure();
    final id = List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
    _prefs.setString(_deviceKey, id);
    return id;
  }

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

  Future<void> upsert(HistoryRecord record) async {
    _records[record.code] = record;
    await _persistLocal();
    _pushRemote(record); // fire-and-forget
  }

  Future<void> _persistLocal() async {
    final list = [for (final r in _records.values) r.toJson()];
    await _prefs.setString(_prefsKey, jsonEncode(list));
  }

  void _pushRemote(HistoryRecord record) {
    if (!firebaseConfigured) return;
    final uri =
        Uri.parse('$firebaseDbUrl/history/$deviceId/${record.code}.json');
    _client.put(uri, body: jsonEncode(record.toJson())).catchError(
          (_) => http.Response('', 599),
        );
  }
}
