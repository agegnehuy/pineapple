import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';

void main() {
  late HttpServer server;
  late ApiClient api;
  late MemoryCookieStore cookies;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cookies = MemoryCookieStore();
    api = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      cookieStore: cookies,
    );
  });
  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  Future<void> nextAccount() async {
    await api.clearSession(cookies.clear);
    await cookies.write([Cookie('session', 'next-account')]);
  }

  Matcher getSessionChanged() =>
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401));

  test(
    'a delayed bookmark read cannot write to a newly entered account',
    () async {
      final received = Completer<HttpRequest>();
      var writes = 0;
      server.listen((request) {
        if (request.method == 'GET') {
          received.complete(request);
        } else {
          writes++;
          request.response
            ..write('{}')
            ..close();
        }
      });
      final bookmark = ApplicationsRepository(api).bookmark('cat:opportunity');
      final rejected = expectLater(bookmark, getSessionChanged());
      final request = await received.future;
      await nextAccount();
      request.response
        ..write('[]')
        ..close();
      await rejected;
      expect(writes, 0);
      expect((await cookies.read()).single.value, 'next-account');
    },
  );

  test(
    'registration stops before automatic sign-in when its session changed',
    () async {
      final received = Completer<HttpRequest>();
      var laterRequests = 0;
      server.listen((request) {
        if (request.uri.path == '/api/register') {
          received.complete(request);
        } else {
          laterRequests++;
          request.response
            ..write('{"csrfToken":"fixture"}')
            ..close();
        }
      });
      final registration = AuthRepository(api, cookies).register(
        firstName: 'One',
        lastName: 'Student',
        email: 'one@example.test',
        password: 'fixture-only',
      );
      final rejected = expectLater(registration, getSessionChanged());
      final request = await received.future;
      await nextAccount();
      request.response
        ..write('{}')
        ..close();
      await rejected;
      expect(laterRequests, 0);
    },
  );

  test('stale CSRF response cannot start a credential callback', () async {
    final received = Completer<HttpRequest>();
    var callbacks = 0;
    server.listen((request) {
      if (request.uri.path == '/api/auth/csrf') {
        received.complete(request);
      } else {
        callbacks++;
        request.response
          ..write('{}')
          ..close();
      }
    });
    final signIn = AuthRepository(
      api,
      cookies,
    ).signIn(email: 'one@example.test', password: 'fixture-only');
    final rejected = expectLater(signIn, getSessionChanged());
    final request = await received.future;
    await nextAccount();
    request.response
      ..write('{"csrfToken":"fixture"}')
      ..close();
    await rejected;
    expect(callbacks, 0);
  });

  test(
    'late credential callback cannot restore old cookies or read the next session',
    () async {
      final received = Completer<HttpRequest>();
      var sessionReads = 0;
      server.listen((request) {
        switch (request.uri.path) {
          case '/api/auth/csrf':
            request.response
              ..write('{"csrfToken":"fixture"}')
              ..close();
          case '/api/auth/callback/credentials':
            received.complete(request);
          default:
            sessionReads++;
            request.response
              ..write('{}')
              ..close();
        }
      });
      final signIn = AuthRepository(
        api,
        cookies,
      ).signIn(email: 'one@example.test', password: 'fixture-only');
      final rejected = expectLater(signIn, getSessionChanged());
      final request = await received.future;
      await nextAccount();
      request.response.cookies.add(Cookie('session', 'old-account'));
      request.response
        ..statusCode = 302
        ..close();
      await rejected;
      expect(sessionReads, 0);
      expect((await cookies.read()).single.value, 'next-account');
    },
  );

  test('late session read cannot restore a signed-out account', () async {
    final received = Completer<HttpRequest>();
    server.listen(received.complete);
    final restore = AuthRepository(api, cookies).currentSession();
    final rejected = expectLater(restore, getSessionChanged());
    final request = await received.future;
    await nextAccount();
    request.response
      ..write(
        jsonEncode({
          'user': {'email': 'old@example.test'},
        }),
      )
      ..close();
    await rejected;
    expect((await cookies.read()).single.value, 'next-account');
  });

  test(
    'an older sign-out completion cannot clear newer session cookies',
    () async {
      final received = Completer<HttpRequest>();
      server.listen((request) {
        if (request.uri.path == '/api/auth/csrf') {
          request.response
            ..write('{"csrfToken":"fixture"}')
            ..close();
        } else {
          received.complete(request);
        }
      });
      final signOut = AuthRepository(api, cookies).signOut();
      final request = await received.future;
      await nextAccount();
      request.response.cookies.add(Cookie('session', '')..maxAge = 0);
      request.response
        ..write('{}')
        ..close();
      await signOut;
      expect((await cookies.read()).single.value, 'next-account');
    },
  );
}
