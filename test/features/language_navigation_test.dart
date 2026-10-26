import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/app.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/features/navigation/presentation/main_shell.dart';
import '../support/recording_api.dart';
import '../support/recording_dependencies.dart';

void main() {
  testWidgets(
    'app restores French and changing language keeps the existing auth state',
    (tester) async {
      final api = RecordingApi();
      final language = LanguageController(read: () async => 'fr');
      final dependencies = recordingDependencies(api, language: language);
      await tester.pumpWidget(MyOccasioApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.text('Commencer'), findsOneWidget);
      expect(
        api.calls.where((call) => call.path == '/api/auth/session').length,
        1,
      );
      await language.setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(
        api.calls.where((call) => call.path == '/api/auth/session').length,
        1,
      );
      await tester.pumpWidget(const SizedBox());
      api.close();
      language.dispose();
    },
  );
  testWidgets(
    'French navigation preserves profile names and refreshes them after editing',
    (tester) async {
      final api = RecordingApi();
      final profile = <String, dynamic>{
        'id': 'one',
        'firstName': 'Save',
        'lastName': 'Home',
        'institution': 'English College',
        'program': 'Computer Science',
        'year': '2nd year',
        'citizenship': 'citizen',
        'interests': ['Computer Science'],
        'opportunityTypes': ['scholarship'],
      };
      api.responses['/api/me'] = {'user': profile};
      api.responses['/api/matches'] = {
        'matches': [],
        'profile': {'status': 'complete', 'firstName': 'Save'},
      };
      api.responses['/api/tracking'] = [];
      final dependencies = recordingDependencies(api);
      final controller = AppSessionController(dependencies.auth);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MainShell(
            dependencies: dependencies,
            sessionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accueil'), findsOneWidget);
      expect(find.text('Découvrir'), findsOneWidget);
      await tester.tap(find.byTooltip('Ouvrir le menu'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      profile['firstName'] = 'Settings';
      api.responses['/api/matches'] = {
        'matches': [],
        'profile': {'status': 'complete', 'firstName': 'Settings'},
      };
      await dependencies.profile.updateProfile({'firstName': 'Settings'});
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Paramètres'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      api.close();
    },
  );
}
