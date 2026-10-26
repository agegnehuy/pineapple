import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/privacy_account_screen.dart';
import 'package:myoccasio/features/settings/presentation/settings_screen.dart';

import '../../core/localization/app_localization_test.dart' show showFrench;
import '../../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());

  testWidgets('settings opens privacy hub and deletion requires typed review', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          repository: SettingsRepository(api),
          email: 'student@example.test',
          onSignOut: () async => signedOut = true,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Privacy & account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Privacy & account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy & account'));
    await tester.pumpAndSettle();
    expect(find.text('Your information. Your say.'), findsOneWidget);
    expect(find.text('Export my profile'), findsNothing);
    expect(find.text('Connected accounts'), findsNothing);
    expect(api.calls, isEmpty);
    await tester.scrollUntilVisible(
      find.text('Delete my account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(find.text('Type DELETE'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'other@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'DELETE');
    final submit = find.widgetWithText(FilledButton, 'Delete my account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(signedOut, isFalse);
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'delete');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(signedOut, isFalse);
    await tester.enterText(find.byType(TextFormField).last, 'DELETE');
    api.failure = const ApiException('Account deletion unavailable');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.calls.single.method, 'DELETE');
    expect(api.calls.single.path, '/api/me/account');
    expect(api.calls.single.body, {
      'confirmEmail': 'student@example.test',
      'confirmation': 'DELETE',
    });
    expect(signedOut, isFalse);
    expect(find.text('Account deletion unavailable'), findsWidgets);
    api.failure = null;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets(
    'privacy cards and delete review remain reachable in large French',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showFrench(
        tester,
        PrivacyAccountScreen(
          repository: SettingsRepository(api),
          email: 'student@example.test',
          onSignOut: () async {},
        ),
        scale: 2,
      );
      const strings = AppStrings('fr');
      for (final title in [
        'Privacy policy',
        'Terms of service',
        'Accessibility',
        'Delete my account',
      ]) {
        final target = find.text(strings.text(title));
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(api.calls, isEmpty);
    },
  );
}
