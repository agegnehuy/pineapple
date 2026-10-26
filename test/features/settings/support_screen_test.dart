import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/support_screen.dart';

import '../../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());

  Future<void> show(
    WidgetTester tester, {
    bool french = false,
    double scale = 1,
    String? reference,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: Locale(french ? 'fr' : 'en'),
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
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: SupportScreen(
          repository: SettingsRepository(api),
          name: 'Fixture Student',
          email: 'student@example.test',
          reference: reference,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'help search filters real guidance and clearing restores answers',
    (tester) async {
      await show(tester);
      expect(find.text('Let’s work it out.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'allowance');
      await tester.pumpAndSettle();
      expect(find.text('How does AI allowance work?'), findsOneWidget);
      expect(find.text('How are matches chosen?'), findsNothing);
      await tester.tap(find.text('How does AI allowance work?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Review generated text before saving'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('How are matches chosen?'), findsOneWidget);
      expect(find.text('Where do I submit an application?'), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets('empty help search still leads to the existing contact form', (
    tester,
  ) async {
    await show(tester);
    await tester.enterText(find.byType(TextField), 'no-matching-topic');
    await tester.pumpAndSettle();
    expect(find.text('No matching answers'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Contact support'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.byType(DataFormScreen), findsOneWidget);
    expect(find.text('Fixture Student'), findsOneWidget);
    expect(find.text('student@example.test'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('report flow retains the content reference and explicit send', (
    tester,
  ) async {
    await show(tester, reference: 'post:fixture-1');
    expect(find.text('Search help'), findsNothing);
    await tester.tap(find.text('Report this content'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Please review this fixture content.',
    );
    expect(api.calls, isEmpty);
    await tester.ensureVisible(find.text('Send message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(api.calls.single.path, '/api/contact');
    expect(
      api.calls.single.body['message'],
      'Content reference: post:fixture-1\n\nPlease review this fixture content.',
    );
  });

  testWidgets(
    'French help fits a narrow screen with large text and no motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, french: true, scale: 2);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'quota');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Comment fonctionne le quota d’IA?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Comment fonctionne le quota d’IA?'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.calls, isEmpty);
    },
  );
}
