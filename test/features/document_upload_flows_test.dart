import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/presentation/import_profile_screen.dart';
import '../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());
  XFile sample() => XFile.fromData(
    Uint8List.fromList('Resume text'.codeUnits),
    name: 'resume.txt',
    path: 'resume.txt',
  );
  test(
    'cancelled file selection and oversized files are handled before any upload',
    () async {
      expect(await readSelectedDocument(() async => null), isNull);
      await expectLater(
        readSelectedDocument(
          () async => XFile.fromData(
            Uint8List(maxDocumentBytes + 1),
            name: 'large.pdf',
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        readSelectedDocument(
          () async => XFile.fromData(Uint8List(0), name: 'empty.txt'),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
  testWidgets('resume upload does not apply any profile field before review', (
    tester,
  ) async {
    api.responses['/api/profile/import'] = {
      'suggestions': [
        {
          'field': 'program',
          'value': 'Computer Science',
          'conflict': true,
          'current': 'Biology',
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ImportProfileScreen(
          repository: ProfileRepository(api),
          pickDocument: () async => sample(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Choose résumé file · up to 4 MB'));
    await tester.tap(find.text('Choose résumé file · up to 4 MB'));
    await tester.pumpAndSettle();
    expect(api.calls.single.path, '/api/profile/import');
    expect(api.calls.where((c) => c.method == 'PATCH'), isEmpty);
    await tester.scrollUntilVisible(
      find.text('Apply this field'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Apply this field'));
    await tester.pumpAndSettle();
    expect(find.text('Replace this profile field?'), findsOneWidget);
    expect(api.calls.where((c) => c.method == 'PATCH'), isEmpty);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(api.calls.last.path, '/api/me');
    expect(api.calls.last.body, {'program': 'Computer Science'});
  });
  testWidgets(
    'coach attaches a real upload reference only to the explicit question',
    (tester) async {
      api.responses['/api/ai/uploads'] = {
        'upload': {'id': 'upload-1', 'fileName': 'resume.txt'},
      };
      api.responses['/api/ai/coach'] = {
        'summary': 'Server guidance',
        'plan': [],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CoachScreen(
              repository: CoachingRepository(api),
              pickDocument: () async => sample(),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Attach document'));
      await tester.pumpAndSettle();
      expect(api.calls.single.path, '/api/ai/uploads');
      expect(find.byType(InputChip), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Review this document');
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(api.calls.last.body['attachmentIds'], ['upload-1']);
      expect(find.byType(InputChip), findsNothing);
    },
  );
  testWidgets(
    'picker failure is recoverable without losing pasted resume text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ImportProfileScreen(
            repository: ProfileRepository(api),
            pickDocument: () async =>
                throw StateError('Fixture platform failure'),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      await tester.ensureVisible(find.text('Choose résumé file · up to 4 MB'));
      await tester.tap(find.text('Choose résumé file · up to 4 MB'));
      await tester.pumpAndSettle();
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(
        find.text('Could not read this file. Try pasting its text instead.'),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
    },
  );
}
