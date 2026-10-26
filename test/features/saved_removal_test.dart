import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() {
    api = RecordingApi();
    api.responses['/api/tracking'] = [
      {
        'id': 'record-1',
        'opportunityId': 'cat:one',
        'title': 'Saved award',
        'status': 'saved',
      },
    ];
  });
  tearDown(() => api.close());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ApplicationsScreen(
            repository: ApplicationsRepository(api),
            savedOnly: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove from saved'));
    await tester.tap(find.text('Remove from saved'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancelling saved removal sends no mutation', (tester) async {
    await open(tester);
    expect(find.text('Remove from saved?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Saved award'), findsOneWidget);
    expect(api.calls.where((c) => c.method == 'DELETE'), isEmpty);
  });
  testWidgets(
    'failed removal retains the bookmark and retry removes only its tracker id',
    (tester) async {
      await open(tester);
      api.failure = const ApiException('Removal failed', statusCode: 503);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Removal failed'), findsOneWidget);
      expect(find.text('Saved award'), findsOneWidget);
      api.failure = null;
      api.responses['/api/tracking'] = [];
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Saved award'), findsNothing);
      expect(api.calls.where((c) => c.method == 'DELETE').map((c) => c.path), [
        '/api/tracking/record-1',
        '/api/tracking/record-1',
      ]);
    },
  );
}
