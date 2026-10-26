import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/settings_screen.dart';

import '../../core/localization/app_localization_test.dart' show showFrench;
import '../../support/recording_api.dart';

const preferences = {
  'matches': true,
  'deadlines': true,
  'applications': true,
  'community': false,
  'weeklyRoundup': true,
};

Finder preference(String label) => find.widgetWithText(SwitchListTile, label);

Future<void> openPreferences(
  WidgetTester tester,
  SettingsRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NotificationPreferencesScreen(repository: repository),
              ),
            ),
            child: const Text('Open preferences'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preferences'));
  await tester.pumpAndSettle();
}

void main() {
  late RecordingApi api;
  setUp(() {
    api = RecordingApi();
    api.responses['/api/me/notifications'] = preferences;
  });
  tearDown(() => api.close());

  testWidgets(
    'failed preference write preserves the value and can be retried',
    (tester) async {
      await openPreferences(tester, SettingsRepository(api));
      expect(find.text('Only the right nudges.'), findsOneWidget);
      expect(
        find.ancestor(
          of: preference('New matches'),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );
      api.failure = const ApiException('Preference service offline');
      await tester.tap(find.text('New matches'));
      await tester.pumpAndSettle();
      expect(find.text('Preference service offline'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(preference('New matches')).value,
        isTrue,
      );
      expect(api.calls.last.body, {'matches': false});
      api.failure = null;
      api.responses['/api/me/notifications'] = {
        ...preferences,
        'matches': false,
      };
      await tester.tap(find.text('New matches'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(preference('New matches')).value,
        isFalse,
      );
    },
  );

  testWidgets(
    'pending preference write blocks Back but its refresh allows exit',
    (tester) async {
      final repository = DeferredPreferences(api);
      await openPreferences(tester, repository);
      final change = tester
          .widget<SwitchListTile>(preference('New matches'))
          .onChanged!;
      change(false);
      change(false);
      await tester.pump();
      expect(repository.writes, [
        {'matches': false},
      ]);
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Only the right nudges.'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(preference('New matches')).value,
        isTrue,
      );
      repository.write.complete();
      await tester.pump();
      await tester.pump();
      expect(repository.reads, 2);
      expect(
        tester.widget<SwitchListTile>(preference('New matches')).value,
        isFalse,
      );
      expect(
        tester.widget<SwitchListTile>(preference('New matches')).onChanged,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open preferences'), findsOneWidget);
      repository.refresh.complete({...preferences, 'matches': false});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed follow-up read keeps the confirmed preference value', (
    tester,
  ) async {
    final repository = DeferredPreferences(api);
    repository.write.complete();
    await openPreferences(tester, repository);
    await tester.tap(find.text('New matches'));
    await tester.pump();
    repository.refresh.completeError(const ApiException('Read offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Refresh failed. Showing the last loaded information.'),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(preference('New matches')).value,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(preference('New matches')).onChanged,
      isNotNull,
    );
    expect(repository.writes, [
      {'matches': false},
    ]);
  });

  testWidgets('all preference cards and account notice fit large French text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showFrench(
      tester,
      NotificationPreferencesScreen(repository: SettingsRepository(api)),
      scale: 2,
    );
    const strings = AppStrings('fr');
    for (final label in [
      'New matches',
      'Deadline reminders',
      'Application updates',
      'Community activity',
      'Weekly roundup',
    ]) {
      final card = preference(strings.text(label));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(
      find.text(
        strings.text(
          'These preferences apply to your MyOccasio account. Device push notifications are separate.',
        ),
      ),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets('recent activity keeps original records and opens preferences', (
    tester,
  ) async {
    api.responses['/api/activity'] = [
      {'title': 'Settings', 'subtitle': 'Original account activity'},
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ActivityScreen(repository: SettingsRepository(api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A little heads-up.'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Original account activity'), findsOneWidget);
    expect(find.text('Mark read'), findsNothing);
    await tester.tap(find.text('Manage notification preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Only the right nudges.'), findsOneWidget);
    expect(api.calls.map((call) => call.path), [
      '/api/activity',
      '/api/me/notifications',
    ]);
  });
}

class DeferredPreferences extends SettingsRepository {
  DeferredPreferences(super.api);
  final write = Completer<void>();
  final refresh = Completer<Map<String, dynamic>>();
  final writes = <Map<String, bool>>[];
  int reads = 0;

  @override
  Future<Map<String, dynamic>> notifications() async =>
      ++reads == 1 ? {...preferences} : refresh.future;

  @override
  Future<void> updateNotifications(Map<String, bool> values) {
    writes.add(values);
    return write.future;
  }
}
