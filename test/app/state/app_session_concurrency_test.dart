import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import '../../support/deferred_auth_repository.dart';
import '../../support/recording_api.dart';

const firstAccount = AuthSession(
  user: {'id': 'one', 'email': 'one@example.test'},
);
const nextAccount = AuthSession(
  user: {'id': 'two', 'email': 'two@example.test'},
);

void main() {
  late RecordingApi api;
  late DeferredAuthRepository auth;
  late AppSessionController controller;
  setUp(() {
    api = RecordingApi();
    auth = DeferredAuthRepository(api);
    controller = AppSessionController(auth);
  });
  tearDown(() {
    controller.dispose();
    api.close();
  });

  test(
    'repeated restoration shares one request and cannot interrupt sign-in',
    () async {
      final first = controller.initialize();
      final second = controller.initialize();
      expect(second, same(first));
      await Future<void>.delayed(Duration.zero);
      expect(auth.restores, hasLength(1));
      auth.restores.single.complete(const AuthSession(user: null));
      await Future.wait([first, second]);
      final signingIn = controller.signIn(
        email: 'one@example.test',
        password: 'fixture',
      );
      await controller.initialize();
      expect(auth.restores, hasLength(1));
      expect(controller.status, AppSessionStatus.unauthenticated);
      auth.signIns.single.complete(firstAccount);
      await signingIn;
      expect(controller.session, firstAccount);
    },
  );

  test(
    'overlapping sign-in and registration never start a second auth request',
    () async {
      final first = controller.signIn(
        email: 'one@example.test',
        password: 'fixture',
      );
      await expectLater(
        controller.signIn(email: 'two@example.test', password: 'fixture'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        controller.register(
          firstName: 'Two',
          lastName: 'Student',
          email: 'two@example.test',
          password: 'fixture',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(auth.signIns, hasLength(1));
      expect(auth.registrations, isEmpty);
      auth.signIns.single.complete(firstAccount);
      await first;
    },
  );

  test(
    'sign-out invalidates a pending restore and duplicate sign-outs share work',
    () async {
      final restoring = controller.initialize();
      await Future<void>.delayed(Duration.zero);
      final firstSignOut = controller.signOut();
      final secondSignOut = controller.signOut();
      expect(secondSignOut, same(firstSignOut));
      await Future<void>.delayed(Duration.zero);
      expect(auth.signOuts, hasLength(1));
      auth.signOuts.single.complete();
      await firstSignOut;
      auth.restores.single.complete(firstAccount);
      await restoring;
      expect(controller.status, AppSessionStatus.unauthenticated);
      expect(controller.session, isNull);
    },
  );

  test(
    'late sign-in cannot replace an account entered after sign-out',
    () async {
      final stale = controller.signIn(
        email: 'one@example.test',
        password: 'fixture',
      );
      final staleError = expectLater(
        stale,
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      final signingOut = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        controller.signIn(email: 'two@example.test', password: 'fixture'),
        throwsA(isA<ApiException>()),
      );
      auth.signOuts.single.complete();
      await signingOut;
      final current = controller.signIn(
        email: 'two@example.test',
        password: 'fixture',
      );
      auth.signIns.last.complete(nextAccount);
      await current;
      auth.signIns.first.complete(firstAccount);
      await staleError;
      expect(controller.status, AppSessionStatus.authenticated);
      expect(controller.session, nextAccount);
    },
  );

  test(
    'failed encrypted sign-out keeps the confirmed account and permits retry',
    () async {
      final signingIn = controller.signIn(
        email: 'one@example.test',
        password: 'fixture',
      );
      auth.signIns.single.complete(firstAccount);
      await signingIn;
      final failed = controller.signOut();
      final error = expectLater(failed, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      auth.signOuts.single.completeError(StateError('Storage failed'));
      await error;
      expect(controller.session, firstAccount);
      expect(controller.status, AppSessionStatus.authenticated);
      final retried = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      auth.signOuts.last.complete();
      await retried;
      expect(controller.session, isNull);
      expect(controller.status, AppSessionStatus.unauthenticated);
    },
  );
}
