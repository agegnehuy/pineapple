import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/application_coach_screen.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApplicationCoachScreen(
          applications: ApplicationsRepository(api),
          coaching: CoachingRepository(api),
          opportunityId: 'cat:award-1',
          opportunity: const {
            'title': 'Real loaded title',
            'description': 'Provider criteria',
          },
          statement: 'My existing statement',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('coaching question is editable and is never sent automatically', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Strengthen my statement'));
    await tester.pumpAndSettle();
    final prompt = tester.widget<TextField>(find.byType(TextField));
    expect(prompt.controller!.text, contains('My existing statement'));
    expect(prompt.controller!.text, contains('Provider criteria'));
    expect(api.calls, isEmpty);
  });
  testWidgets('draft generation requires consent and saves only after review', (
    tester,
  ) async {
    api.responses['/api/ai/application-draft/award-1'] = {
      'statement': 'Generated draft to review',
      'checklist': ['Check facts'],
      'missingFields': ['Experience'],
      'saved': false,
    };
    await show(tester);
    final generate = find.text('Generate draft for review');
    await scrollTo(tester, generate);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: generate, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    expect(api.calls, isEmpty);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(api.calls.single.path, '/api/ai/application-draft/award-1');
    expect(api.calls.single.body, {'consent': true, 'instruction': ''});
    expect(find.text('Review application draft'), findsOneWidget);
    expect(find.textContaining('Experience'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.calls.last.method, 'PUT');
    expect(api.calls.last.path, '/api/applications/award-1');
    expect(api.calls.last.body, {
      'statement': 'Generated draft to review',
      'checklist': ['Check facts'],
      'missingFields': ['Experience'],
    });
    expect(
      api.calls.where(
        (c) => c.path == '/api/applications/award-1' && c.method == 'POST',
      ),
      isEmpty,
    );
  });
  testWidgets('plan denial preserves instructions and offers explicit retry', (
    tester,
  ) async {
    await show(tester);
    await scrollTo(tester, find.byType(CheckboxListTile));
    await tester.enterText(find.byType(TextField), 'Keep my voice');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    api.failure = const ApiException(
      'Your plan does not include application guidance',
      statusCode: 403,
    );
    await tester.ensureVisible(find.text('Generate draft for review'));
    await tester.tap(find.text('Generate draft for review'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Retry draft generation'));
    expect(
      find.text('Your plan does not include application guidance'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep my voice',
    );
    expect(api.calls.length, 1);
  });
}
