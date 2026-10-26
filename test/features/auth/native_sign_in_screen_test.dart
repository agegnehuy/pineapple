import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/auth/data/native_auth_repository.dart';
import 'package:myoccasio/features/auth/data/system_auth_browser.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import 'package:myoccasio/features/auth/presentation/register_screen.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';
import '../../support/deferred_auth_repository.dart';
import '../../support/recording_api.dart';
import '../../core/localization/app_localization_test.dart' show showFrench;

class _NativeAuth extends NativeAuthRepository {
  _NativeAuth(RecordingApi api, DeferredAuthRepository auth)
    : super(
        api: api,
        auth: auth,
        cookies: MemoryCookieStore(),
        baseUri: Uri.parse('https://example.test'),
      );
  bool available = true;
  int availabilityCalls = 0;
  Completer<bool>? availabilityGate;
  int calls = 0;
  int cancelCalls = 0;
  Completer<AuthSession>? _attempt;
  Completer<AuthSession> get attempt => _attempt!;
  bool failCancel = false;
  bool completeOnCancel = true;
  bool retainCleanup = false;
  bool _pending = false;
  @override
  Future<bool> googleAvailable() async {
    availabilityCalls++;
    return availabilityGate == null
        ? available
        : await availabilityGate!.future;
  }

  @override
  Future<AuthSession> signIn() async {
    calls++;
    _pending = true;
    final operation = Completer<AuthSession>();
    _attempt = operation;
    try {
      return await operation.future;
    } finally {
      if (!retainCleanup) _pending = false;
    }
  }

  @override
  bool get pending => _pending;
  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (failCancel) throw StateError('Fixture encrypted storage unavailable');
    retainCleanup = false;
    _pending = false;
    if (completeOnCancel) {
      if (_attempt case final operation? when !operation.isCompleted) {
        operation.completeError(const NativeAuthCancelled());
      }
    }
  }
}

