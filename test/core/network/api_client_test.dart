import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';

void main() {
  late HttpServer server;
  late MemoryCookieStore cookieStore;
  late ApiClient api;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cookieStore = MemoryCookieStore();
    api = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      cookieStore: cookieStore,
    );
  });

  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  test('late responses cannot restore cookies after sign-out', () async {
    await cookieStore.write([Cookie('session', 'fixture-session')]);
    final late = Completer<HttpRequest>();
    server.listen((request) {
      if (request.uri.path == '/late') {
        late.complete(request);
        return;
      }
      request.response
        ..write(
          request.uri.path.endsWith('/csrf')
              ? '{"csrfToken":"fixture-csrf"}'
              : '{}',
        )
        ..close();
    });
    final pending = api.get('/late');
    final request = await late.future;
    await AuthRepository(api, cookieStore).signOut();
    expect(await cookieStore.read(), isEmpty);
    request.response.cookies.add(Cookie('session', 'late-session'));
    request.response
      ..write('{}')
      ..close();
    await pending;
    expect(await cookieStore.read(), isEmpty);
  });

  test(
    'a pending mutation cannot borrow cookies from a replacement session',
    () async {
      api.close();
      final delayed = _DelayedReadStore();
      await delayed.write([Cookie('session', 'old-account')]);
      api = ApiClient(
        baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
        cookieStore: delayed,
      );
      var mutations = 0;
      server.listen((request) {
        if (request.method == 'PATCH') mutations++;
        request.response.write(
          jsonEncode({'cookie': request.cookies.single.value}),
        );
        request.response.close();
      });
      final pending = api.patchJson('/api/me', {
        'firstName': 'Old account edit',
      });
      await delayed.readStarted.future;
      await api.clearSession(delayed.clear);
      await delayed.write([Cookie('session', 'new-account')]);
      final cancelled = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      delayed.release.complete();
      await cancelled;
      expect(mutations, 0);
      expect((await api.get('/api/me')).json['cookie'], 'new-account');
    },
  );

  test(
    'locale follows the existing website cookie without changing session cookies',
    () async {
      api.close();
      var language = 'fr';
      api = ApiClient(
        baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
        cookieStore: cookieStore,
        language: () => language,
      );
      await cookieStore.write([
        Cookie('session', 'fixture-session'),
        Cookie('occasio-locale', 'stale'),
      ]);
      var received = 0;
      server.listen((request) {
        final expected = received++ == 0 ? 'fr' : 'en';
        expect(
          request.headers.value(HttpHeaders.acceptLanguageHeader),
          expected,
        );
        expect(
          request.cookies.where((c) => c.name == 'occasio-locale').single.value,
          expected,
        );
        expect(
          request.cookies.singleWhere((c) => c.name == 'session').value,
          'fixture-session',
        );
        request.response
          ..write('{}')
          ..close();
      });
      await api.get('/api/me');
      language = 'en';
      await api.get('/api/me');
      expect(received, 2);
      expect(
        (await cookieStore.read())
            .singleWhere((c) => c.name == 'session')
            .value,
        'fixture-session',
      );
    },
  );

  test(
    'multipart upload preserves binary bytes and uses the existing authenticated client',
    () async {
      await cookieStore.write([Cookie('session', 'fixture-session')]);
      final binary = [0, 1, 255, 13, 10, 42];
      server.listen((request) async {
        expect(request.headers.contentType?.mimeType, 'multipart/form-data');
        expect(request.cookies.single.value, 'fixture-session');
        final received = await request.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        final start = received.indexOf(0);
        expect(received.sublist(start, start + binary.length), binary);
        request.response
          ..write('{"suggestions":[]}')
          ..close();
      });
      final result = await api.postFile(
        '/api/profile/import',
        filename: 'resume.pdf',
        bytes: binary,
      );
      expect(result.statusCode, 200);
    },
  );

  test(
    'read retries recover a transient connection failure without replaying writes',
    () async {
      final transient = _TransientApi();
      addTearDown(transient.close);
      expect((await transient.get('/api/me')).statusCode, 200);
      expect(transient.attempts, 2);
      transient.attempts = 0;
      await expectLater(
        transient.postJson('/api/tracking', {'status': 'drafting'}),
        throwsA(isA<ApiException>()),
      );
      expect(transient.attempts, 1);
    },
  );

  test(
    'binary download preserves bytes, authentication and refreshed cookies',
    () async {
      await cookieStore.write([Cookie('session', 'fixture-session')]);
      server.listen((request) {
        expect(request.cookies.single.value, 'fixture-session');
        request.response.cookies.add(Cookie('session', 'refreshed-session'));
        request.response
          ..headers.contentType = ContentType('application', 'pdf')
          ..add([0, 255, 13, 10, 42])
          ..close();
      });
      expect(await api.getBytes('/api/profile/resume', maxBytes: 5), [
        0,
        255,
        13,
        10,
        42,
      ]);
      expect((await cookieStore.read()).single.value, 'refreshed-session');
    },
  );

  test(
    'binary downloads enforce both announced and streamed byte limits',
    () async {
      var requests = 0;
      server.listen((request) {
        requests++;
        if (request.uri.path == '/announced') {
          request.response.contentLength = 6;
        }
        request.response
          ..add([0, 1, 2, 3, 4, 5])
          ..close();
      });
      for (final path in ['/announced', '/chunked']) {
        await expectLater(
          api.getBytes(path, maxBytes: 5),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              413,
            ),
          ),
        );
      }
      expect(requests, 2);
    },
  );

  test(
    'download metadata belongs to the same response as the original bytes',
    () async {
      server.listen((request) {
        request.response
          ..headers.set(
            HttpHeaders.contentTypeHeader,
            'application/pdf; charset=binary',
          )
          ..headers.set(
            'content-disposition',
            'attachment; filename="Current; CV.pdf"',
          )
          ..add([0, 255, 42])
          ..close();
      });
      final download = await api.getDownload(
        '/api/profile/resume',
        maxBytes: 100,
      );
      expect(download.bytes, [0, 255, 42]);
      expect(download.filename, 'Current; CV.pdf');
      expect(download.mimeType, 'application/pdf');
    },
  );

  test('download prefers the encoded UTF-8 filename over its fallback', () async {
    server.listen((request) {
      request.response
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/pdf')
        ..headers.set(
          'content-disposition',
          "attachment; filename=resume.pdf; filename*=UTF-8''CV%20fran%C3%A7ais.pdf",
        )
        ..add([0, 255, 42])
        ..close();
    });
    final download = await api.getDownload(
      '/api/profile/resume',
      maxBytes: 100,
    );
    expect(download.filename, 'CV français.pdf');
  });

  test(
    'download without usable response metadata does not invent a filename',
    () async {
      server.listen((request) {
        request.response
          ..headers.set(
            'content-disposition',
            'attachment; filename="unterminated',
          )
          ..add([0, 255, 42])
          ..close();
      });
      final download = await api.getDownload(
        '/api/profile/resume',
        maxBytes: 100,
      );
      expect(download.bytes, [0, 255, 42]);
      expect(download.filename, isNull);
      expect(download.mimeType, 'text/plain');
    },
  );

  test(
    'binary download reports API errors and never follows redirects',
    () async {
      var requests = 0;
      server.listen((request) {
        requests++;
        if (request.uri.path == '/redirect') {
          request.response
            ..statusCode = 302
            ..headers.set(HttpHeaders.locationHeader, '/must-not-follow');
        } else {
          request.response
            ..statusCode = 404
            ..write('{"error":"No résumé is saved on this profile."}');
        }
        request.response.close();
      });
      await expectLater(
        api.getBytes('/api/profile/resume', maxBytes: 1000),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 404)
              .having(
                (error) => error.message,
                'message',
                'No résumé is saved on this profile.',
              ),
        ),
      );
      await expectLater(
        api.getBytes('/redirect', maxBytes: 1000),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            302,
          ),
        ),
      );
      expect(requests, 2);
    },
  );

  test(
    'late private bytes never reach a replacement account after sign-out',
    () async {
      await cookieStore.write([Cookie('session', 'old-account')]);
      final arrived = Completer<HttpRequest>();
      server.listen(arrived.complete);
      final pending = api.getBytes('/api/profile/resume', maxBytes: 100);
      final request = await arrived.future;
      await api.clearSession(cookieStore.clear);
      await cookieStore.write([Cookie('session', 'new-account')]);
      final cancelled = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      request.response.cookies.add(Cookie('session', 'late-old-account'));
      request.response
        ..add([0, 255, 42])
        ..close();
      await cancelled;
      expect((await cookieStore.read()).single.value, 'new-account');
    },
  );

  test(
    'binary reads retry a disconnected request using the same session',
    () async {
      var requests = 0;
      server.listen((request) async {
        if (++requests == 1) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
        } else {
          request.response
            ..add([0, 255, 42])
            ..close();
        }
      });
      expect(await api.getBytes('/api/profile/resume', maxBytes: 100), [
        0,
        255,
        42,
      ]);
      expect(requests, 2);
    },
  );

  test('times out a stalled response with a retryable message', () async {
    api.close();
    api = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      cookieStore: cookieStore,
      requestTimeout: const Duration(milliseconds: 100),
    );
    server.listen((request) {});

    await expectLater(
      api.get('/api/me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  test('connection failure has a readable message', () async {
    await server.close(force: true);
    await expectLater(
      api.get('/api/me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Check your connection'),
        ),
      ),
    );
  });

  test(
    'HTML error responses preserve status without exposing markup',
    () async {
      server.listen((request) {
        request.response
          ..statusCode = 503
          ..write('<html>Internal details</html>')
          ..close();
      });
      await expectLater(
        api.get('/api/me'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 503)
              .having(
                (error) => error.message,
                'message',
                'Request failed with status 503.',
              ),
        ),
      );
    },
  );

  test('reads JSON and stores response cookies', () async {
    server.listen((request) {
      request.response.cookies.add(Cookie('session', 'abc')..path = '/');
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true}))
        ..close();
    });

    final response = await api.get('/api/auth/session');

    expect(response.json, {'ok': true});
    expect((await cookieStore.read()).single.value, 'abc');
  });

  test('returns stored cookies to the API', () async {
    await cookieStore.write([Cookie('session', 'abc')..path = '/']);
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'cookie': request.cookies.single.value}))
        ..close();
    });

    final response = await api.get('/api/me');

    expect(response.json, {'cookie': 'abc'});
  });
}

class _TransientApi extends ApiClient {
  _TransientApi()
    : super(
        baseUri: Uri.parse('https://example.test'),
        cookieStore: MemoryCookieStore(),
      );
  int attempts = 0;
  @override
  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
  }) async {
    if (++attempts == 1) throw const ApiException('Connection interrupted');
    return const ApiResponse(statusCode: 200, body: '{}');
  }
}

class _DelayedReadStore extends MemoryCookieStore {
  final readStarted = Completer<void>();
  final release = Completer<void>();
  bool _delay = true;
  @override
  Future<List<Cookie>> read() async {
    if (_delay) {
      _delay = false;
      readStarted.complete();
      await release.future;
    }
    return super.read();
  }
}
