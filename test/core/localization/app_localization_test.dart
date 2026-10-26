import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/auth/presentation/welcome_screen.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/profile/presentation/onboarding_screen.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_card.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/presentation/edit_profile_screen.dart';
import 'package:myoccasio/features/settings/presentation/appearance_screen.dart';
import '../../support/recording_api.dart';

const delegates = <LocalizationsDelegate<dynamic>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
Future<void> showFrench(
  WidgetTester tester,
  Widget page, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: delegates,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'French sign-in validates locally and exposes translated password controls',
    (tester) async {
      final api = RecordingApi();
      final controller = AppSessionController(
        AuthRepository(api, MemoryCookieStore()),
      );
      await showFrench(
        tester,
        SignInScreen(sessionController: controller, onCreateAccount: () {}),
      );
      await tester.enterText(find.byType(TextFormField).first, 'invalid');
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saisissez une adresse courriel valide.'),
        findsOneWidget,
      );
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
      expect(api.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      api.close();
    },
  );
  testWidgets(
    'French profile and interest onboarding fit 320 pixels at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = RecordingApi();
      final profile = UserProfile.fromJson({
        'firstName': 'Save',
        'lastName': 'Home',
        'institution': 'English College',
        'program': 'Computer Science',
        'year': '2nd year',
        'citizenship': 'citizen',
        'interests': ['Computer Science'],
        'opportunityTypes': ['scholarship'],
      });
      await showFrench(
        tester,
        EditProfileScreen(profile: profile, repository: ProfileRepository(api)),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Enregistrer le profil'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await showFrench(
        tester,
        OnboardingScreen(profile: profile, repository: ProfileRepository(api)),
        scale: 2,
      );
      await tester.scrollUntilVisible(
        find.text('Continuer'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Voir mes recommandations'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(api.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  test(
    'language persists and a late read does not replace a new choice',
    () async {
      String? saved;
      final first = LanguageController(write: (value) async => saved = value);
      await first.setLanguage('fr');
      final restored = LanguageController(read: () async => saved);
      await restored.initialize();
      expect(restored.code, 'fr');
      final delayed = Completer<String?>();
      final controller = LanguageController(read: () => delayed.future);
      final pending = controller.initialize();
      await controller.setLanguage('fr');
      delayed.complete('en');
      await pending;
      expect(controller.code, 'fr');
      await expectLater(
        controller.setLanguage('unsupported'),
        throwsArgumentError,
      );
      first.dispose();
      restored.dispose();
      controller.dispose();
    },
  );
  test('UI copy and canonical selection labels have French translations', () {
    final known = AppStrings.french.keys.map((v) => v.toLowerCase()).toSet();
    final missing = <String>{};
    final patterns = [
      RegExp(r"AppText\(\s*'((?:\\.|[^'\\])*)'"),
      RegExp(r"AppStrings\.tr\(\s*context,\s*'((?:\\.|[^'\\])*)'"),
      RegExp(
        r"(?:DataField\(\s*'[^']*'\s*,\s*|(?:title|description|message|label|requiredMessage|submitLabel):\s*)'((?:\\.|[^'\\])*)'",
      ),
    ];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.contains('localization')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          final text = match[1]!.replaceAll(r'\n', '\n').replaceAll(r"\'", "'");
          if (text.contains(r'$') ||
              !RegExp('[A-Za-z]').hasMatch(text) ||
              text == 'MyOccasio') {
            continue;
          }
          if (!known.contains(text.toLowerCase())) missing.add(text);
        }
      }
      for (final block in RegExp(
        r'(?:options:\s*(?:const\s*)?|const\s+\w*(?:Options|Fields|Labels)\s*=\s*|const\s*)\{([^{}]+)\}(?:\.entries)?',
      ).allMatches(source)) {
        for (final match in RegExp(
          r":\s*'((?:\\.|[^'\\])*)'",
        ).allMatches(block[1]!)) {
          final label = match[1]!;
          if (!label.contains(r'$') &&
              RegExp('[A-Za-z]').hasMatch(label) &&
              !known.contains(label.toLowerCase())) {
            missing.add(label);
          }
        }
      }
    }
    for (final label in [
      ...matchingInterests,
      ...studyYears,
      ...citizenshipOptions.values,
      ...opportunityTypeOptions.values,
      ...importedProfileLabels.values,
    ]) {
      if (!known.contains(label.toLowerCase())) missing.add(label);
    }
    expect(
      missing,
      isEmpty,
      reason: 'Add reviewed French copy for these interface labels.',
    );
  });
  test('French formatting keeps names and imported values intact', () {
    const strings = AppStrings('fr');
    expect(strings.text('A little closer, Save.'), 'Un peu plus près, Save.');
    expect(strings.text('Show 1 opportunities'), 'Afficher 1 possibilité');
    expect(strings.text('90% match'), '90 % de compatibilité');
    expect(strings.text('Replaces: Save'), 'Remplace : Save');
    expect(
      strings.text('Replaces: Save\n\nSettings'),
      'Remplace : Save\n\nSettings',
    );
    expect(
      strings.text('2026-10-22\nSave\n\nSettings'),
      '2026-10-22\nSave\n\nSettings',
    );
  });
  testWidgets(
    'welcome and locale-formatted dates and decimals render in French',
    (tester) async {
      var started = false;
      await showFrench(
        tester,
        WelcomeScreen(onSignIn: () {}, onCreateAccount: () => started = true),
      );
      expect(
        find.text('Plus de possibilités.\nMoins de recherches.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Commencer'));
      await tester.tap(find.text('Commencer'));
      expect(started, isTrue);
      await showFrench(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                Text(formatDecimal(context, 3.75)),
                Text(formatDashboardDate(context, DateTime(2026, 10, 22))),
              ],
            ),
          ),
        ),
      );
      expect(find.text('3,75'), findsOneWidget);
      expect(find.textContaining('OCTOBRE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'French interface does not translate a provider title or user text',
    (tester) async {
      await showFrench(
        tester,
        Scaffold(
          body: Column(
            children: [
              const Text('Save'),
              const AppText('Save'),
              OpportunityCard(
                opportunity: Opportunity.fromJson({
                  'id': 'cat:one',
                  'title': 'Save',
                  'org': 'English College',
                  'match': 90,
                }),
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('Save'), findsNWidgets(2));
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(
        find.textContaining('English College', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('90 % de compatibilité'), findsOneWidget);
    },
  );
  testWidgets(
    'decimal commas are normalized for numeric fields and text remains unchanged',
    (tester) async {
      Map<String, String>? saved;
      await showFrench(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DataFormScreen(
                    title: 'Add course',
                    fields: [
                      DataField(
                        'credits',
                        'Credits',
                        numeric: true,
                        required: true,
                        validate: (v) => validateNumber(v, min: 0.01, max: 60),
                      ),
                      const DataField('notes', 'Notes'),
                    ],
                    save: (values) async => saved = values,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '3,5');
      await tester.enterText(find.byType(TextFormField).last, 'Save, Home');
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(saved, {'credits': '3.5', 'notes': 'Save, Home'});
    },
  );
  testWidgets('offscreen required data is validated before any mutation', (
    tester,
  ) async {
    var writes = 0;
    await showFrench(
      tester,
      DataFormScreen(
        title: 'Add course',
        fields: [
          for (var i = 0; i < 20; i++)
            DataField('field$i', 'Title', required: true),
        ],
        initial: {for (var i = 1; i < 20; i++) 'field$i': 'Filled'},
        save: (_) async => writes++,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('Veuillez saisir'), findsWidgets);
  });
  testWidgets('French profile selections save canonical backend keys', (
    tester,
  ) async {
    final api = RecordingApi();
    final profile = UserProfile.fromJson({
      'id': 'one',
      'firstName': 'Save',
      'lastName': 'Home',
      'email': 'test@example.test',
      'institution': 'English College',
      'program': 'Computer Science',
      'year': '2nd year',
      'citizenship': 'citizen',
      'interests': ['Computer Science'],
      'opportunityTypes': ['scholarship'],
    });
    await showFrench(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(
                  profile: profile,
                  repository: ProfileRepository(api),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Stages'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Stages'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enregistrer le profil'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer le profil'));
    await tester.pumpAndSettle();
    final body = api.calls.single.body as Map<String, dynamic>;
    expect(body['opportunityTypes'], ['scholarship', 'internship']);
    expect(body['interests'], ['Computer Science']);
    expect(body['firstName'], 'Save');
    expect(body['institution'], 'English College');
    api.close();
  });
  testWidgets(
    'language storage failure retains the choice and retry switches the interface',
    (tester) async {
      var fail = true;
      final language = LanguageController(
        write: (_) async {
          if (fail) throw StateError('storage');
        },
      );
      final appearance = AppearanceController();
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: language,
          builder: (context, _) => MaterialApp(
            locale: Locale(language.code),
            supportedLocales: const [Locale('en'), Locale('fr')],
            localizationsDelegates: delegates,
            theme: AppTheme.light,
            home: AppearanceScreen(controller: appearance, language: language),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(language.code, 'en');
      fail = false;
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(find.text('Langue et apparence'), findsOneWidget);
      expect(language.code, 'fr');
      language.dispose();
      appearance.dispose();
    },
  );
}
