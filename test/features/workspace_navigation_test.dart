import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/app.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/presentation/gpa_tools_screen.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/community/presentation/community_screen.dart';
import 'package:myoccasio/features/navigation/presentation/main_shell.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

import '../support/recording_api.dart';
import '../support/recording_dependencies.dart';

Widget _host(WorkspaceNavigationController navigation) => AnimatedBuilder(
  animation: navigation,
  builder: (context, _) => MaterialApp(
    navigatorKey: navigation.navigatorKey,
    navigatorObservers: [navigation.observer],
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) =>
        WorkspaceNavigationScope(controller: navigation, child: child!),
    home: Scaffold(
      body: Text('Tab ${navigation.selectedIndex}'),
      bottomNavigationBar: const WorkspaceBottomBar(),
    ),
  ),
);

Widget _detail(String title, {bool enabled = true}) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: Text(title),
  bottomNavigationBar: WorkspaceBottomBar(enabled: enabled),
);

void main() {
  testWidgets(
    'detail destinations return to the root and select the requested tab',
    (tester) async {
      final navigation = WorkspaceNavigationController()
        ..updateSession('account-one')
        ..selectRootTab(1);
      await tester.pumpWidget(_host(navigation));
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => _detail('Opportunity')),
      );
      await tester.pumpAndSettle();
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => _detail('Application')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Découvrir'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tester.tap(find.text('Études'));
      await tester.pumpAndSettle();
      expect(find.text('Tab 3'), findsOneWidget);
      expect(find.text('Opportunity'), findsNothing);
      expect(find.text('Application'), findsNothing);
      expect(navigation.navigatorKey.currentState!.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
    },
  );

  testWidgets('guarded routes prevent tab switching and keep discard dialogs', (
    tester,
  ) async {
    final navigation = WorkspaceNavigationController()
      ..updateSession('account-one')
      ..selectRootTab(1);
    await tester.pumpWidget(_host(navigation));
    navigation.navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (context) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Keep unsaved changes'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep editing'),
                  ),
                ],
              ),
            );
          },
          // Even accidental inclusion on an editor must respect its guard.
          child: _detail('Editor'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Keep unsaved changes'), findsOneWidget);
    expect(navigation.selectedIndex, 1);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNWidgets(2));
    expect(navigation.selectedIndex, 1);
    await tester.pumpWidget(const SizedBox());
    navigation.dispose();
  });

  testWidgets('editors can explicitly omit the shared bottom bar', (
    tester,
  ) async {
    final navigation = WorkspaceNavigationController()
      ..updateSession('account-one');
    await tester.pumpWidget(_host(navigation));
    navigation.navigatorKey.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => _detail('Editor', enabled: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    navigation.dispose();
  });

  testWidgets(
    'a real dirty form retains its draft when tab navigation is cancelled',
    (tester) async {
      final navigation = WorkspaceNavigationController()
        ..updateSession('account-one')
        ..selectRootTab(1);
      await tester.pumpWidget(_host(navigation));
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: DataFormScreen(
              title: 'Save calculation',
              fields: const [DataField('title', 'Title', required: true)],
              save: (_) async {},
            ),
            bottomNavigationBar: const WorkspaceBottomBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Unsent draft');
      await tester.pump();
      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppStrings('fr').text('Discard unsaved changes?')),
        findsOneWidget,
      );
      expect(navigation.selectedIndex, 1);
      await tester.tap(find.text('Continuer à modifier'));
      await tester.pumpAndSettle();
      expect(find.text('Unsent draft'), findsOneWidget);
      expect(navigation.selectedIndex, 1);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
    },
  );

  testWidgets('session boundaries remove private routes and reset the tab', (
    tester,
  ) async {
    final navigation = WorkspaceNavigationController()
      ..updateSession('account-one')
      ..selectRootTab(4);
    await tester.pumpWidget(_host(navigation));
    navigation.navigatorKey.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => _detail('Private account-one content')),
    );
    await tester.pumpAndSettle();
    final oldNavigatorKey = navigation.navigatorKey;
    navigation.updateSession(null);
    await tester.pumpAndSettle();
    expect(find.text('Private account-one content'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(navigation.selectedIndex, 0);
    expect(navigation.navigatorKey, isNot(same(oldNavigatorKey)));
    navigation.updateSession('account-two');
    await tester.pumpAndSettle();
    expect(find.text('Tab 0'), findsOneWidget);
    expect(navigation.navigatorKey.currentState!.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
    navigation.dispose();
  });

  testWidgets('community readers keep tabs but the post editor has none', (
    tester,
  ) async {
    final api = RecordingApi()..responses['/api/community/posts'] = [];
    final navigation = WorkspaceNavigationController()
      ..updateSession('account-one');
    await tester.pumpWidget(_host(navigation));
    navigation.navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => CommunityScreen(repository: CommunityRepository(api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    final composer = find.text(
      const AppStrings('fr').text('What’s on your mind?'),
    );
    await tester.ensureVisible(composer);
    await tester.tap(composer);
    await tester.pumpAndSettle();
    expect(find.byType(DataFormScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    navigation.dispose();
    api.close();
  });

  testWidgets(
    'saved calculation navigation respects an unsaved calculator below it',
    (tester) async {
      final api = RecordingApi()
        ..responses['/api/grading-scales'] = {
          'gradingScales': [
            {
              'id': 'scale',
              'name': '4.0',
              'maximumGpa': 4,
              'bands': [
                {'letterGrade': 'A', 'gradePoints': 4, 'minimumPercentage': 85},
                {'letterGrade': 'F', 'gradePoints': 0, 'minimumPercentage': 0},
              ],
            },
          ],
        }
        ..responses['/api/academic'] = {
          'courses': [],
          'assessments': [],
          'deadlines': [],
          'degreePlan': null,
        };
      final navigation = WorkspaceNavigationController()
        ..updateSession('account-one')
        ..selectRootTab(3);
      await tester.pumpWidget(_host(navigation));
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => GpaToolsScreen(repository: AcademicsRepository(api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Unsent course');
      await tester.pumpAndSettle();
      final historyLabel = find.text(
        const AppStrings('fr').text('Saved calculations'),
      );
      await tester.scrollUntilVisible(
        historyLabel,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(historyLabel);
      await tester.pumpAndSettle();
      await tester.tap(historyLabel);
      await tester.pumpAndSettle();
      expect(find.byType(CalculationHistoryScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppStrings('fr').text('Discard unsaved changes?')),
        findsOneWidget,
      );
      expect(navigation.selectedIndex, 3);
      await tester.tap(find.text(const AppStrings('fr').text('Cancel')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      expect(find.text('Unsent course'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      api.close();
    },
  );

  testWidgets('detail bottom bar is hidden without the app scope', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _detail('Independent detail')));
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
    'app keeps visited discover state but discards it after sign-out',
    (tester) async {
      final api = RecordingApi();
      api.responses['/api/auth/session'] = {
        'user': {'id': 'one', 'email': 'one@example.test'},
      };
      api.responses['/api/me'] = {
        'user': {
          'id': 'one',
          'firstName': 'One',
          'lastName': 'Student',
          'institution': 'College',
          'program': 'Computer Science',
          'year': '2nd year',
          'citizenship': 'citizen',
          'interests': ['Computer Science'],
          'opportunityTypes': ['scholarship'],
        },
      };
      api.responses['/api/matches'] = {
        'matches': [],
        'profile': {'status': 'complete', 'firstName': 'One'},
      };
      api.responses['/api/tracking'] = [];
      final dependencies = recordingDependencies(api);
      await tester.pumpWidget(MyOccasioApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final shell = tester.widget<MainShell>(find.byType(MainShell));
      final shellContext = tester.element(find.byType(MainShell));
      final navigation = WorkspaceNavigationScope.maybeOf(shellContext)!;
      navigation.selectRootTab(1);
      await tester.pumpAndSettle();
      final discoverElement = tester.element(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'account-one query');
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => _detail('Detail')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(TextField).first),
        same(discoverElement),
      );
      expect(find.text('account-one query'), findsOneWidget);
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => _detail('Private detail')),
      );
      await tester.pumpAndSettle();
      await shell.sessionController.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Private detail'), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
      api.responses['/api/auth/session'] = {
        'user': {'id': 'two', 'email': 'two@example.test'},
      };
      await shell.sessionController.initialize();
      await tester.pumpAndSettle();
      final newShellContext = tester.element(find.byType(MainShell));
      final newNavigation = WorkspaceNavigationScope.maybeOf(newShellContext)!;
      expect(newNavigation.selectedIndex, 0);
      newNavigation.selectRootTab(1);
      await tester.pumpAndSettle();
      expect(find.text('account-one query'), findsNothing);
      expect(
        tester.element(find.byType(TextField).first),
        isNot(same(discoverElement)),
      );
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
