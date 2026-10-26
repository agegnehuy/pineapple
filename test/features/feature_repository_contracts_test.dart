import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  test(
    'support uses the existing contact contract without claiming priority',
    () async {
      await SettingsRepository(api).sendSupportMessage(
        name: 'Student',
        email: 'student@example.test',
        message: 'Please help with my application.',
      );
      expect(api.calls.single.path, '/api/contact');
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.body, {
        'name': 'Student',
        'email': 'student@example.test',
        'topic': 'student',
        'message': 'Please help with my application.',
      });
    },
  );
  test(
    'deletion retry accepts only the exact already-deleted response',
    () async {
      final repository = SettingsRepository(api);
      api.failure = const ApiException('Account not found.', statusCode: 404);
      await repository.deleteAccount('student@example.test');
      api.failure = const ApiException('Route not found.', statusCode: 404);
      await expectLater(
        repository.deleteAccount('student@example.test'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'bookmarking an in-progress application never changes its status',
    () async {
      api.responses['/api/tracking'] = [
        {'id': 'tracked', 'opportunityId': 'cat:abc', 'status': 'drafting'},
      ];
      await ApplicationsRepository(api).bookmark('cat:abc');
      expect(api.calls.length, 1);
      expect(api.calls.single.method, 'GET');
    },
  );
  test(
    'password recovery uses the website endpoint and normalized email',
    () async {
      await AuthRepository(
        api,
        MemoryCookieStore(),
      ).requestPasswordReset(' Student@Example.test ');
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/api/auth/forgot-password');
      expect(api.calls.single.body, {'email': 'student@example.test'});
    },
  );
  test(
    'workspace strips catalogue prefix and preserves statement/checklist on PUT',
    () async {
      final repo = ApplicationsRepository(api);
      await repo.getWorkspace('cat:abc');
      await repo.saveStatement(
        'cat:abc',
        'My statement',
        checklist: ['Review eligibility'],
        missingFields: ['Transcript'],
      );
      await repo.submitApplication('cat:abc');
      await repo.withdrawApplication('cat:abc');
      expect(api.calls.map((c) => c.path).toSet(), {'/api/applications/abc'});
      expect(api.calls.map((c) => c.method), ['GET', 'PUT', 'POST', 'DELETE']);
      expect(api.calls[1].body, {
        'statement': 'My statement',
        'checklist': ['Review eligibility'],
        'missingFields': ['Transcript'],
      });
      expect(api.calls[2].body, {'confirmation': true});
    },
  );
  test(
    'course and goal updates use PATCH rather than replacing other data',
    () async {
      final repo = AcademicsRepository(api);
      await repo.saveCourse({'name': 'Biology', 'credits': 3}, id: 'course-1');
      await repo.saveGoal({
        'title': 'Finish essay',
        'progress': 20,
      }, id: 'goal-1');
      expect(api.calls.map((c) => c.method), ['PATCH', 'PATCH']);
      expect(api.calls.map((c) => c.path), [
        '/api/academic/courses/course-1',
        '/api/academic/goals/goal-1',
      ]);
    },
  );
  test(
    'academic snapshot decodes real response collections and weighted GPA',
    () async {
      api.responses['/api/academic'] = {
        'courses': [
          {'id': '1', 'name': 'Biology', 'credits': 3, 'gradePercent': 90},
          {'id': '2', 'name': 'Chemistry', 'credits': 1, 'gradePercent': 73},
          {'id': '3', 'name': 'Ungraded', 'credits': 3, 'gradePercent': null},
        ],
        'deadlines': [],
        'assessments': [],
        'degreePlan': null,
      };
      final result = await AcademicsRepository(api).getSnapshot();
      expect(result.courses.length, 3);
      expect(result.gpa, 3.75);
    },
  );
  test(
    'story saving and generated draft saving use separate contracts',
    () async {
      api.responses['/api/ai/story-draft'] = {'draft': 'Generated fixture'};
      final repo = CoachingRepository(api);
      await repo.saveStory({
        'background': 'My notes',
        'allowFinancialContextUse': false,
      });
      await repo.draftStory(['background'], 'Keep my voice');
      await repo.saveDraft('Reviewed statement');
      expect(api.calls.map((c) => c.path), [
        '/api/academic/story',
        '/api/ai/story-draft',
        '/api/academic/story/draft',
      ]);
      expect(api.calls[1].body, {
        'sources': ['background'],
        'instruction': 'Keep my voice',
        'consent': true,
      });
      expect(api.calls[2].body, {'draft': 'Reviewed statement'});
    },
  );
  test(
    'mentor passes privacy choices and conversation id without fabricating replies',
    () async {
      api.responses['/api/ai/coach'] = {
        'summary': 'Server answer',
        'plan': ['Check criteria'],
        'conversationId': 'thread-1',
      };
      final reply = await CoachingRepository(api).ask(
        'Help',
        conversationId: 'thread-1',
        useProfile: false,
        useSaved: false,
      );
      expect(api.calls.single.body, {
        'prompt': 'Help',
        'conversationId': 'thread-1',
        'useProfile': false,
        'useSaved': false,
      });
      expect(reply['summary'], 'Server answer');
    },
  );
  test(
    'event registration and cancellation use same route with opposite methods',
    () async {
      final repo = CommunityRepository(api);
      await repo.register('event-1');
      await repo.register('event-1', cancel: true);
      expect(api.calls.map((c) => c.method), ['POST', 'DELETE']);
      expect(api.calls.map((c) => c.path).toSet(), {
        '/api/community/events/event-1/register',
      });
    },
  );
  test(
    'community comments carry content, not incompatible reply body',
    () async {
      await CommunityRepository(api).comment('post-1', 'My comment');
      expect(api.calls.single.path, '/api/community/posts/post-1/comments');
      expect(api.calls.single.body, {'content': 'My comment'});
    },
  );
  test('notification toggles patch only selected account preference', () async {
    await SettingsRepository(api).updateNotifications({'community': true});
    expect(api.calls.single.method, 'PATCH');
    expect(api.calls.single.body, {'community': true});
  });
  test(
    'account deletion requires explicit confirmation and matching email payload',
    () async {
      await SettingsRepository(api).deleteAccount('student@example.test');
      expect(api.calls.single.method, 'DELETE');
      expect(api.calls.single.path, '/api/me/account');
      expect(api.calls.single.body, {
        'confirmEmail': 'student@example.test',
        'confirmation': 'DELETE',
      });
    },
  );
  test(
    'profile import only reads suggestions, applying is an independent PATCH',
    () async {
      api.responses['/api/profile/import'] = {
        'suggestions': [
          {'field': 'program', 'value': 'Biology'},
        ],
      };
      final repo = ProfileRepository(api);
      final suggestions = await repo.suggestImport('My résumé');
      expect(api.calls.length, 1);
      expect(suggestions.single['value'], 'Biology');
      await repo.updateProfile({'program': suggestions.single['value']});
      expect(api.calls.last.method, 'PATCH');
      expect(api.calls.last.path, '/api/me');
    },
  );
}
