import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import 'package:myoccasio/features/auth/presentation/register_screen.dart';

import '../../support/deferred_auth_repository.dart';
import '../../support/recording_api.dart';

class _RegistrationAuth extends DeferredAuthRepository {
  _RegistrationAuth(super.api);

  final payloads = <Map<String, String>>[];

  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    payloads.add({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
    });
    return super.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}

Finder _field(String name) => find.byKey(ValueKey('register-$name'));

const _consent =
    'By continuing, you agree to our Terms of service and Privacy policy.';

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
  late _RegistrationAuth auth;
  late AppSessionController controller;

  setUp(() {
    api = RecordingApi();
    auth = _RegistrationAuth(api);
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
    VoidCallback? signIn,
    bool pushed = false,
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
    Widget screen() => RegisterScreen(
      sessionController: controller,
      onSignIn: signIn ?? () {},
    );
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
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => screen()),
                    ),
                    child: const Text('Open registration fixture'),
                  ),
                ),
              )
            : screen(),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('Open registration fixture'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, {String name = 'Amara Khan'}) async {
    for (final entry in {
      'name': name,
      'email': 'fixture@example.test',
      'password': 'fixture-only',
    }.entries) {
      final field = _field(entry.key);
      await _reveal(tester, field);
      await tester.enterText(field, entry.value);
    }
  }

  Future<void> submit(WidgetTester tester) async {
    final button = _field('submit');
    await _reveal(tester, button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets(
    'reference phone presents the full-name form without prefilling identity',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        const viewport = Size(390, 844);
        await open(tester);
        expect(find.text('MyOccasio'), findsOneWidget);
        expect(find.text('A little closer.'), findsOneWidget);
        expect(
          find.text('Create your free MyOccasio account.'),
          findsOneWidget,
        );
        expect(find.text('FULL NAME'), findsOneWidget);
        expect(find.text('EMAIL ADDRESS'), findsOneWidget);
        expect(find.text('PASSWORD'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(3));
        for (final entry in {
          'name': 'Amara Khan',
          'email': 'amara@university.ca',
          'password': 'Create a strong password',
        }.entries) {
          final field = tester.widget<TextFormField>(_field(entry.key));
          expect(field.controller!.text, isEmpty);
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: _field(entry.key),
                    matching: find.byType(TextField),
                  ),
                )
                .decoration!
                .hintText,
            entry.value,
          );
          _expectVisible(tester, _field(entry.key), viewport);
        }
        for (final label in ['Continue with Apple', 'Continue with Google']) {
          final provider = _button(label);
          _expectVisible(tester, provider, viewport);
          _expectAction(tester, provider, label);
        }
        for (final label in ['Create account', 'Already a member? Sign in']) {
          final action = _button(label);
          _expectVisible(tester, action, viewport);
          _expectAction(tester, action, label);
        }
        final fullName = tester.widget<TextField>(
          find.descendant(of: _field('name'), matching: find.byType(TextField)),
        );
        expect(fullName.autofillHints, contains(AutofillHints.name));
        expect(fullName.textCapitalization, TextCapitalization.words);
        expect(auth.payloads, isEmpty);
        expect(api.calls, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final name in [
    (input: '  Amara   Noor   Khan  ', first: 'Amara', last: 'Noor Khan'),
    (input: '  Élodie   de la Cruz ', first: 'Élodie', last: 'de la Cruz'),
    (input: '李 小龍', first: '李', last: '小龍'),
    (input: '  Madonna  ', first: 'Madonna', last: ''),
  ]) {
    testWidgets(
      'full name ${name.input} retains the existing registration contract',
      (tester) async {
        await open(tester, pushed: true);
        await fill(tester, name: name.input);
        await submit(tester);
        expect(auth.payloads, [
          {
            'firstName': name.first,
            'lastName': name.last,
            'email': 'fixture@example.test',
            'password': 'fixture-only',
          },
        ]);
        auth.registrations.single.complete(
          const AuthSession(user: {'email': 'fixture@example.test'}),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RegisterScreen), findsNothing);
        expect(find.text('Open registration fixture'), findsOneWidget);
        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.email, 'fixture@example.test');
      },
    );
  }

  testWidgets(
    'validation and failed registration preserve values and allow a retry',
    (tester) async {
      await open(tester, pushed: true);
      await fill(tester, name: '  ');
      await tester.enterText(_field('email'), 'invalid');
      await _reveal(tester, _field('password'));
      await tester.enterText(_field('password'), 'short');
      await _tap(tester, 'Create account');
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(auth.payloads, isEmpty);
      expect(
        tester.widget<TextFormField>(_field('email')).controller!.text,
        'invalid',
      );
      expect(
        tester.widget<TextFormField>(_field('password')).controller!.text,
        'short',
      );
      await fill(tester);
      await submit(tester);
      auth.registrations.single.completeError(
        const ApiException('Fixture registration failure', statusCode: 409),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fixture registration failure'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(_field('name')).controller!.text,
        'Amara Khan',
      );
      expect(
        tester.widget<TextFormField>(_field('email')).controller!.text,
        'fixture@example.test',
      );
      expect(
        tester.widget<TextFormField>(_field('password')).controller!.text,
        'fixture-only',
      );
      expect(controller.status, AppSessionStatus.unauthenticated);
      await submit(tester);
      expect(auth.registrations, hasLength(2));
      auth.registrations.last.complete(
        const AuthSession(user: {'email': 'fixture@example.test'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open registration fixture'), findsOneWidget);
      expect(controller.status, AppSessionStatus.authenticated);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('password visibility preserves the entered password', (
    tester,
  ) async {
    await open(tester);
    final field = _field('password');
    await _reveal(tester, field);
    await tester.enterText(field, 'fixture-only');
    TextField password() => tester.widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    );
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(password().obscureText, isFalse);
    expect(password().controller!.text, 'fixture-only');
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(password().obscureText, isTrue);
    expect(password().controller!.text, 'fixture-only');
    expect(auth.payloads, isEmpty);
  });

  testWidgets('sign-in navigation preserves the existing callback', (
    tester,
  ) async {
    var navigations = 0;
    await open(tester, signIn: () => navigations++);
    await _tap(tester, 'Already a member? Sign in');
    expect(navigations, 1);
    expect(auth.payloads, isEmpty);
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'Apple explains its unavailable status without creating an account',
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
      expect(auth.payloads, isEmpty);
      expect(api.calls, isEmpty);
      await _tap(tester, 'Use email');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RegisterScreen), findsOneWidget);
    },
  );

  testWidgets('consent controls open the actual terms and privacy pages', (
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
      final consent = _button(_consent);
      expect(tester.getSize(consent).height, greaterThanOrEqualTo(48));
      await _tap(tester, _consent);
      for (final label in ['Terms of service', 'Privacy policy']) {
        final action = _button(label);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        await _tap(tester, label);
      }
      final launched = calls.where((call) => call.method == 'launch').toList();
      expect(launched, hasLength(2));
      expect(launched.map((call) => (call.arguments as Map)['url']), [
        'https://myoccasio.ca/terms',
        'https://myoccasio.ca/privacy',
      ]);
      expect(
        launched.every(
          (call) => (call.arguments as Map)['useWebView'] == false,
        ),
        isTrue,
      );
      expect(auth.payloads, isEmpty);
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
      'registration actions remain reachable at ${configuration.viewport} ${configuration.scale}x ${configuration.language}',
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
          final strings = AppStrings(configuration.language);
          for (final source in [
            'Continue with Apple',
            'Continue with Google',
            _consent,
            'Create account',
            'Already a member? Sign in',
          ]) {
            final label = strings.text(source);
            final action = _button(label);
            await _reveal(tester, action);
            _expectVisible(tester, action, configuration.viewport);
            _expectAction(tester, action, label);
            expect(tester.takeException(), isNull);
          }
          await _tap(tester, strings.text(_consent));
          for (final source in ['Terms of service', 'Privacy policy']) {
            final label = strings.text(source);
            final action = _button(label);
            await _reveal(tester, action);
            _expectVisible(tester, action, configuration.viewport);
            _expectAction(tester, action, label);
          }
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          for (final name in ['name', 'email', 'password']) {
            await _reveal(tester, _field(name));
            _expectVisible(tester, _field(name), configuration.viewport);
          }
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
          expect(auth.payloads, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
