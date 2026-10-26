import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets(
    'a covered profile reflects confirmed changes from another route',
    (tester) async {
      final api = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        cookieStore: MemoryCookieStore(),
      );
      final repository = _FixtureProfile(api);
      addTearDown(repository.dispose);
      addTearDown(api.close);
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation,
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileScreen(repository: repository, onSignOut: () async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fixture Student'), findsOneWidget);
      navigation.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Settings')),
        ),
      );
      await tester.pumpAndSettle();
      repository.confirmName('Updated');
      await tester.pumpAndSettle();
      navigation.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Updated Student'), findsOneWidget);
      expect(find.text('Fixture Student'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repository.confirmName('After disposal');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid sign-out activation opens a single cancellable prompt', (
    tester,
  ) async {
    final api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    addTearDown(api.close);
    var signedOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileScreen(
            repository: _FixtureProfile(api),
            onSignOut: () async => signedOut++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Sign out');
    await tester.scrollUntilVisible(button, 240);
    final activate = tester.widget<OutlinedButton>(button).onPressed!;
    activate();
    activate();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(signedOut, 0);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
  });

  testWidgets('profile footer opens each connected destination', (
    tester,
  ) async {
    final api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    addTearDown(api.close);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileScreen(
            repository: _FixtureProfile(api),
            onSignOut: () async {},
            onStory: () => opened.add('story'),
            onSettings: () => opened.add('settings'),
            onHelp: () => opened.add('help'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Make it yours.'), findsOneWidget);
    for (final label in ['My story', 'Settings', 'Help']) {
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, label),
        240,
      );
      await tester.tap(find.widgetWithText(TextButton, label));
    }
    expect(opened, ['story', 'settings', 'help']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile load failure still allows sign-out from an expired session',
    (tester) async {
      final api = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        cookieStore: MemoryCookieStore(),
      );
      addTearDown(api.close);
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileScreen(
              repository: _FixtureProfile(api)..failRead = true,
              onSignOut: () async {
                signedOut = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile unavailable'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
    },
  );
  testWidgets('failed local session removal offers another sign-out attempt', (
    tester,
  ) async {
    final api = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      cookieStore: MemoryCookieStore(),
    );
    addTearDown(api.close);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileScreen(
            repository: _FixtureProfile(api),
            onSignOut: () async {
              attempts++;
              throw StateError('Fixture storage failure');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
    await tester.scrollUntilVisible(signOut, 300);
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not clear your session. Please try again.'),
      findsOneWidget,
    );
    expect(attempts, 1);
    expect(tester.takeException(), isNull);
    expect(tester.widget<OutlinedButton>(signOut).onPressed, isNotNull);
  });
}

class _FixtureProfile extends ProfileRepository {
  _FixtureProfile(super.api);
  bool failRead = false;
  String firstName = 'Fixture';

  void confirmName(String value) {
    firstName = value;
    notifyListeners();
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    if (failRead) throw StateError('Fixture expired session');
    return UserProfile.fromJson({
      'firstName': firstName,
      'lastName': 'Student',
    });
  }
}
