import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';

import '../../support/deferred_auth_repository.dart';
import '../../support/recording_api.dart';

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = _button(label);
  await _reveal(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void _expectVisible(WidgetTester tester, Finder finder, Size viewport) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewport.width));
  expect(rect.bottom, lessThanOrEqualTo(viewport.height));
}

void _expectAction(WidgetTester tester, Finder finder, String label) {
  final data = tester.getSemantics(finder).getSemanticsData();
  expect(data.label, contains(label));
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
}

void main() {
  late RecordingApi api;
  late DeferredAuthRepository auth;
  late AppSessionController controller;

  setUp(() {
    api = RecordingApi();
    auth = DeferredAuthRepository(api);
    controller = AppSessionController(auth)
      ..status = AppSessionStatus.unauthenticated;
  });
  tearDown(() {
    controller.dispose();
    api.close();
  });

  Future<void> open(
    WidgetTester tester, {
    Size viewport = const Size(390, 844),
    double scale = 1,
    String language = 'en',
    bool reducedMotion = false,
    VoidCallback? createAccount,
    VoidCallback? recovery,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final family in ['InstrumentSans', 'Newsreader']) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
        await loader.load();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
            padding: viewport == const Size(390, 844)
                ? const EdgeInsets.only(top: 44, bottom: 34)
                : EdgeInsets.zero,
          ),
          child: child!,
        ),
        home: SignInScreen(
          sessionController: controller,
          onCreateAccount: createAccount ?? () {},
          onForgotPassword: recovery ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reference phone exposes both providers and labeled email form', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      const viewport = Size(390, 844);
      await open(tester);
      expect(find.text('MyOccasio'), findsOneWidget);
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('you@university.ca'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      for (final label in ['Continue with Google', 'Continue with Apple']) {
        final provider = _button(label);
        expect(provider, findsOneWidget);
        _expectVisible(tester, provider, viewport);
        final data = tester.getSemantics(provider).getSemanticsData();
        expect(data.label, contains(label));
        expect(data.flagsCollection.isButton, isTrue);
        expect(tester.getSize(provider).height, greaterThanOrEqualTo(48));
      }
      expect(
        find.bySemanticsLabel(RegExp('Email address', caseSensitive: false)),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp('Password', caseSensitive: false)),
        findsWidgets,
      );
      _expectAction(tester, _button('Sign in'), 'Sign in');
      expect(auth.signIns, isEmpty);
      expect(auth.registrations, isEmpty);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'recovery and create-account links retain their navigation flows',
    (tester) async {
      var recovery = 0;
      var createAccount = 0;
      await open(
        tester,
        recovery: () => recovery++,
        createAccount: () => createAccount++,
      );
      await _tap(tester, 'Forgot password?');
      expect(recovery, 1);
      expect(createAccount, 0);
      await _tap(tester, 'New to MyOccasio? Create account');
      expect(createAccount, 1);
      expect(recovery, 1);
      expect(auth.signIns, isEmpty);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'password visibility toggles without replacing the entered value',
    (tester) async {
      await open(tester);
      final password = find.byType(TextFormField).last;
      await _reveal(tester, password);
      await tester.enterText(password, 'fixture-only');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .obscureText,
        isFalse,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(password).controller!.text,
        'fixture-only',
      );
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .obscureText,
        isTrue,
      );
      expect(
        tester.widget<TextFormField>(password).controller!.text,
        'fixture-only',
      );
      expect(auth.signIns, isEmpty);
    },
  );

  testWidgets(
    'email validation and failed sign-in preserve entered credentials',
    (tester) async {
      await open(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'invalid');
      await tester.enterText(fields.last, 'fixture-only');
      await _tap(tester, 'Sign in');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.signIns, isEmpty);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'invalid',
      );
      await tester.enterText(fields.first, 'fixture@example.test');
      final submit = _button('Sign in');
      await _reveal(tester, submit);
      await tester.tap(submit);
      await tester.pump();
      expect(auth.signIns, hasLength(1));
      auth.signIns.single.completeError(
        const ApiException('Fixture sign-in failure', statusCode: 401),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fixture sign-in failure'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'fixture@example.test',
      );
      expect(
        tester.widget<TextFormField>(fields.last).controller!.text,
        'fixture-only',
      );
      expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Apple explains unsupported authentication without an API request',
    (tester) async {
      await open(tester);
      await _tap(tester, 'Continue with Apple');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Apple sign-in unavailable'), findsOneWidget);
      expect(
        find.text(
          'Apple sign-in is not available yet. Please use your email and password.',
        ),
        findsOneWidget,
      );
      expect(auth.signIns, isEmpty);
      expect(auth.registrations, isEmpty);
      expect(api.calls, isEmpty);
      await _tap(tester, 'Use email');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
    },
  );

  testWidgets('legal footer opens the actual privacy and terms pages', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    try {
      await open(tester);
      for (final label in ['Privacy policy', 'Terms of service']) {
        await _tap(tester, label);
      }
      final launched = calls.where((call) => call.method == 'launch').toList();
      expect(launched, hasLength(2));
      expect(launched.map((call) => (call.arguments as Map)['url']), [
        'https://myoccasio.ca/privacy',
        'https://myoccasio.ca/terms',
      ]);
      expect(
        launched.every(
          (call) => (call.arguments as Map)['useWebView'] == false,
        ),
        isTrue,
      );
      expect(auth.signIns, isEmpty);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
  for (final configuration in [
    (viewport: Size(320, 725), scale: 2.0, language: 'fr'),
    (viewport: Size(844, 320), scale: 1.0, language: 'en'),
  ]) {
    testWidgets(
      'sign-in actions remain reachable at ${configuration.viewport} ${configuration.scale}x ${configuration.language}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await open(
            tester,
            viewport: configuration.viewport,
            scale: configuration.scale,
            language: configuration.language,
            reducedMotion: true,
          );
          expect(tester.takeException(), isNull);
          final strings = AppStrings(configuration.language);
          for (final source in [
            'Continue with Google',
            'Continue with Apple',
            'Forgot password?',
            'Sign in',
            'New to MyOccasio? Create account',
            'Privacy policy',
            'Terms of service',
          ]) {
            final label = strings.text(source);
            final action = _button(label);
            await _reveal(tester, action);
            _expectVisible(tester, action, configuration.viewport);
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            if (source != 'Continue with Google') {
              _expectAction(tester, action, label);
            }
            expect(tester.takeException(), isNull);
          }
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
