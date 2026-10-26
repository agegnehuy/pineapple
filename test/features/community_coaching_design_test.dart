import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/coaching/presentation/story_draft_screen.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/community/presentation/community_conversation_screen.dart';
import 'package:myoccasio/features/community/presentation/community_event_screen.dart';
import 'package:myoccasio/features/community/presentation/community_screen.dart';

import '../support/recording_api.dart';
import '../core/localization/app_localization_test.dart' show showFrench;

Finder labeledField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> visible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    if (find.byType(ListView).evaluate().isEmpty &&
        find.byType(NestedScrollView).evaluate().isNotEmpty) {
      final outer = find
          .descendant(
            of: find.byType(NestedScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(outer).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());

  const story = {
    'background': 'Settings',
    'achievements': 'My own tutoring experience',
    'financialContext': 'Private financial details',
    'allowFinancialContextUse': false,
  };

  Future<void> openRoute(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute(builder: (_) => screen)),
              child: const Text('Open feature'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open feature'));
    await tester.pumpAndSettle();
  }

  Future<void> enableDraft(WidgetTester tester) async {
    final consent = find.widgetWithText(
      CheckboxListTile,
      'Allow the selected notes to be sent to the AI service for this draft.',
    );
    await visible(tester, consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'story draft sends chosen sources and focus only after explicit consent and saves after review',
    (tester) async {
      api.responses['/api/ai/story-draft'] = {
        'draft': 'A draft using my real experience.',
        'saved': false,
      };
      await openRoute(
        tester,
        StoryDraftScreen(repository: CoachingRepository(api), story: story),
      );
      expect(find.text('Financial context (optional)'), findsNothing);
      expect(find.text('Private financial details'), findsNothing);
      await tester.enterText(
        labeledField('What are you writing?'),
        'My statement',
      );
      await tester.enterText(
        labeledField('What should it highlight?'),
        'My tutoring experience',
      );
      final achievement = find.widgetWithText(
        CheckboxListTile,
        'What you’re proud of',
      );
      await visible(tester, achievement);
      await tester.tap(achievement);
      await tester.pumpAndSettle();
      final generate = find.widgetWithText(
        FilledButton,
        'Create a starting draft',
      );
      await visible(tester, generate);
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      expect(api.calls, isEmpty);
      await enableDraft(tester);
      await visible(tester, generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(api.calls.single.path, '/api/ai/story-draft');
      expect(api.calls.single.body, {
        'sources': ['background'],
        'instruction':
            'Writing: My statement\nHighlight: My tutoring experience',
        'consent': true,
      });
      expect(find.text('Review your draft'), findsOneWidget);
      expect(api.calls.where((call) => call.method == 'PUT'), isEmpty);
      // Even the unedited generated text is unsaved and needs confirmation.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('This draft has not been saved.'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await visible(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.calls.last.path, '/api/academic/story/draft');
      expect(api.calls.last.body, {
        'draft': 'A draft using my real experience.',
      });
      expect(find.text('Open feature'), findsOneWidget);
    },
  );

  testWidgets('failed drafting retains purpose and source choices for retry', (
    tester,
  ) async {
    await openRoute(
      tester,
      StoryDraftScreen(repository: CoachingRepository(api), story: story),
    );
    await tester.enterText(
      labeledField('What are you writing?'),
      'Keep this focus',
    );
    await enableDraft(tester);
    api.failure = const ApiException('AI allowance exhausted');
    final generate = find.widgetWithText(
      FilledButton,
      'Create a starting draft',
    );
    await visible(tester, generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.text('AI allowance exhausted'), findsOneWidget);
    expect(find.text('Retry draft generation'), findsOneWidget);
    await visible(tester, labeledField('What are you writing?'));
    expect(
      tester
          .widget<TextField>(labeledField('What are you writing?'))
          .controller!
          .text,
      'Keep this focus',
    );
    expect(api.calls.length, 1);
    expect(api.calls.single.body['sources'], ['background', 'achievements']);
    expect(api.calls.where((call) => call.method == 'PUT'), isEmpty);
  });

  testWidgets(
    'an unsent coach question is retained when discard is cancelled',
    (tester) async {
      await openRoute(
        tester,
        Scaffold(body: CoachScreen(repository: CoachingRepository(api))),
      );
      await tester.enterText(
        find.byType(TextField),
        'Keep my original question',
      );
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Your question has not been sent.'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Keep my original question'), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'community comment retains failure, ignores duplicate send, and counts fetched replies',
    (tester) async {
      const path = '/api/community/posts/post-1/comments';
      api.responses[path] = {'comments': []};
      await openRoute(
        tester,
        CommunityConversationScreen(
          repository: CommunityRepository(api),
          post: const {
            'id': 'post-1',
            'body': 'Original community post',
            'firstName': 'Real',
            'lastName': 'Author',
          },
          win: false,
        ),
      );
      await tester.enterText(
        labeledField('Your comment'),
        'My thoughtful reply',
      );
      await tester.pump();
      api.failure = const ApiException('Comment service offline');
      final send = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Post comment',
            ),
          )
          .onPressed!;
      send();
      send();
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'POST').length, 1);
      expect(find.text('My thoughtful reply'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your comment has not been posted.'), findsOneWidget);
      send();
      await tester.pump();
      expect(api.calls.where((call) => call.method == 'POST').length, 1);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      api.failure = null;
      api.responses[path] = {
        'comments': [
          {
            'firstName': 'My',
            'lastName': 'Name',
            'content': 'My thoughtful reply',
          },
        ],
      };
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'POST').last.body, {
        'content': 'My thoughtful reply',
      });
      expect(
        tester.widget<TextField>(labeledField('Your comment')).controller!.text,
        isEmpty,
      );
      await visible(tester, find.text('1 reply'));
      expect(find.text('1 reply'), findsOneWidget);
    },
  );

  testWidgets(
    'pending comment write blocks Back but its delayed refresh does not',
    (tester) async {
      final repository = PendingCommentsRepository(api);
      await openRoute(
        tester,
        CommunityConversationScreen(
          repository: repository,
          post: const {'id': 'post-1', 'body': 'Original community post'},
          win: false,
        ),
      );
      await tester.enterText(labeledField('Your comment'), 'My new comment');
      await tester.pump();
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pump();
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Conversation'), findsOneWidget);
      repository.write.complete();
      await tester.pump();
      await tester.pump();
      expect(repository.reads, 2);
      expect(
        tester.widget<TextField>(labeledField('Your comment')).controller!.text,
        isEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open feature'), findsOneWidget);
      repository.refresh.complete([]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real coffee request is sent only after one guarded confirmation',
    (tester) async {
      api.responses['/api/community/people'] = [
        {
          'id': 'person-1',
          'firstName': 'Real',
          'lastName': 'Student',
          'program': 'Biology',
          'institution': 'University',
          'tags': ['Community'],
        },
      ];
      api.responses['/api/community/chat-requests'] = {'alreadyExists': false};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CommunityScreen(
            repository: CommunityRepository(api),
            initialTab: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final request = find.widgetWithText(
        OutlinedButton,
        'Request a coffee chat',
      );
      await visible(tester, request);
      final confirm = tester.widget<OutlinedButton>(request).onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.calls.where((call) => call.method == 'POST'), isEmpty);
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'POST').single.body, {
        'toUserId': 'person-1',
      });
      expect(find.text('Coffee chat request sent.'), findsOneWidget);
    },
  );

  testWidgets(
    'event registration changes only after a confirmed endpoint response',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CommunityEventScreen(
            repository: CommunityRepository(api),
            event: const {
              'id': 'event-1',
              'title': 'Real workshop',
              'description': 'Original provider details',
              'eventDate': '2026-11-30T18:00:00Z',
              'location': 'Online',
              'isRegistered': false,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      api.failure = const ApiException('Registration offline');
      await visible(tester, find.text('Register for event'));
      await tester.tap(find.text('Register for event'));
      await tester.pumpAndSettle();
      expect(find.text('Registration offline'), findsOneWidget);
      expect(find.text('Cancel registration'), findsNothing);
      api.failure = null;
      await tester.tap(find.text('Register for event'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel registration'), findsOneWidget);
      expect(api.calls.last.path, '/api/community/events/event-1/register');
      expect(api.calls.last.method, 'POST');
      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      expect(api.calls.last.method, 'DELETE');
      expect(find.text('Register for event'), findsOneWidget);
    },
  );

  testWidgets('event filters use actual future dates and registration state', (
    tester,
  ) async {
    api.responses['/api/community/events'] = [
      {
        'id': 'next',
        'title': 'Future workshop',
        'eventDate': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'isRegistered': false,
      },
      {
        'id': 'past',
        'title': 'Registered past workshop',
        'eventDate': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String(),
        'isRegistered': true,
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CommunityScreen(
          repository: CommunityRepository(api),
          initialTab: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Future workshop'), findsOneWidget);
    expect(find.text('Registered past workshop'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Registered'));
    await tester.pumpAndSettle();
    expect(find.text('Registered past workshop'), findsOneWidget);
    expect(find.text('Future workshop'), findsNothing);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets(
    'story draft setup remains scrollable at 320px and 200% French text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showFrench(
        tester,
        StoryDraftScreen(repository: CoachingRepository(api), story: story),
        scale: 2,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'real win cards preserve original author text in large French layouts',
    (tester) async {
      api.responses['/api/community/wins'] = [
        {
          'id': 'win-1',
          'authorFirstName': 'Settings',
          'authorLastName': 'Save',
          'body': 'My actual experience, in my own words.',
          'likeCount': 2,
          'liked': false,
        },
      ];
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showFrench(
        tester,
        CommunityScreen(repository: CommunityRepository(api), initialTab: 1),
        scale: 2,
      );
      await visible(tester, find.text('Settings Save'));
      expect(find.text('Settings Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );
}

class PendingCommentsRepository extends CommunityRepository {
  PendingCommentsRepository(super.api);
  final write = Completer<void>();
  final refresh = Completer<List<Map<String, dynamic>>>();
  int reads = 0;

  @override
  Future<List<Map<String, dynamic>>> comments(
    String id, {
    bool win = false,
  }) async => ++reads == 1 ? [] : refresh.future;

  @override
  Future<void> comment(String id, String text, {bool win = false}) =>
      write.future;
}
