import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';

void main() {
  late HttpServer server;
  late ApiClient api;
  late MemoryCookieStore cookies;
  late AuthRepository auth;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cookies = MemoryCookieStore();
    api = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      cookieStore: cookies,
    );
    auth = AuthRepository(api, cookies);
  });

  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  test(
    'credentials flow normalizes email and confirms the cookie session',
    () async {
      Map<String, String>? submitted;
      server.listen((request) async {
        switch (request.uri.path) {
          case '/api/auth/csrf':
            request.response.write(jsonEncode({'csrfToken': 'fixture-csrf'}));
          case '/api/auth/callback/credentials':
            submitted = Uri.splitQueryString(
              await utf8.decoder.bind(request).join(),
            );
            request.response.cookies.add(
              Cookie('session', 'fixture-session')..path = '/',
            );
            request.response.statusCode = 302;
          case '/api/auth/session':
            expect(request.cookies.single.value, 'fixture-session');
            request.response.write(
              jsonEncode({
                'user': {'email': 'fixture@example.test'},
              }),
            );
          default:
            request.response.statusCode = 404;
        }
        await request.response.close();
      });

      final session = await auth.signIn(
        email: ' Fixture@Example.Test ',
        password: 'fixture-only',
      );
      expect(session.isAuthenticated, isTrue);
      expect(submitted?['email'], 'fixture@example.test');
      expect(submitted?['csrfToken'], 'fixture-csrf');
    },
  );

  test('malformed CSRF response gives a controlled error', () async {
    server.listen(
      (request) => request.response
        ..write('[]')
        ..close(),
    );
    await expectLater(
      auth.signIn(email: 'fixture@example.test', password: 'fixture-only'),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'successful HTTP callback without an authenticated session fails sign-in',
    () async {
      server.listen((request) {
        request.response
          ..write(
            request.uri.path == '/api/auth/csrf'
                ? '{"csrfToken":"fixture-csrf"}'
                : '{}',
          )
          ..close();
      });
      await expectLater(
        auth.signIn(email: 'fixture@example.test', password: 'fixture-only'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
    },
  );

  test('sign-out storage failure is not reported as success', () async {
    server.listen(
      (request) => request.response
        ..statusCode = 503
        ..close(),
    );
    final failingStore = _FailingCookieStore();
    final repository = AuthRepository(api, failingStore);
    await expectLater(repository.signOut(), throwsStateError);
  });
}

class _FailingCookieStore extends MemoryCookieStore {
  @override
  Future<void> clear() async => throw StateError('Fixture storage failure');
}
