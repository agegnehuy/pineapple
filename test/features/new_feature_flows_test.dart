import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/presentation/password_recovery_screen.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/application_workspace_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/presentation/academics_screen.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/community/presentation/community_screen.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/settings_screen.dart';
import '../support/recording_api.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> show(
  WidgetTester tester,
  Widget screen, {
  bool scaffold = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: scaffold ? Scaffold(body: screen) : screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  testWidgets(
    'recovery validates and shows confirmation only after server success',
    (tester) async {
      await show(
        tester,
        PasswordRecoveryScreen(
          repository: AuthRepository(api, MemoryCookieStore()),
        ),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        'student@example.test',
      );
      api.failure = const ApiException('Service unavailable');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Reset link requested'), findsNothing);
      api.failure = null;
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Reset link requested'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );
  testWidgets(
    'editor preserves draft after failure and blocks losing unsaved data',
    (tester) async {
      var writes = 0;
      await show(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DataFormScreen(
                    title: 'Edit goal',
                    fields: const [DataField('title', 'Title', required: true)],
                    save: (v) async {
                      writes++;
                      throw const ApiException('Offline');
                    },
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Title'), 'My goal');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('My goal'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('My goal'), findsOneWidget);
    },
  );
  testWidgets('editor ignores duplicate save while awaiting confirmation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var writes = 0;
    await show(
      tester,
      DataFormScreen(
        title: 'Edit',
        fields: const [DataField('title', 'Title')],
        save: (v) {
          writes++;
          return pending.future;
        },
      ),
    );
    await tester.enterText(field('Title'), 'Value');
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    expect(writes, 1);
    pending.completeError(const ApiException('Fixture offline'));
    await tester.pumpAndSettle();
    expect(find.text('Value'), findsOneWidget);
  });
  testWidgets('refresh failure keeps last loaded data and exposes retry', (
    tester,
  ) async {
    var fail = false;
    await show(
      tester,
      AsyncContent<String>(
        load: () async {
          if (fail) throw const ApiException('Offline');
          return 'Saved content';
        },
        builder: (context, data, refresh) => ListView(
          children: [
            Text(data),
            TextButton(onPressed: refresh, child: const Text('Refresh')),
          ],
        ),
      ),
      scaffold: true,
    );
    fail = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Saved content'), findsOneWidget);
    expect(
      find.text('Refresh failed. Showing the last loaded information.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Refresh failed. Showing the last loaded information.'),
      findsNothing,
    );
  });
  Map<String, dynamic> workspace({bool internal = true}) => {
    'opportunity': {
      'title': 'Real contract fixture',
      'provider': 'Test provider',
      'description': 'Criteria',
      'applyUrl': 'https://provider.test/apply',
    },
    'draft': {
      'statement': 'Reviewed statement',
      'checklist': [],
      'missingFields': [],
    },
    'submission': null,
    'submissionMode': internal ? 'internal' : 'external_integration_required',
  };
  testWidgets('internal submission requires review confirmation', (
    tester,
  ) async {
    api.responses['/api/applications/abc'] = workspace();
    await show(
      tester,
      ApplicationWorkspaceScreen(
        repository: ApplicationsRepository(api),
        opportunityId: 'cat:abc',
      ),
    );
    final submit = find.text('Review & submit');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm submission'));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c.method == 'POST').single.body, {
      'confirmation': true,
    });
  });
  testWidgets('external workspace never offers internal submission', (
    tester,
  ) async {
    api.responses['/api/applications/abc'] = workspace(internal: false);
    await show(
      tester,
      ApplicationWorkspaceScreen(
        repository: ApplicationsRepository(api),
        opportunityId: 'cat:abc',
      ),
    );
    expect(find.text('Review & submit'), findsNothing);
    await tester.ensureVisible(find.text('Open provider website'));
    expect(find.text('Open provider website'), findsOneWidget);
    expect(api.calls.where((c) => c.method != 'GET'), isEmpty);
  });
  testWidgets(
    'coach retains question after failure then renders server answer',
    (tester) async {
      await show(
        tester,
        CoachScreen(repository: CoachingRepository(api)),
        scaffold: true,
      );
      await tester.enterText(
        find.byType(TextField),
        'Help with my application',
      );
      await tester.pump();
      api.failure = const ApiException('AI allowance exhausted');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(find.text('Help with my application'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AI allowance exhausted'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('AI allowance exhausted'), findsOneWidget);
      api.failure = null;
      api.responses['/api/ai/coach'] = {
        'summary': 'Check your eligibility.',
        'plan': ['Read the provider criteria'],
        'conversationId': null,
      };
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your eligibility.'), findsOneWidget);
      expect(
        find.byType(TextField).evaluate().single.widget is TextField,
        isTrue,
      );
    },
  );
  testWidgets('notification preference failure does not change the switch', (
    tester,
  ) async {
    api.responses['/api/me/notifications'] = {
      'matches': true,
      'deadlines': true,
      'applications': true,
      'community': false,
      'weeklyRoundup': true,
    };
    await show(
      tester,
      NotificationPreferencesScreen(repository: SettingsRepository(api)),
    );
    api.failure = const ApiException('Offline');
    await tester.tap(find.text('Community activity'));
    await tester.pumpAndSettle();
    expect(api.calls.last.body, {'community': true});
    expect(
      tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .elementAt(3)
          .value,
      isFalse,
    );
  });
  testWidgets(
    'community never shows fixture posts after failed load and retry works',
    (tester) async {
      api.failure = const ApiException('Offline');
      await show(tester, CommunityScreen(repository: CommunityRepository(api)));
      expect(find.text('Could not load this page'), findsOneWidget);
      api.failure = null;
      api.responses['/api/community/posts'] = [];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
    },
  );
  testWidgets('academic hub shows no invented GPA for an ungraded account', (
    tester,
  ) async {
    api.responses['/api/academic'] = {
      'courses': [],
      'deadlines': [],
      'assessments': [],
      'degreePlan': null,
    };
    await show(
      tester,
      AcademicsScreen(repository: AcademicsRepository(api)),
      scaffold: true,
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 courses · Default 4.0 scale'), findsOneWidget);
  });
  test('calendar validation rejects normalized impossible dates', () {
    expect(validateCalendarDate('2026-02-31'), isNotNull);
    expect(validateCalendarDate('2028-02-29'), isNull);
    expect(validateNumber('NaN', min: 0, max: 100), isNotNull);
  });
}
