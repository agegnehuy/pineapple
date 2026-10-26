import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/settings_screen.dart';

import '../../support/recording_api.dart';

void main() {
  testWidgets(
    'settings shows the selected language and theme without backend requests',
    (tester) async {
      final api = RecordingApi();
      final appearance = AppearanceController();
      final language = LanguageController();
      await language.setLanguage('fr');
      await appearance.setMode(ThemeMode.dark);
      addTearDown(api.close);
      addTearDown(appearance.dispose);
      addTearDown(language.dispose);
      var profileOpened = false;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: SettingsScreen(
            repository: SettingsRepository(api),
            appearance: appearance,
            language: language,
            email: 'student@example.test',
            onSignOut: () async {},
            onProfile: () => profileOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Votre espace. Vos choix.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Profil et études'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Profil et études'));
      expect(profileOpened, isTrue);
      await tester.scrollUntilVisible(
        find.text('Français · Sombre'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Français · Sombre'), findsOneWidget);
      // Keep the host's Theme and Locale fixed: the row must listen to the
      // selected preferences even when the effective system theme is unchanged.
      await appearance.setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(find.text('Français · Clair'), findsOneWidget);
      await language.setLanguage('en');
      await tester.pumpAndSettle();
      expect(
        find.text('${const AppStrings('fr').text('English')} · Clair'),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
