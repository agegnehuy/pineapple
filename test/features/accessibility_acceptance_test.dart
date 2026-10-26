import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity_filter.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunities_screen.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_filter_sheet.dart';

import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
    EdgeInsets keyboard = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
            viewInsets: keyboard,
          ),
          child: child!,
        ),
        home: Scaffold(body: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectSheetSettled(WidgetTester tester) {
    final route = ModalRoute.of(tester.element(find.byType(BottomSheet)));
    expect(route!.animation!.value, 1);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'wrapped location menu remains selectable at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const region =
          'Newfoundland and Labrador · remote and regional opportunities';
      OpportunityFilter? selected;
      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showModalBottomSheet<OpportunityFilter>(
                context: context,
                isScrollControlled: true,
                sheetAnimationStyle: AnimationStyle.noAnimation,
                builder: (_) => OpportunityFilterSheet(
                  initial: const OpportunityFilter(),
                  source: [
                    Opportunity.fromJson({
                      'id': 'original',
                      'title': 'Original record',
                      'region': region,
                    }),
                  ],
                ),
              );
            },
            child: const Text('Open filters'),
          ),
        ),
        scale: 2,
      );
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      final location = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(location);
      await tester.tap(location);
      await tester.pumpAndSettle();
      final option = find.text(region).last;
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(tester.getSize(option).height, greaterThan(48));
      expect(tester.takeException(), isNull);
      await tester.tap(option);
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(FilledButton, 'Show 1 opportunities');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(selected!.region, region);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opportunity filter sheet opens without motion when requested', (
    tester,
  ) async {
    api.responses['/api/matches'] = {
      'matches': [],
      'profile': {'status': 'complete'},
    };
    api.responses['/api/tracking'] = [];
    await show(
      tester,
      OpportunitiesScreen(
        repository: OpportunitiesRepository(api),
        applicationsRepository: ApplicationsRepository(api),
      ),
    );
    await tester.tap(find.text('Filters'));
    await tester.pump();
    await tester.pump();
    expectSheetSettled(tester);
  });

  testWidgets('application status sheet opens without motion when requested', (
    tester,
  ) async {
    api.responses['/api/tracking'] = [
      {
        'id': 'tracked',
        'opportunityId': 'cat:original',
        'title': 'Original record',
        'status': 'saved',
      },
    ];
    await show(
      tester,
      ApplicationsScreen(repository: ApplicationsRepository(api)),
    );
    final status = find.byTooltip('Change application status');
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pump();
    await tester.pump();
    expectSheetSettled(tester);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets(
    'coach history sheet opens without motion and original titles are preserved',
    (tester) async {
      api.responses['/api/ai/coach'] = {
        'memoryEnabled': true,
        'conversations': [
          {'id': 'history', 'title': 'Original saved question'},
        ],
      };
      await show(tester, CoachScreen(repository: CoachingRepository(api)));
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump();
      expectSheetSettled(tester);
      expect(find.text('Original saved question'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'filled coach question keeps an accessible name in a landscape keyboard viewport',
    (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        api.responses['/api/ai/coach'] = {
          'summary': 'Original server answer',
          'plan': [],
        };
        await show(
          tester,
          CoachScreen(repository: CoachingRepository(api)),
          scale: 2,
          keyboard: const EdgeInsets.only(bottom: 120),
        );
        await tester.enterText(
          find.byType(TextField),
          'Keep my original question',
        );
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp('Ask a question…')), findsWidgets);
        final send = find.byTooltip('Send question');
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        final sendSize = tester.getSize(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Send question',
          ),
        );
        expect(sendSize.width, greaterThanOrEqualTo(48));
        expect(sendSize.height, greaterThanOrEqualTo(48));
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(api.calls.single.body['prompt'], 'Keep my original question');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
