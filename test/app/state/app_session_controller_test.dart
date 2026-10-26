import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';

void main() {
  late HttpServer server;
  late ApiClient api;
  late MemoryCookieStore cookies;
  late AppSessionController controller;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cookies = MemoryCookieStore();
    api = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      cookieStore: cookies,
    );
    controller = AppSessionController(AuthRepository(api, cookies));
  });

  tearDown(() async {
    controller.dispose();
    api.close();
    await server.close(force: true);
  });

  test(
    'failed restoration retains cookies and retry restores the session',
    () async {
      var available = false;
      await cookies.write([Cookie('session', 'fixture-session')]);
      server.listen((request) {
        request.response
          ..statusCode = available ? 200 : 503
          ..write(
            jsonEncode(
              available
                  ? {
                      'user': {'email': 'fixture@example.test'},
                    }
                  : {'error': 'Unavailable'},
            ),
          )
          ..close();
      });

      await controller.initialize();
      expect(controller.status, AppSessionStatus.failed);
      expect((await cookies.read()).single.value, 'fixture-session');

      available = true;
      await controller.initialize();
      expect(controller.status, AppSessionStatus.authenticated);
      expect(controller.session?.email, 'fixture@example.test');
    },
  );

  test('empty production-style session shows unauthenticated state', () async {
    server.listen(
      (request) => request.response
        ..write('{}')
        ..close(),
    );
    await controller.initialize();
    expect(controller.status, AppSessionStatus.unauthenticated);
  });

  test('remote sign-out failure still clears cookies and UI session', () async {
    await cookies.write([Cookie('session', 'fixture-session')]);
    server.listen((request) {
      if (request.uri.path == '/api/auth/session') {
        request.response.write(
          jsonEncode({
            'user': {'email': 'fixture@example.test'},
          }),
        );
      } else {
        request.response.statusCode = 503;
      }
      request.response.close();
    });
    await controller.initialize();
    expect(controller.status, AppSessionStatus.authenticated);

    await controller.signOut();
    expect(await cookies.read(), isEmpty);
    expect(controller.status, AppSessionStatus.unauthenticated);
    expect(controller.session, isNull);
  });
}
