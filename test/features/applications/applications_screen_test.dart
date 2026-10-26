import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';

void main() {
  late ApiClient api;
  late _FixtureApplications repository;

  setUp(() {
    api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    repository = _FixtureApplications(api);
  });
  tearDown(() => api.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ApplicationsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectInProgress(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Change application status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('In progress'),
      ),
    );
    await tester.ensureVisible(find.text('Save status'));
    await tester.tap(find.text('Save status'));
  }

  testWidgets(
    'failed status write leaves data intact and retry persists the change',
    (tester) async {
      repository.save = () async => throw StateError('Fixture write failure');
      await open(tester);
      await selectInProgress(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update this application. Please try again.'),
        findsOneWidget,
      );
      expect(repository.status, 'saved');
      expect(tester.takeException(), isNull);

      repository.save = () async {};
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.writes, 2);
      expect(repository.status, 'drafting');
      expect(find.text('Application marked in progress.'), findsOneWidget);
    },
  );

  testWidgets(
    'pending write locks selection and close until the response completes',
    (tester) async {
      final pending = Completer<void>();
      repository.save = () => pending.future;
      await open(tester);
      await selectInProgress(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Close',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(repository.writes, 1);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Change application status',
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'status selection is not written until save and can be cancelled',
    (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Change application status'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Submitted'),
        ),
      );
      expect(repository.writes, 0);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(repository.status, 'saved');
      expect(repository.writes, 0);
    },
  );

  testWidgets(
    'failed pull-to-refresh displays retry without an uncaught error',
    (tester) async {
      await open(tester);
      repository.failRead = true;
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Applications unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repository.failRead = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture opportunity'), findsOneWidget);
    },
  );
}

class _FixtureApplications extends ApplicationsRepository {
  _FixtureApplications(super.api);

  String status = 'saved';
  int writes = 0;
  bool failRead = false;
  Future<void> Function() save = () async {};

  @override
  Future<List<TrackedApplication>> getTrackedApplications() async {
    if (failRead) throw StateError('Fixture read failure');
    return [
      TrackedApplication.fromJson({
        'id': 'fixture',
        'opportunityId': 'fixture',
        'title': 'Fixture opportunity',
        'status': status,
      }),
    ];
  }

  @override
  Future<void> saveTrackedApplication({
    required String opportunityId,
    String status = 'saved',
  }) async {
    writes++;
    await save();
    this.status = status;
  }
}
