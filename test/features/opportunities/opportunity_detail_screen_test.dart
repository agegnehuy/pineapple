import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_detail_screen.dart';

void main() {
  testWidgets('repeated bookmark taps issue one pending write', (tester) async {
    final api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    addTearDown(api.close);
    final pending = Completer<void>();
    final repository = _FailingApplications(api)..write = () => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OpportunityDetailScreen(
          opportunity: Opportunity.fromJson({
            'id': 'fixture',
            'title': 'Fixture opportunity',
          }),
          applicationsRepository: repository,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Save opportunity'));
    await tester.tap(find.byTooltip('Save opportunity'));
    expect(repository.attempts, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Opportunity saved.'), findsOneWidget);
  });
  testWidgets(
    'failed bookmark save is recoverable and never invents eligibility',
    (tester) async {
      final api = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        cookieStore: MemoryCookieStore(),
      );
      addTearDown(api.close);
      final repository = _FailingApplications(api);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OpportunityDetailScreen(
            opportunity: Opportunity.fromJson({
              'id': 'fixture',
              'title': 'Fixture opportunity',
            }),
            applicationsRepository: repository,
          ),
        ),
      );
      expect(find.text('Matches your student profile'), findsNothing);
      expect(find.text('Open to your selected interests'), findsNothing);
      await tester.tap(find.byTooltip('Save opportunity'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save this opportunity. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Save opportunity'));
      await tester.pumpAndSettle();
      expect(repository.attempts, 2);
    },
  );
}

class _FailingApplications extends ApplicationsRepository {
  _FailingApplications(super.api);
  int attempts = 0;
  Future<void> Function() write = () async =>
      throw StateError('Fixture write failure');

  @override
  Future<List<TrackedApplication>> getTrackedApplications() async => [];

  @override
  Future<void> saveTrackedApplication({
    required String opportunityId,
    String status = 'saved',
  }) async {
    attempts++;
    await write();
  }
}
