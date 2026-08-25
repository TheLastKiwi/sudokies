import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudokies/data/auth_service.dart';
import 'package:sudokies/data/firebase_config.dart';
import 'package:sudokies/data/history_record.dart';
import 'package:sudokies/data/history_store.dart';
import 'package:sudokies/engine/step.dart';

const _key = 'test-api-key';

String _signUpBody({
  String uid = 'uid-1',
  String token = 'id-1',
  String refresh = 'refresh-1',
}) =>
    jsonEncode({
      'idToken': token,
      'refreshToken': refresh,
      'expiresIn': '3600',
      'localId': uid,
    });

String _refreshBody({
  String uid = 'uid-1',
  String token = 'id-2',
  String refresh = 'refresh-2',
}) =>
    jsonEncode({
      'access_token': token,
      'expires_in': '3600',
      'token_type': 'Bearer',
      'refresh_token': refresh,
      'id_token': token,
      'user_id': uid,
      'project_id': 'sudokies',
    });

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    test('stays inert without an API key', () async {
      var calls = 0;
      final auth = AuthService(
        await _prefs(),
        apiKey: '',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(auth.enabled, isFalse);
      expect(await auth.idToken(), isNull);
      expect(calls, 0);
    });

    test('signs up anonymously on first use and persists the credential',
        () async {
      final prefs = await _prefs();
      final paths = <String>[];
      final auth = AuthService(
        prefs,
        apiKey: _key,
        client: MockClient((req) async {
          paths.add(req.url.path);
          return http.Response(_signUpBody(), 200);
        }),
      );

      expect(await auth.idToken(), 'id-1');
      expect(auth.uid, 'uid-1');
      expect(paths, ['/v1/accounts:signUp']);
      expect(prefs.getString('auth_uid_v1'), 'uid-1');
      expect(prefs.getString('auth_refresh_token_v1'), 'refresh-1');
    });

    test('reuses a live token instead of re-signing in', () async {
      var calls = 0;
      final auth = AuthService(
        await _prefs(),
        apiKey: _key,
        client: MockClient((_) async {
          calls++;
          return http.Response(_signUpBody(), 200);
        }),
      );

      expect(await auth.idToken(), 'id-1');
      expect(await auth.idToken(), 'id-1');
      expect(calls, 1);
    });

    test('collapses concurrent callers into one round-trip', () async {
      var calls = 0;
      final auth = AuthService(
        await _prefs(),
        apiKey: _key,
        client: MockClient((_) async {
          calls++;
          return http.Response(_signUpBody(), 200);
        }),
      );

      expect(
        await Future.wait([auth.idToken(), auth.idToken(), auth.idToken()]),
        ['id-1', 'id-1', 'id-1'],
      );
      expect(calls, 1);
    });

    test('refreshes the stored credential on relaunch', () async {
      final prefs = await _prefs({
        'auth_uid_v1': 'uid-1',
        'auth_refresh_token_v1': 'refresh-1',
      });
      final hosts = <String>[];
      final sent = <String, String>{};
      final auth = AuthService(
        prefs,
        apiKey: _key,
        client: MockClient((req) async {
          hosts.add(req.url.host);
          sent.addAll(req.bodyFields);
          return http.Response(_refreshBody(), 200);
        }),
      );

      expect(auth.uid, 'uid-1', reason: 'known offline, before any request');
      expect(await auth.idToken(), 'id-2');
      expect(hosts, ['securetoken.googleapis.com']);
      expect(sent['grant_type'], 'refresh_token');
      expect(sent['refresh_token'], 'refresh-1');
      expect(prefs.getString('auth_refresh_token_v1'), 'refresh-2');
    });

    test('a network failure never costs the player their identity', () async {
      final prefs = await _prefs({
        'auth_uid_v1': 'uid-1',
        'auth_refresh_token_v1': 'refresh-1',
      });
      final auth = AuthService(
        prefs,
        apiKey: _key,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(await auth.idToken(), isNull);
      expect(auth.uid, 'uid-1');
      expect(prefs.getString('auth_refresh_token_v1'), 'refresh-1');
    });

    test('a rejected refresh token yields a fresh anonymous account', () async {
      final prefs = await _prefs({
        'auth_uid_v1': 'uid-old',
        'auth_refresh_token_v1': 'revoked',
      });
      final paths = <String>[];
      final auth = AuthService(
        prefs,
        apiKey: _key,
        client: MockClient((req) async {
          paths.add(req.url.path);
          if (req.url.host == 'securetoken.googleapis.com') {
            return http.Response(
                jsonEncode({
                  'error': {'message': 'TOKEN_EXPIRED'}
                }),
                400);
          }
          return http.Response(
              _signUpBody(
                  uid: 'uid-new', token: 'id-new', refresh: 'refresh-new'),
              200);
        }),
      );

      expect(await auth.idToken(), 'id-new');
      expect(auth.uid, 'uid-new');
      expect(paths, ['/v1/token', '/v1/accounts:signUp']);
      expect(prefs.getString('auth_refresh_token_v1'), 'refresh-new');
    });

    test('survives Anonymous sign-in being disabled in the console', () async {
      final auth = AuthService(
        await _prefs(),
        apiKey: _key,
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'message': 'ADMIN_ONLY_OPERATION'}
              }),
              400,
            )),
      );

      expect(await auth.idToken(), isNull);
      expect(auth.uid, isNull);
    });
  });

  group('HistoryStore sync', () {
    final record = HistoryRecord(
      code: 'ABC123',
      difficulty: Difficulty.easy,
      startedAt: DateTime.utc(2026, 1, 1),
      elapsedSeconds: 42,
    );

    test('mirrors a record into the account subtree with an auth token',
        () async {
      final prefs = await _prefs();
      final puts = <http.Request>[];
      final client = MockClient((req) async {
        if (req.url.host == 'identitytoolkit.googleapis.com') {
          return http.Response(_signUpBody(), 200);
        }
        puts.add(req);
        return http.Response('{}', 200);
      });
      final store = HistoryStore(
        prefs,
        auth: AuthService(prefs, apiKey: _key, client: client),
        client: client,
      );

      await store.upsert(record);
      await pumpEventQueue();

      expect(puts, hasLength(1));
      expect(puts.single.method, 'PUT');
      expect(puts.single.url.toString(),
          '$firebaseDbUrl/history/uid-1/ABC123.json?auth=id-1');
      expect(
        jsonDecode(puts.single.body) as Map<String, dynamic>,
        containsPair('elapsedSeconds', 42),
      );
      expect(store.uid, 'uid-1');
    });

    test('stays local-only when sign-in is unavailable', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final store = HistoryStore(await _prefs(), auth: null, client: client);

      await store.upsert(record);
      await pumpEventQueue();

      expect(calls, 0);
      expect(store.records, hasLength(1));
      expect(store.uid, isNull);
    });
  });
}
