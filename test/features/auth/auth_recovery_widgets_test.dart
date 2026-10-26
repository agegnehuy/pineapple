import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/app.dart';
import 'package:myoccasio/app/app_dependencies.dart';
import 'package:myoccasio/app/config/app_config.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import 'package:myoccasio/features/auth/presentation/register_screen.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';

void main() {
  late ApiClient api;
  late _FixtureAuth auth;

  setUp(() {
    api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    auth = _FixtureAuth(api);
  });
  tearDown(() => api.close());

  testWidgets(
    'authentication forms can switch modes without stacking routes or posting credentials',
    (tester) async {
      await tester.pumpWidget(
        MyOccasioApp(
          dependencies: AppDependencies(
            config: AppConfig.fromValues(
              environmentValue: 'production',
              apiBaseUrl: 'https://example.test',
            ),
            auth: auth,
            profile: ProfileRepository(api),
            opportunities: OpportunitiesRepository(api),
            applications: ApplicationsRepository(api),
            academics: AcademicsRepository(api),
            coaching: CoachingRepository(api),
            community: CommunityRepository(api),
            settings: SettingsRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      final signInLink = find.text('Already a member? Sign in');
      await tester.ensureVisible(signInLink);
      await tester.tap(signInLink);
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      final registerLink = find.text('New to MyOccasio? Create account');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(auth.submissions, 0);
    },
  );

  testWidgets(
    'loading uses a static accessible indicator when reduced motion is enabled',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: AppLoadingView(label: 'Loading your profile…'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'late startup response after app disposal does not notify a disposed controller',
    (tester) async {
      final pending = Completer<AuthSession>();
      auth.restore = () => pending.future;
      final controller = AppSessionController(auth);
      final restoring = controller.initialize();
      controller.dispose();
      pending.complete(const AuthSession(user: null));
      await restoring;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup failure offers retry instead of silently signing out', (
    tester,
  ) async {
    var attempts = 0;
    auth.restore = () async {
      if (++attempts == 1) throw StateError('Fixture connection failure');
      return const AuthSession(user: null);
    };
    await tester.pumpWidget(
      MyOccasioApp(
        dependencies: AppDependencies(
          config: AppConfig.fromValues(
            environmentValue: 'production',
            apiBaseUrl: 'https://example.test',
          ),
          auth: auth,
          profile: ProfileRepository(api),
          opportunities: OpportunitiesRepository(api),
          applications: ApplicationsRepository(api),
          academics: AcademicsRepository(api),
          coaching: CoachingRepository(api),
          community: CommunityRepository(api),
          settings: SettingsRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('We couldn’t restore your session'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Get started'), findsOneWidget);
  });

  for (final registration in [false, true]) {
    testWidgets(
      '${registration ? 'registration' : 'sign-in'} ignores repeated keyboard submission',
      (tester) async {
        final pending = Completer<AuthSession>();
        auth.submit = () => pending.future;
        final controller = AppSessionController(auth);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => registration
                          ? RegisterScreen(sessionController: controller)
                          : SignInScreen(sessionController: controller),
                    ),
                  ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        var index = 0;
        if (registration) {
          await tester.enterText(fields.at(index++), 'Fixture Student');
        }
        await tester.enterText(fields.at(index++), 'fixture@example.test');
        await tester.ensureVisible(fields.at(index));
        await tester.enterText(fields.at(index), 'fixture-only');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(auth.submissions, 1);

        pending.complete(
          const AuthSession(user: {'email': 'fixture@example.test'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open form'), findsOneWidget);
      },
    );
  }

  testWidgets('retry remains reachable in a small viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AppErrorView(
            title: 'Could not restore your session',
            message: 'Check your connection and try again.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}

class _FixtureAuth extends AuthRepository {
  _FixtureAuth(ApiClient api) : super(api, MemoryCookieStore());

  Future<AuthSession> Function() restore = () async =>
      const AuthSession(user: null);
  Future<AuthSession> Function() submit = () async =>
      const AuthSession(user: null);
  int submissions = 0;

  @override
  Future<AuthSession> currentSession() => restore();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    submissions++;
    return submit();
  }

  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    submissions++;
    return submit();
  }
}
