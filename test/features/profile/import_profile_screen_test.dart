import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/presentation/edit_profile_screen.dart';
import 'package:myoccasio/features/profile/presentation/import_profile_screen.dart';

import '../../support/recording_api.dart';

void main() {
  late RecordingApi api;
  late _ImportRepository repository;

  setUp(() {
    api = RecordingApi();
    repository = _ImportRepository(api);
  });
  tearDown(() {
    repository.dispose();
    api.close();
  });

  Future<void> open(
    WidgetTester tester, {
    DocumentPicker? picker,
    bool french = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ImportProfileScreen(
                    repository: repository,
                    pickDocument: picker ?? _document,
                  ),
                ),
              ),
              child: const Text('Open import'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();
  }

  Future<void> upload(WidgetTester tester) async {
    await tester.tap(find.text('Upload a résumé'));
    await tester.pumpAndSettle();
    expect(repository.imports, 1);
  }

  Future<void> showApply(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Apply this field'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Apply this field'));
    await tester.pumpAndSettle();
  }

  testWidgets('an untouched import can leave without creating a request', (
    tester,
  ) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
    expect(find.text('Discard this import?'), findsNothing);
    expect(repository.imports, 0);
    expect(repository.writes, isEmpty);
  });

  testWidgets('pasted text survives cancelled Back and discards explicitly', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'My unsaved experience');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this import?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('My unsaved experience'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
    expect(repository.imports, 0);
    expect(repository.writes, isEmpty);
  });

  testWidgets('the LinkedIn text card reveals and focuses the manual editor', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Paste LinkedIn details'));
    await tester.tap(find.text('Paste LinkedIn details'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThanOrEqualTo(kToolbarHeight),
    );
    expect(repository.imports, 0);
    expect(repository.writes, isEmpty);
  });

  testWidgets(
    'file suggestions require review and protect an unapplied field',
    (tester) async {
      await open(tester);
      await upload(tester);
      expect(repository.writes, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard this import?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await showApply(tester);
      expect(find.text('Replace this profile field?'), findsOneWidget);
      expect(repository.writes, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(find.text('Apply this field'), findsOneWidget);
    },
  );

  testWidgets(
    'a confirmed field write blocks Back until persistence completes',
    (tester) async {
      repository.pendingWrite = Completer<void>();
      await open(tester);
      await upload(tester);
      await showApply(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();
      expect(repository.writes, [
        {'program': 'Computer Science'},
      ]);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ImportProfileScreen), findsOneWidget);
      expect(find.text('Discard this import?'), findsNothing);
      repository.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Applied'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open import'), findsOneWidget);
      expect(repository.writes, hasLength(1));
    },
  );

  testWidgets('discarding pasted text can leave while extraction is pending', (
    tester,
  ) async {
    repository.pendingImport = Completer<List<Map<String, dynamic>>>();
    await open(tester);
    await tester.enterText(find.byType(TextField), 'My experience');
    await tester.ensureVisible(find.text('Review suggestions'));
    await tester.tap(find.text('Review suggestions'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
    repository.pendingImport!.complete(_suggestions);
    await tester.pumpAndSettle();
    expect(find.byType(ImportProfileScreen), findsNothing);
    expect(repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during document selection never uploads a late file', (
    tester,
  ) async {
    final selected = Completer<XFile?>();
    await open(tester, picker: () => selected.future);
    await tester.tap(find.text('Upload a résumé'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
    selected.complete(await _document());
    await tester.pumpAndSettle();
    expect(repository.imports, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling manual editing preserves the imported suggestions', (
    tester,
  ) async {
    await open(tester);
    await upload(tester);
    await tester.scrollUntilVisible(
      find.text('Enter details myself'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter details myself'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ImportProfileScreen), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);
    expect(repository.writes, isEmpty);
  });

  testWidgets('French import actions fit a narrow screen at double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, french: true, textScale: 2);
    expect(find.text('Vous avez déjà fait beaucoup.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Saisir mes renseignements'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Saisir mes renseignements'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _suggestions = <Map<String, dynamic>>[
  {
    'field': 'program',
    'value': 'Computer Science',
    'current': 'Biology',
    'conflict': true,
  },
];

Future<XFile?> _document() async => XFile.fromData(
  Uint8List.fromList('Resume text'.codeUnits),
  path: 'resume.txt',
  name: 'resume.txt',
);

class _ImportRepository extends ProfileRepository {
  _ImportRepository(super.api);
  int imports = 0;
  final writes = <Map<String, dynamic>>[];
  Completer<void>? pendingWrite;
  Completer<List<Map<String, dynamic>>>? pendingImport;

  @override
  Future<List<Map<String, dynamic>>> suggestImport(String text) async {
    imports++;
    if (pendingImport != null) return pendingImport!.future;
    return _suggestions;
  }

  @override
  Future<List<Map<String, dynamic>>> suggestFileImport(
    String name,
    List<int> bytes,
  ) async {
    imports++;
    return _suggestions;
  }

  @override
  Future<UserProfile> getCurrentUser() async => UserProfile.fromJson({
    'firstName': 'Fixture',
    'lastName': 'Student',
    'institution': 'Fixture University',
    'program': 'Biology',
    'year': '2',
    'citizenship': 'citizen',
    'interests': ['Science'],
    'opportunityTypes': ['scholarship'],
  });

  @override
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    writes.add(fields);
    await pendingWrite?.future;
  }
}
