import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/auth/presentation/welcome_screen.dart';

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void _expectVisibleTarget(WidgetTester tester, Finder button, Size viewport) {
  final rect = tester.getRect(button);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewport.width));
  expect(rect.bottom, lessThanOrEqualTo(viewport.height));
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(button.hitTestable(), findsOneWidget);
}

void _expectButtonSemantics(WidgetTester tester, Finder button, String label) {
  final data = tester.getSemantics(button).getSemanticsData();
  expect(data.label, contains(label));
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
}

Future<void> _pumpWelcome(
  WidgetTester tester, {
  required Size viewport,
  required VoidCallback onSignIn,
  required VoidCallback onCreateAccount,
  double textScale = 1,
  bool reducedMotion = false,
  String language = 'en',
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
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          padding: viewport == const Size(390, 844)
              ? const EdgeInsets.only(top: 44, bottom: 34)
              : EdgeInsets.zero,
        ),
        child: child!,
      ),
      home: WelcomeScreen(onSignIn: onSignIn, onCreateAccount: onCreateAccount),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'standard phone shows both accessible authentication actions without scrolling',
    (tester) async {
      const viewport = Size(390, 844);
      final semantics = tester.ensureSemantics();
      try {
        var signedIn = 0;
        var registered = 0;
        await _pumpWelcome(
          tester,
          viewport: viewport,
          onSignIn: () => signedIn++,
          onCreateAccount: () => registered++,
        );
        expect(tester.takeException(), isNull);
        for (final label in ['Get started', 'Already a member? Sign in']) {
          final button = _button(label);
          expect(button, findsOneWidget);
          _expectVisibleTarget(tester, button, viewport);
          _expectButtonSemantics(tester, button, label);
        }
        for (final scrollable in tester.stateList<ScrollableState>(
          find.byType(Scrollable),
        )) {
          expect(scrollable.position.maxScrollExtent, lessThanOrEqualTo(1));
          expect(scrollable.position.pixels, 0);
        }
        await tester.tap(_button('Get started'));
        await tester.pumpAndSettle();
        expect(registered, 1);
        expect(signedIn, 0);
        await tester.tap(_button('Already a member? Sign in'));
        await tester.pumpAndSettle();
        expect(signedIn, 1);
        expect(registered, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final language in ['en', 'fr']) {
    testWidgets(
      '$language welcome keeps both actions reachable at 320px and 200 percent text',
      (tester) async {
        const viewport = Size(320, 725);
        final semantics = tester.ensureSemantics();
        try {
          var signedIn = 0;
          var registered = 0;
          await _pumpWelcome(
            tester,
            viewport: viewport,
            language: language,
            textScale: 2,
            reducedMotion: true,
            onSignIn: () => signedIn++,
            onCreateAccount: () => registered++,
          );
          expect(tester.takeException(), isNull);
          for (final source in ['Get started', 'Already a member? Sign in']) {
            final label = AppStrings(language).text(source);
            final button = _button(label);
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            _expectVisibleTarget(tester, button, viewport);
            _expectButtonSemantics(tester, button, label);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(registered, 1);
          expect(signedIn, 1);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'short landscape keeps semantic authentication actions reachable with reduced motion',
    (tester) async {
      const viewport = Size(844, 320);
      final semantics = tester.ensureSemantics();
      try {
        var signedIn = 0;
        var registered = 0;
        await _pumpWelcome(
          tester,
          viewport: viewport,
          reducedMotion: true,
          onSignIn: () => signedIn++,
          onCreateAccount: () => registered++,
        );
        expect(tester.takeException(), isNull);
        for (final label in ['Get started', 'Already a member? Sign in']) {
          final button = _button(label);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          _expectVisibleTarget(tester, button, viewport);
          _expectButtonSemantics(tester, button, label);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(registered, 1);
        expect(signedIn, 1);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        semantics.dispose();
      }
    },
  );
}
