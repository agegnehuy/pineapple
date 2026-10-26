import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/data/native_auth_repository.dart';
import 'package:myoccasio/features/auth/data/system_auth_browser.dart';

class RecordingAuthBrowser implements AuthBrowser {
  Future<Uri> Function(Uri)? open;
  Future<void> Function()? close;
  final urls = <Uri>[];
  int cancellations = 0;
  @override
  Future<Uri> authenticate(Uri url) {
    urls.add(url);
    return open!(url);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    await close?.call();
  }
}

class _FailingCookieStore extends MemoryCookieStore {
  bool failClear = true;
  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Fixture encrypted storage unavailable');
    await super.clear();
  }
}

void main() {
  late HttpServer server;
  late ApiClient api;
  late MemoryCookieStore cookies;
  late NativeAuthRepository repository;
  late RecordingAuthBrowser browser;
  late Uri base;
  late Map<String, dynamic> started;
  late List<String> requests;
  const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  final now = DateTime.utc(2026, 10, 24, 12);

  Future<void> listen({
    bool enabled = true,
    int configStatus = 200,
    String callback = NativeAuthRepository.callbackUri,
    String? authorization,
    bool authenticated = true,
    bool sessionAuthenticated = true,
    Completer<void>? exchangeGate,
    Completer<void>? exchangeStarted,
    int exchangeStatus = 200,
    bool expired = false,
  }) async {
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/api/auth/native/config':
          request.response.statusCode = configStatus;
          request.response.write(
            jsonEncode({
              'enabled': enabled,
              'callbackUri': callback,
              'providers': enabled
                  ? [
                      {'id': 'google', 'name': 'Google'},
                    ]
                  : [],
            }),
          );
        case '/api/auth/native/start':
          started = jsonDecode(await utf8.decoder.bind(request).join());
          request.response.statusCode = 201;
          request.response.write(
            jsonEncode({
              'authorizationUrl':
                  authorization ?? '$base/auth/native?request=$code',
              'expiresAt': now
                  .add(Duration(minutes: expired ? -1 : 10))
                  .toIso8601String(),
            }),
          );
        case '/api/auth/native/exchange':
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          expect(
            body.keys,
            unorderedEquals(['code', 'codeVerifier', 'redirectUri']),
          );
          expect(body['code'], code);
          expect(body['redirectUri'], NativeAuthRepository.callbackUri);
          final verifier = body['codeVerifier'] as String;
          expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
          expect(
            base64Url
                .encode(sha256.convert(ascii.encode(verifier)).bytes)
                .replaceAll('=', ''),
            started['codeChallenge'],
          );
          expect(verifier, isNot(started['state']));
          exchangeStarted?.complete();
          await exchangeGate?.future;
          request.response.statusCode = exchangeStatus;
          request.response.cookies.add(
            Cookie('session', 'fixture-native-session')..path = '/',
          );
          request.response.write(jsonEncode({'authenticated': authenticated}));
        case '/api/auth/session':
          expect(
            request.cookies.any(
              (cookie) =>
                  cookie.name == 'session' &&
                  cookie.value == 'fixture-native-session',
            ),
            isTrue,
          );
          request.response.write(
            jsonEncode(
              sessionAuthenticated
                  ? {
                      'user': {
                        'id': 'fixture-student',
                        'email': 'fixture@example.test',
                      },
                    }
                  : {},
            ),
          );
        default:
          request.response.statusCode = 404;
      }
      await request.response.close();
    });
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://${server.address.host}:${server.port}');
    cookies = MemoryCookieStore();
    api = ApiClient(baseUri: base, cookieStore: cookies);
    browser = RecordingAuthBrowser();
    repository = NativeAuthRepository(
      api: api,
      auth: AuthRepository(api, cookies),
      cookies: cookies,
      baseUri: base,
      browser: browser,
      now: () => now,
    );
    started = {};
    requests = [];
    browser.open = (_) async => Uri.parse(
      '${NativeAuthRepository.callbackUri}?code=$code&state=${started['state']}',
    );
  });
  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  test('PKCE handoff confirms the existing normal cookie session', () async {
    await listen();
    final session = await repository.signIn();
    expect(session.user?['id'], 'fixture-student');
    expect(
      started.keys,
      unorderedEquals([
        'provider',
        'state',
        'codeChallenge',
        'codeChallengeMethod',
        'redirectUri',
      ]),
    );
    expect(started['provider'], 'google');
    expect(started['codeChallengeMethod'], 'S256');
    expect(started['state'], matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(browser.urls.single.origin, base.origin);
    expect((await cookies.read()).single.value, 'fixture-native-session');
    expect(requests.where((path) => path.endsWith('/exchange')).length, 1);
  });

  for (final variant in ['old server', 'disabled', 'wrong callback']) {
    test('$variant hides Google and sends no sign-in mutation', () async {
      await listen(
        configStatus: variant == 'old server' ? 404 : 200,
        enabled: variant != 'disabled',
        callback: variant == 'wrong callback'
            ? 'evil://callback'
            : NativeAuthRepository.callbackUri,
      );
      expect(await repository.googleAvailable(), isFalse);
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      expect(browser.urls, isEmpty);
      expect(requests.any((path) => path.endsWith('/start')), isFalse);
    });
  }

  for (final variant in ['foreign origin', 'duplicate request', 'expired']) {
    test('$variant authorization response never opens browser', () async {
      await listen(
        authorization: variant == 'foreign origin'
            ? 'https://example.test/auth/native?request=$code'
            : variant == 'duplicate request'
            ? '$base/auth/native?request=$code&request=$code'
            : null,
        expired: variant == 'expired',
      );
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      expect(browser.urls, isEmpty);
      expect(requests.any((path) => path.endsWith('/exchange')), isFalse);
    });
  }

  for (final variant in [
    'state mismatch',
    'duplicate code',
    'fragment',
    'other scheme',
    'provider error',
  ]) {
    test('$variant callback is rejected before exchange', () async {
      await listen();
      browser.open = (_) async => Uri.parse(switch (variant) {
        'state mismatch' =>
          '${NativeAuthRepository.callbackUri}?code=$code&state=$code',
        'duplicate code' =>
          '${NativeAuthRepository.callbackUri}?code=$code&code=$code&state=${started['state']}',
        'fragment' =>
          '${NativeAuthRepository.callbackUri}?code=$code&state=${started['state']}#ignored',
        'other scheme' =>
          'evil://callback?code=$code&state=${started['state']}',
        _ =>
          '${NativeAuthRepository.callbackUri}?error=denied&state=${started['state']}',
      });
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      expect(requests.any((path) => path.endsWith('/exchange')), isFalse);
      expect(await cookies.read(), isEmpty);
    });
  }

  test(
    'a JSON success without a confirmed session clears exchange cookies',
    () async {
      await listen(sessionAuthenticated: false);
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      expect(await cookies.read(), isEmpty);
    },
  );

  test('failed exchange is not retried and cannot retain a cookie', () async {
    await listen(exchangeStatus: 503);
    await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
    expect(requests.where((path) => path.endsWith('/exchange')).length, 1);
    expect(await cookies.read(), isEmpty);
  });

  test(
    'cancelling delayed failed-exchange cleanup cannot erase a replacement session',
    () async {
      await listen(exchangeStatus: 503);
      final closeStarted = Completer<void>();
      final closeGate = Completer<void>();
      browser.close = () {
        if (browser.cancellations == 1) {
          closeStarted.complete();
          return closeGate.future;
        }
        return Future.value();
      };
      final controller = AppSessionController(
        AuthRepository(api, cookies),
        nativeAuth: repository,
      )..status = AppSessionStatus.unauthenticated;
      addTearDown(controller.dispose);
      final pending = controller.signInWithGoogle();
      final assertion = expectLater(pending, throwsA(isA<ApiException>()));
      await closeStarted.future;
      expect(repository.pending, isTrue);
      expect((await cookies.read()).single.value, 'fixture-native-session');
      await expectLater(
        controller.signIn(
          email: 'replacement@example.test',
          password: 'fixture-only-password',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(
        requests.any((path) => path.endsWith('/callback/credentials')),
        isFalse,
      );
      await controller.cancelNativeSignIn();
      expect(repository.pending, isFalse);
      expect(await cookies.read(), isEmpty);
      final replacementGeneration = api.sessionGeneration;
      await cookies.write([Cookie('replacement', 'replacement-fixture')]);
      closeGate.complete();
      await assertion;
      expect(api.sessionGeneration, replacementGeneration);
      expect((await cookies.read()).single.name, 'replacement');
      expect((await cookies.read()).single.value, 'replacement-fixture');
      expect(requests.where((path) => path.endsWith('/exchange')).length, 1);
    },
  );

  test(
    'cancelled browser cannot exchange a late callback; overlapping login is rejected',
    () async {
      await listen();
      final opened = Completer<void>();
      final callback = Completer<Uri>();
      browser.open = (_) {
        opened.complete();
        return callback.future;
      };
      final pending = repository.signIn();
      final assertion = expectLater(
        pending,
        throwsA(isA<NativeAuthCancelled>()),
      );
      await opened.future;
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      await repository.cancel();
      callback.complete(
        Uri.parse(
          '${NativeAuthRepository.callbackUri}?code=$code&state=${started['state']}',
        ),
      );
      await assertion;
      expect(requests.any((path) => path.endsWith('/exchange')), isFalse);
    },
  );

  test(
    'cancellation invalidates a delayed exchange cookie before a new account session',
    () async {
      final gate = Completer<void>();
      final began = Completer<void>();
      await listen(exchangeGate: gate, exchangeStarted: began);
      final pending = repository.signIn();
      final assertion = expectLater(
        pending,
        throwsA(isA<NativeAuthCancelled>()),
      );
      await began.future;
      await repository.cancel();
      await cookies.write([Cookie('replacement', 'replacement-fixture')]);
      gate.complete();
      await assertion;
      expect((await cookies.read()).single.name, 'replacement');
      expect(requests.any((path) => path == '/api/auth/session'), isFalse);
    },
  );

  test(
    'old controller completion cannot clear a newer native login operation',
    () async {
      await listen();
      final controller = AppSessionController(
        AuthRepository(api, cookies),
        nativeAuth: repository,
      );
      controller.status = AppSessionStatus.unauthenticated;
      addTearDown(controller.dispose);
      final opened = Completer<void>();
      final oldCallback = Completer<Uri>();
      browser.open = (_) {
        opened.complete();
        return oldCallback.future;
      };
      final old = controller.signInWithGoogle();
      final oldAssertion = expectLater(
        old,
        throwsA(isA<NativeAuthCancelled>()),
      );
      await opened.future;
      final oldState = started['state'];
      await controller.cancelNativeSignIn();
      final newCallback = Completer<Uri>();
      final newOpened = Completer<void>();
      browser.open = (_) {
        newOpened.complete();
        return newCallback.future;
      };
      final newer = controller.signInWithGoogle();
      await newOpened.future;
      oldCallback.complete(
        Uri.parse(
          '${NativeAuthRepository.callbackUri}?code=$code&state=$oldState',
        ),
      );
      await oldAssertion;
      expect(controller.status, AppSessionStatus.unauthenticated);
      await expectLater(
        controller.signInWithGoogle(),
        throwsA(isA<ApiException>()),
      );
      newCallback.complete(
        Uri.parse(
          '${NativeAuthRepository.callbackUri}?code=$code&state=${started['state']}',
        ),
      );
      await newer;
      expect(controller.status, AppSessionStatus.authenticated);
      expect(controller.session?.user?['id'], 'fixture-student');
    },
  );

  test(
    'failed encrypted cleanup retains cancellation and can be retried safely',
    () async {
      api.close();
      final storage = _FailingCookieStore();
      cookies = storage;
      api = ApiClient(baseUri: base, cookieStore: storage);
      repository = NativeAuthRepository(
        api: api,
        auth: AuthRepository(api, storage),
        cookies: storage,
        baseUri: base,
        browser: browser,
        now: () => now,
      );
      await storage.write([Cookie('session', 'old-fixture')]);
      await listen();
      final opened = Completer<void>();
      final callback = Completer<Uri>();
      browser.open = (_) {
        opened.complete();
        return callback.future;
      };
      final pending = repository.signIn();
      final assertion = expectLater(
        pending,
        throwsA(isA<NativeAuthCancelled>()),
      );
      await opened.future;
      await expectLater(repository.cancel(), throwsStateError);
      callback.complete(
        Uri.parse(
          '${NativeAuthRepository.callbackUri}?code=$code&state=${started['state']}',
        ),
      );
      await assertion;
      expect(repository.pending, isTrue);
      await expectLater(repository.signIn(), throwsA(isA<ApiException>()));
      storage.failClear = false;
      await repository.cancel();
      expect(repository.pending, isFalse);
      expect(await storage.read(), isEmpty);
      expect(requests.any((path) => path.endsWith('/exchange')), isFalse);
    },
  );
}
