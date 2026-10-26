import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/presentation/academics_screen.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity_filter.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_card.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_filter_sheet.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/presentation/onboarding_screen.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  Future<void> showLarge(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: widget),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'long opportunity card stays readable at 320 pixels and 200% text',
    (tester) async {
      await showLarge(
        tester,
        ListView(
          children: [
            OpportunityCard(
              opportunity: Opportunity.fromJson({
                'id': 'test',
                'title':
                    'A long scholarship name for the student accessibility verification',
                'org': 'A long university organization name',
                'match': 100,
                'amount': 'Up to CAD 100,000',
                'deadlineLabel': 'Closes November 30, 2026',
              }),
              onTap: () {},
              onSave: () {},
            ),
          ],
        ),
      );
      expect(find.textContaining('A long scholarship'), findsOneWidget);
    },
  );
  testWidgets('tracker long deadlines fit at large text', (tester) async {
    api.responses['/api/tracking'] = [
      {
        'id': '1',
        'opportunityId': 'fixture',
        'title': 'Long opportunity title',
        'org': 'A university',
        'status': 'drafting',
        'deadlineLabel': 'Closes November 30, 2026',
        'amount': 'CAD 100,000',
      },
    ];
    await showLarge(
      tester,
      ApplicationsScreen(repository: ApplicationsRepository(api)),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('filter sheet supports scrolling to actions at large text', (
    tester,
  ) async {
    await showLarge(
      tester,
      const OpportunityFilterSheet(initial: OpportunityFilter(), source: []),
    );
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('academic hub supports a small viewport and large text', (
    tester,
  ) async {
    api.responses['/api/academic'] = {
      'courses': [],
      'assessments': [],
      'deadlines': [],
      'degreePlan': null,
    };
    await showLarge(
      tester,
      AcademicsScreen(repository: AcademicsRepository(api)),
    );
  });
  testWidgets('coach composer leaves scrollable space at large text', (
    tester,
  ) async {
    await showLarge(tester, CoachScreen(repository: CoachingRepository(api)));
  });
  testWidgets('onboarding education fields scroll at large text', (
    tester,
  ) async {
    await showLarge(
      tester,
      OnboardingScreen(
        repository: ProfileRepository(api),
        profile: UserProfile.fromJson({
          'firstName': 'Test',
          'lastName': 'Student',
          'institution': '',
          'program': '',
          'year': '',
          'citizenship': '',
        }),
      ),
    );
  });
}
