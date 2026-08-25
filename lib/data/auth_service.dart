import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// An anonymous Firebase identity, spoken directly to the Identity Toolkit
/// REST API.
///
/// Deliberately SDK-free (no `firebase_core` / `firebase_auth`): those pull the
/// Firebase JS SDK into the web build, which would undo the app's
/// fully-offline guarantee. Everything here is plain `http`.
///
/// Sign-in is best-effort. When the API key is unset, the device is offline, or
/// the call fails, [idToken] resolves to null and callers fall back to
/// local-only behaviour rather than blocking the user.
///
/// The refresh token lives in shared_preferences — localStorage on web — so
/// clearing site data drops the identity. Recovering from that needs a restore
/// code the player can write down; that is not built yet.
class AuthService {
  static const _uidKey = 'auth_uid_v1';
  static const _refreshKey = 'auth_refresh_token_v1';

  /// ID tokens last an hour. Renew early so an in-flight request never races
  /// expiry.
  static const _renewSkew = Duration(minutes: 5);
  static const _timeout = Duration(seconds: 8);

  final SharedPreferences _prefs;
  final http.Client _client;
  final String _apiKey;

  String? _uid;
  String? _idToken;
  DateTime? _renewAt;
  Future<String?>? _inFlight;

  AuthService(this._prefs, {http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? firebaseApiKey {
    _uid = _prefs.getString(_uidKey);
  }

  /// The anonymous account id. Cached across launches, so this stays non-null
  /// offline once sign-in has succeeded at least once.
  String? get uid => _uid;

  /// Whether sign-in is possible at all.
  bool get enabled => _apiKey.isNotEmpty;

  /// A valid ID token to pass as `?auth=` on Realtime Database REST calls.
  /// Signs in on first use, refreshes when stale, and returns null rather than
  /// throwing when unavailable. Concurrent callers share one network round-trip.
  Future<String?> idToken() {
    if (!enabled) return Future.value(null);
    final cached = _idToken;
    if (cached != null && _renewAt != null &&
        DateTime.now().isBefore(_renewAt!)) {
      return Future.value(cached);
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _authenticate();
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  /// Refresh the stored credential if there is one, otherwise claim a new
  /// anonymous identity.
  Future<String?> _authenticate() async {
    try {
      final refreshToken = _prefs.getString(_refreshKey);
      if (refreshToken != null) {
        final token = await _refresh(refreshToken);
        if (token != null) return token;
        // Rejected outright — revoked, or the project was rebuilt. Drop the
        // dead credential and start over rather than staying stuck forever.
        await _prefs.remove(_refreshKey);
        await _prefs.remove(_uidKey);
        _uid = null;
      }
      return await _signUp();
    } catch (_) {
      // Offline or transient. Keep whatever identity we already have.
      return null;
    }
  }

  /// Exchanges a refresh token for a fresh ID token. Returns null only when the
  /// server rejects the token; transport failures throw instead, so a flaky
  /// network never costs the player their account.
  Future<String?> _refresh(String refreshToken) async {
    final res = await _client
        .post(
          Uri.parse(
              'https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await _store(
        uid: json['user_id'] as String,
        idToken: json['id_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: json['expires_in'],
      );
      return _idToken;
    }
    if (res.statusCode == 400 || res.statusCode == 403) return null;
    throw http.ClientException('Token refresh failed (${res.statusCode})');
  }

  Future<String?> _signUp() async {
    final res = await _client
        .post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp'
              '?key=$_apiKey'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'returnSecureToken': true}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      // Most often ADMIN_ONLY_OPERATION: Anonymous sign-in is still disabled
      // under Authentication → Sign-in method in the console.
      throw http.ClientException(
          'Anonymous sign-in failed (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    await _store(
      uid: json['localId'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'],
    );
    return _idToken;
  }

  /// Both endpoints report the lifetime as a string of seconds; tolerate a
  /// number in case that ever changes.
  Future<void> _store({
    required String uid,
    required String idToken,
    required String refreshToken,
    required Object? expiresIn,
  }) async {
    final seconds = expiresIn is num
        ? expiresIn.toInt()
        : int.tryParse('${expiresIn ?? ''}') ?? 3600;
    final lifetime = Duration(seconds: seconds);
    _uid = uid;
    _idToken = idToken;
    _renewAt = DateTime.now()
        .add(lifetime > _renewSkew ? lifetime - _renewSkew : lifetime);
    await _prefs.setString(_uidKey, uid);
    await _prefs.setString(_refreshKey, refreshToken);
  }
}