void main() {
  late DeferredAuthRepository auth;
  late _NativeAuth native;
  late AppSessionController controller;
  setUp(() {
    final api = RecordingApi();
    auth = DeferredAuthRepository(api);
    native = _NativeAuth(api, auth);
    controller = AppSessionController(auth, nativeAuth: native);
    controller.status = AppSessionStatus.unauthenticated;
  });
  tearDown(() => controller.dispose());

  // Active browser/capability states contain an indeterminate progress
  // indicator. Advance transitions without waiting for that animation to end.
  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final registering in [false, true]) {
    final mode = registering ? 'registration' : 'sign-in';
    const googleLabel = 'Continue with Google';
    final emailLabel = registering ? 'Create account' : 'Sign in';
    final screenType = registering ? RegisterScreen : SignInScreen;
    Widget screen() => registering
        ? RegisterScreen(sessionController: controller, onSignIn: () {})
        : SignInScreen(
            sessionController: controller,
            onCreateAccount: () {},
            onForgotPassword: () {},
          );

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => screen()),
                ),
                child: const Text('Open sign-in'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sign-in'));
      await pumpUi(tester);
    }

    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await pumpUi(tester);
      await tester.ensureVisible(finder);
      await pumpUi(tester);
    }

    testWidgets('$mode shows unavailable Google and allows capability retry', (
      tester,
    ) async {
      native.available = false;
      await open(tester);
      expect(find.text(googleLabel), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, googleLabel),
            )
            .onPressed,
        isNotNull,
      );
      await reveal(tester, find.text(googleLabel));
      await tester.tap(find.text(googleLabel));
      await pumpUi(tester);
      expect(
        find.text(
          'Google is not available right now. Continue with email or try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNWidgets(registering ? 3 : 2));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, emailLabel))
            .onPressed,
        isNotNull,
      );
      expect(native.calls, 0);
      native.available = true;
      const retry = 'Try again';
      await reveal(tester, find.text(retry));
      await tester.tap(find.text(retry));
      await pumpUi(tester);
      expect(native.availabilityCalls, 2);
      expect(native.calls, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, googleLabel),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      '$mode Google locks duplicate actions and supports explicit cancellation',
      (tester) async {
        await open(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        expect(native.calls, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .every((field) => field.enabled == false),
          isTrue,
        );
        await tester.binding.handlePopRoute();
        await pumpUi(tester);
        expect(find.byType(screenType), findsOneWidget);
        await reveal(tester, find.text('Cancel sign-in'));
        await tester.tap(find.text('Cancel sign-in'));
        await pumpUi(tester);
        expect(native.cancelCalls, 1);
        expect(find.text(googleLabel), findsOneWidget);
        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('$mode provider failure retains inputs and supports retry', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byType(TextFormField).at(registering ? 1 : 0),
        'fixture@example.test',
      );
      if (registering) {
        await tester.enterText(find.byType(TextFormField).at(0), 'One Student');
      }
      await reveal(tester, find.text(googleLabel));
      await tester.tap(find.text(googleLabel));
      await pumpUi(tester);
      native.attempt.completeError(
        const ApiException('Google sign-in did not finish. Please try again.'),
      );
      await pumpUi(tester);
      expect(
        find.text('Google sign-in did not finish. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('fixture@example.test'), findsOneWidget);
      if (registering) {
        expect(find.text('One Student'), findsOneWidget);
      }
      expect(controller.session, isNull);
      await reveal(tester, find.text(googleLabel));
      await tester.tap(find.text(googleLabel));
      await pumpUi(tester);
      expect(native.calls, 2);
      native.attempt.completeError(const NativeAuthCancelled());
      await pumpUi(tester);
      expect(
        find.text('Google sign-in did not finish. Please try again.'),
        findsNothing,
      );
    });

    testWidgets(
      '$mode failed cancellation keeps authentication locked until cleanup retry',
      (tester) async {
        await open(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        native.failCancel = true;
        await reveal(tester, find.text('Cancel sign-in'));
        await tester.tap(find.text('Cancel sign-in'));
        await pumpUi(tester);
        expect(
          find.text('Could not cancel sign-in. Please try again.'),
          findsOneWidget,
        );
        await expectLater(
          controller.signIn(
            email: 'fixture@example.test',
            password: 'fixture-only',
          ),
          throwsA(isA<ApiException>()),
        );
        native.failCancel = false;
        await tester.tap(find.text('Cancel sign-in'));
        await pumpUi(tester);
        expect(find.text(googleLabel), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      '$mode ignores a late Google result after explicit cancellation',
      (tester) async {
        await open(tester);
        native.completeOnCancel = false;
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        await reveal(tester, find.text('Cancel sign-in'));
        await tester.tap(find.text('Cancel sign-in'));
        await pumpUi(tester);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNotNull,
        );
        native.attempt.complete(
          const AuthSession(
            user: {
              'id': 'cancelled-fixture-user',
              'email': 'cancelled@example.test',
            },
          ),
        );
        await pumpUi(tester);
        expect(find.byType(screenType), findsOneWidget);
        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(controller.session, isNull);
        expect(
          find.text('Your session changed. Please try again.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$mode Google success restores a session without credential validation',
      (tester) async {
        await open(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        expect(native.calls, 1);
        // Google supplies identity and creates new accounts through the same
        // backend flow. Empty local fields must not trigger email registration.
        expect(auth.registrations, isEmpty);
        expect(auth.signIns, isEmpty);
        native.attempt.complete(
          const AuthSession(
            user: {
              'id': 'google-fixture-user',
              'firstName': 'Student',
              'email': 'fixture@example.test',
            },
          ),
        );
        await pumpUi(tester);
        expect(find.byType(screenType), findsNothing);
        expect(find.text('Open sign-in'), findsOneWidget);
        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.email, 'fixture@example.test');
      },
    );

    testWidgets(
      '$mode capability retry stays disabled while checking and preserves email',
      (tester) async {
        native.available = false;
        await open(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        native.availabilityGate = Completer<bool>();
        const retry = 'Try again';
        await reveal(tester, find.text(retry));
        await tester.tap(find.text(retry));
        await tester.pump();
        expect(native.availabilityCalls, 2);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, googleLabel),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .every((field) => field.enabled == true),
          isTrue,
        );
        native.availabilityGate!.complete(true);
        await pumpUi(tester);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, googleLabel),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      '$mode provider cleanup failure keeps cancel reachable until recovery',
      (tester) async {
        await open(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        native.retainCleanup = true;
        native.attempt.completeError(
          StateError('Fixture encrypted cleanup failed'),
        );
        await pumpUi(tester);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .every((field) => field.enabled == false),
          isTrue,
        );
        await reveal(tester, find.text('Cancel sign-in'));
        await tester.tap(find.text('Cancel sign-in'));
        await pumpUi(tester);
        expect(native.pending, isFalse);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, emailLabel),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      '$mode delayed Google capability retry does not cover the next route',
      (tester) async {
        native.available = false;
        final navigation = GlobalKey<NavigatorState>();
        void nextRoute() => navigation.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Next route fixture')),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigation,
            theme: AppTheme.light,
            home: registering
                ? RegisterScreen(
                    sessionController: controller,
                    onSignIn: nextRoute,
                  )
                : SignInScreen(
                    sessionController: controller,
                    onForgotPassword: nextRoute,
                  ),
          ),
        );
        await pumpUi(tester);
        await reveal(tester, find.text(googleLabel));
        await tester.tap(find.text(googleLabel));
        await pumpUi(tester);
        native.availabilityGate = Completer<bool>();
        await tester.tap(find.text('Try again'));
        await pumpUi(tester);
        final next = registering
            ? 'Already a member? Sign in'
            : 'Forgot password?';
        await reveal(tester, find.text(next));
        await tester.tap(find.text(next));
        await pumpUi(tester);
        expect(find.text('Next route fixture'), findsOneWidget);
        native.availabilityGate!.complete(false);
        await pumpUi(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Next route fixture'), findsOneWidget);
        expect(native.calls, 0);
        expect(controller.session, isNull);
      },
    );

    testWidgets(
      '$mode email submission locks Google, inputs, and password visibility',
      (tester) async {
        await open(tester);
        final fields = find.byType(TextFormField);
        if (registering) {
          await tester.enterText(fields.at(0), 'One Student');
        }
        await tester.enterText(
          fields.at(registering ? 1 : 0),
          'fixture@example.test',
        );
        await tester.enterText(fields.at(registering ? 2 : 1), 'fixture-only');
        final button = find.widgetWithText(FilledButton, emailLabel);
        await reveal(tester, button);
        await tester.tap(button);
        await tester.pump();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, googleLabel),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .every((field) => field.enabled == false),
          isTrue,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Show password',
                ),
              )
              .onPressed,
          isNull,
        );
        if (registering) {
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(
                    TextButton,
                    'By continuing, you agree to our Terms of service and Privacy policy.',
                  ),
                )
                .onPressed,
            isNull,
          );
        }
        final operation = registering
            ? auth.registrations.single
            : auth.signIns.single;
        operation.completeError(const ApiException('Please try again.'));
        await pumpUi(tester);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, googleLabel),
              )
              .onPressed,
          isNotNull,
        );
        expect(native.calls, 0);
      },
    );

    testWidgets(
      '$mode French provider control remains reachable at 200% in short landscape',
      (tester) async {
        tester.view.physicalSize = const Size(568, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await showFrench(tester, screen(), scale: 2);
        const label = 'Continuer avec Google';
        await reveal(tester, find.text(label));
        expect(
          tester.getSize(find.widgetWithText(OutlinedButton, label)).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
