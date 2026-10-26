import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';

void main() {
  test(
    'reset links accept only trusted destinations and one bounded opaque token',
    () {
      for (final value in [
        'https://myoccasio.ca/reset-password?token=fixture_-123',
        'ca.occasiotech.myoccasio://reset-password?token=fixture_-123',
        'ca.occasiotech.myoccasio:/reset-password?token=fixture_-123',
      ]) {
        final link = PasswordResetLink.parse(value)!;
        expect(link.token, 'fixture_-123');
        expect(link.toString(), isNot(contains('fixture_-123')));
      }
      expect(PasswordResetLink.parse('/reset-password?token=fixture'), isNull);
      expect(
        PasswordResetLink.parse(
          '/reset-password?token=fixture',
          fromPlatform: true,
        )!.isValid,
        isTrue,
      );
      for (final value in [
        'http://myoccasio.ca/reset-password?token=fixture',
        'https://myoccasio.ca.evil.test/reset-password?token=fixture',
        'https://myoccasio.ca@evil.test/reset-password?token=fixture',
        'https://myoccasio.ca:444/reset-password?token=fixture',
        'https://evil.test/reset-password?token=fixture',
        'https://myoccasio.ca/auth/callback?token=fixture',
        'ca.occasiotech.myoccasio.auth://callback?token=fixture',
        'https://myoccasio.ca/reset-password?token=fixture#fragment',
      ]) {
        expect(PasswordResetLink.parse(value), isNull);
      }
      for (final query in [
        '',
        '?token=',
        '?token=one&token=two',
        '?token=a%20b',
        '?token=%FF',
        '?token=${'a' * 2049}',
      ]) {
        expect(
          PasswordResetLink.parse(
            'https://myoccasio.ca/reset-password$query',
          )!.isValid,
          isFalse,
        );
      }
    },
  );

  group('existing reset HTTP contract', () {
    late HttpServer server;
    late ApiClient api;
    late AuthRepository auth;
    late MemoryCookieStore cookies;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      cookies = MemoryCookieStore();
      await cookies.write([
        Cookie('session', 'fixture-existing-session')..path = '/',
      ]);
      api = ApiClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        cookieStore: cookies,
      );
      auth = AuthRepository(api, cookies);
    });
    tearDown(() async {
      api.close();
      await server.close(force: true);
    });

    test(
      'posts exact token/password once and preserves the existing session',
      () async {
        var calls = 0;
        server.listen((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.uri.path, '/api/auth/reset-password');
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'token': 'fixture-token',
            'password': '  fixture password  ',
          });
          request.response.write('{"ok":true}');
          await request.response.close();
        });
        await auth.resetPassword(
          token: 'fixture-token',
          password: '  fixture password  ',
        );
        expect(calls, 1);
        expect((await cookies.read()).single.value, 'fixture-existing-session');
      },
    );

    test('invalid local input never sends a mutation', () async {
      var calls = 0;
      server.listen((request) {
        calls++;
        request.response.close();
      });
      await expectLater(
        auth.resetPassword(token: '', password: 'fixture-only'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        auth.resetPassword(token: 'fixture', password: 'short'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    });

    test(
      'invalid/expired server response is preserved without auto retry',
      () async {
        var calls = 0;
        server.listen((request) {
          calls++;
          request.response
            ..statusCode = 400
            ..write('{"error":"Reset link is invalid or has expired."}')
            ..close();
        });
        await expectLater(
          auth.resetPassword(token: 'fixture-token', password: 'fixture-only'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.statusCode, 'status', 400)
                .having(
                  (error) => error.message,
                  'message',
                  'Reset link is invalid or has expired.',
                ),
          ),
        );
        expect(calls, 1);
      },
    );

    test(
      'server failure and unconfirmed 200 never become success or automatic retries',
      () async {
        var calls = 0;
        server.listen((request) {
          calls++;
          request.response
            ..statusCode = calls == 1 ? 503 : 200
            ..write(calls == 1 ? '{"error":"Try later"}' : '{}')
            ..close();
        });
        await expectLater(
          auth.resetPassword(token: 'fixture-token', password: 'fixture-only'),
          throwsA(isA<ApiException>()),
        );
        expect(calls, 1);
        await expectLater(
          auth.resetPassword(token: 'fixture-token', password: 'fixture-only'),
          throwsA(isA<ApiException>()),
        );
        expect(calls, 2);
      },
    );
  });
}
