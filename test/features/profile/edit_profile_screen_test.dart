import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/presentation/edit_profile_screen.dart';

void main() {
  late ApiClient api;
  late _FixtureProfile repository;
  bool? result;
  late List<String> interests;

  setUp(() {
    api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    repository = _FixtureProfile(api);
    result = null;
    interests = ['Science'];
  });
  tearDown(() => api.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open editor'),
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      profile: UserProfile.fromJson({
                        'firstName': 'Fixture',
                        'lastName': 'Student',
                        'institution': 'Fixture University',
                        'program': 'Science',
                        'year': '2',
                        'citizenship': 'citizen',
                        'interests': interests,
                        'opportunityTypes': ['Scholarships'],
                      }),
                      repository: repository,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> editAndBack(WidgetTester tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Updated');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Keep your changes?'), findsOneWidget);
  }

  testWidgets('clean editor can leave without a confirmation', (tester) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Keep your changes?'), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    expect(repository.writes, 0);
  });

  testWidgets('save and leave validates required fields below the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    interests = [];
    await editAndBack(tester);
    await tester.tap(find.text('Save and leave'));
    await tester.pumpAndSettle();
    expect(repository.writes, 0);
    expect(find.text('Keep your changes?'), findsNothing);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets(
    'keep editing retains changes and discard leaves without writing',
    (tester) async {
      await editAndBack(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        'Updated',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(repository.writes, 0);
      expect(result, isFalse);
    },
  );

  testWidgets(
    'save and leave persists fields, confirms success, and returns changed',
    (tester) async {
      await editAndBack(tester);
      await tester.tap(find.text('Save and leave'));
      await tester.pumpAndSettle();
      expect(repository.saved?['firstName'], 'Updated');
      expect(repository.writes, 1);
      expect(result, isTrue);
      expect(find.text('Profile saved.'), findsOneWidget);
    },
  );

  testWidgets('failed save retains edits and permits retry', (tester) async {
    repository.fail = true;
    await editAndBack(tester);
    await tester.tap(find.text('Save and leave'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(result, isNull);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'Updated',
    );
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Your profile could not be saved. Please try again.',
        ),
      ),
      findsOneWidget,
    );
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.writes, 2);
    expect(result, isTrue);
  });
}

class _FixtureProfile extends ProfileRepository {
  _FixtureProfile(super.api);
  int writes = 0;
  bool fail = false;
  Map<String, dynamic>? saved;

  @override
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    writes++;
    if (fail) throw StateError('Fixture write failure');
    saved = fields;
  }
}
