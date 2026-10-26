import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunities_screen.dart';

import '../../support/recording_api.dart';

void main() {
  testWidgets(
    'empty search can reset visible input or edit matching interests',
    (tester) async {
      final api = RecordingApi()
        ..responses['/api/tracking'] = []
        ..responses['/api/matches'] = {
          'matches': [
            {'id': 'cat:fixture', 'title': 'Science award', 'org': 'College'},
          ],
          'totalMatches': 1,
          'profile': {'status': 'complete'},
        };
      addTearDown(api.close);
      var edited = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OpportunitiesScreen(
              repository: OpportunitiesRepository(api),
              applicationsRepository: ApplicationsRepository(api),
              onEditProfile: () async => edited++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No matching award');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
      await tester.ensureVisible(find.text('Edit my interests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit my interests'));
      await tester.pumpAndSettle();
      expect(edited, 1);
      expect(find.text('No results'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('Science award'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );
}
