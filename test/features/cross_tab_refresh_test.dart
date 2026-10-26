import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  test(
    'only confirmed profile and tracking writes notify other destinations',
    () async {
      final profile = ProfileRepository(api);
      final applications = ApplicationsRepository(api);
      var profileChanges = 0;
      var trackingChanges = 0;
      profile.addListener(() => profileChanges++);
      applications.addListener(() => trackingChanges++);
      api.failure = const ApiException('Save failed', statusCode: 503);
      await expectLater(
        profile.updateProfile({'program': 'Biology'}),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        applications.saveTrackedApplication(opportunityId: 'cat:one'),
        throwsA(isA<ApiException>()),
      );
      expect(profileChanges, 0);
      expect(trackingChanges, 0);
      api.failure = null;
      await profile.updateProfile({'program': 'Biology'});
      await applications.saveTrackedApplication(opportunityId: 'cat:one');
      expect(profileChanges, 1);
      expect(trackingChanges, 1);
      profile.dispose();
      applications.dispose();
    },
  );
  testWidgets(
    'a visited tracker refreshes after a bookmark from another destination',
    (tester) async {
      api.responses['/api/tracking'] = [];
      final applications = ApplicationsRepository(api);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: ApplicationsScreen(repository: applications)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Newly saved opportunity'), findsNothing);
      api.responses['/api/tracking'] = [
        {
          'id': 'tracking-1',
          'opportunityId': 'cat:one',
          'status': 'saved',
          'title': 'Newly saved opportunity',
          'organization': 'Provider',
        },
      ];
      await applications.saveTrackedApplication(opportunityId: 'cat:one');
      await tester.pumpAndSettle();
      expect(find.text('Newly saved opportunity'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.calls.clear();
      await applications.saveTrackedApplication(opportunityId: 'cat:two');
      expect(api.calls.where((call) => call.method == 'GET'), isEmpty);
      applications.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
