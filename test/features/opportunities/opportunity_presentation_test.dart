import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_detail_screen.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_card.dart';

import '../../support/recording_api.dart';

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  Future<void> showSmall(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: _delegates,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  final opportunity = Opportunity.fromJson({
    'id': 'cat:fixture',
    'title':
        'A long scholarship title for accessible student opportunity cards',
    'org': 'Settings',
    'kind': 'scholarship',
    'kindLabel': 'Scholarship',
    'amount': 'CAD 100,000',
    'amountSub': 'Save',
    'deadlineLabel': 'Closes November 30, 2026',
    'reasons': ['Settings'],
    'summary': 'Save\n\nSettings',
    'match': 100,
  });

  for (final dark in [false, true]) {
    testWidgets(
      'opportunity card stacks long facts at 200% French text, dark=$dark',
      (tester) async {
        await showSmall(
          tester,
          Scaffold(
            body: ListView(
              children: [
                OpportunityCard(
                  opportunity: opportunity,
                  onTap: () {},
                  onSave: () {},
                  featured: dark,
                ),
              ],
            ),
          ),
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(opportunity.title), findsOneWidget);
        expect(
          find.text('Settings · Bourse', findRichText: true),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text('Closes November 30, 2026')).dy,
          greaterThan(tester.getBottomLeft(find.text('CAD 100,000')).dy),
        );
        final bookmark = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == 'Enregistrer la possibilité',
          ),
        );
        if (dark) expect(bookmark.color, Colors.white);
      },
    );
  }

  testWidgets(
    'detail preserves real eligibility and provider paragraphs at 200% French text',
    (tester) async {
      final api = RecordingApi();
      addTearDown(api.close);
      await showSmall(
        tester,
        OpportunityDetailScreen(
          opportunity: opportunity,
          applicationsRepository: ApplicationsRepository(api),
        ),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('opportunity-value-hero')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('CAD 100,000'), findsOneWidget);
      await tester.ensureVisible(find.text('Save\n\nSettings'));
      await tester.pumpAndSettle();
      expect(find.text('Save\n\nSettings'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );
}
