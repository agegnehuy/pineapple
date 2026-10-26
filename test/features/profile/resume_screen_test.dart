import 'dart:async';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/profile_resume.dart';
import 'package:myoccasio/features/profile/presentation/resume_screen.dart';
import '../../support/recording_api.dart';
import '../../core/localization/app_localization_test.dart' show showFrench;

const stored = ProfileResume(
  name: 'previous.pdf',
  mimeType: 'application/pdf',
  size: 4,
);
final pdf = XFile.fromData(
  Uint8List.fromList([37, 80, 68, 70]),
  path: 'new.pdf',
  name: 'new.pdf',
);

class ResumeFixture extends ProfileRepository {
  ResumeFixture(super.api);
  ProfileResume? resume;
  Object? failure;
  Object? uploadFailure;
  bool commitBeforeUploadFailure = false;
  Completer<void>? pending;
  Completer<void>? pendingRead;
  Completer<void>? pendingDownload;
  int uploads = 0;
  int removals = 0;
  int reads = 0;
  int downloads = 0;
  @override
  Future<ProfileResume?> getResume() async {
    reads++;
    if (pendingRead != null) await pendingRead!.future;
    if (failure != null) throw failure!;
    return resume;
  }

  @override
  Future<ProfileResume> saveResume(String name, List<int> bytes) async {
    uploads++;
    if (pending != null) await pending!.future;
    final uploaded = ProfileResume(
      name: name,
      mimeType: 'application/pdf',
      size: bytes.length,
    );
    if (uploadFailure != null) {
      if (commitBeforeUploadFailure) resume = uploaded;
      throw uploadFailure!;
    }
    return resume = uploaded;
  }

  @override
  Future<void> removeResume() async {
    removals++;
    if (failure != null) throw failure!;
    resume = null;
  }

  @override
  Future<Uint8List> downloadResume() async =>
      Uint8List.fromList([37, 80, 68, 70]);
  @override
  Future<({String name, String mimeType, Uint8List bytes})>
  downloadResumeFile() async {
    downloads++;
    if (pendingDownload != null) await pendingDownload!.future;
    return (
      name: resume!.name,
      mimeType: resume!.mimeType,
      bytes: await downloadResume(),
    );
  }
}

Future<void> makeVisible(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(ResumeScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    // ResumeScreen uses a lazy list. Begin from the top so retry controls above
    // the selected-file card can also be found after a failed upload.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  final target = find.text(label);
  await makeVisible(tester, target);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  late RecordingApi api;
  late ResumeFixture repository;
  setUp(() {
    api = RecordingApi();
    repository = ResumeFixture(api);
  });
  tearDown(() {
    repository.dispose();
    api.close();
  });
  Future<void> show(WidgetTester tester, {XFile? file}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResumeScreen(
          repository: repository,
          pickDocument: () async => file ?? pdf,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRoute(
    WidgetTester tester, {
    WidgetBuilder? screenBuilder,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder:
                      screenBuilder ??
                      (_) => ResumeScreen(
                        repository: repository,
                        pickDocument: () async => pdf,
                      ),
                ),
              ),
              child: const Text('Open résumé'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open résumé'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('Back leaves a pending initial metadata read safely', (
    tester,
  ) async {
    repository.pendingRead = Completer<void>();
    await openRoute(tester, settle: false);
    expect(repository.reads, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    repository.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open résumé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back leaves a pending file selection without uploading later', (
    tester,
  ) async {
    final selection = Completer<XFile?>();
    await openRoute(
      tester,
      screenBuilder: (_) => ResumeScreen(
        repository: repository,
        pickDocument: () => selection.future,
      ),
    );
    await tapVisible(tester, 'Choose a résumé', settle: false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    selection.complete(pdf);
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back remains blocked while an upload is pending', (
    tester,
  ) async {
    await openRoute(tester);
    await tapVisible(tester, 'Choose a résumé');
    repository.pending = Completer<void>();
    await tapVisible(tester, 'Save résumé', settle: false);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResumeScreen), findsOneWidget);
    expect(find.text('Discard selected file?'), findsNothing);
    expect(repository.uploads, 1);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back leaves a pending download without opening export later', (
    tester,
  ) async {
    repository.resume = stored;
    repository.pendingDownload = Completer<void>();
    var exports = 0;
    await openRoute(
      tester,
      screenBuilder: (_) => ResumeScreen(
        repository: repository,
        export: (_, _, _) async {
          exports++;
          return false;
        },
      ),
    );
    await tapVisible(tester, 'Save a copy', settle: false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    repository.pendingDownload!.complete();
    await tester.pumpAndSettle();
    expect(exports, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back remains blocked while native export is pending', (
    tester,
  ) async {
    repository.resume = stored;
    final exporting = Completer<bool>();
    await openRoute(
      tester,
      screenBuilder: (_) => ResumeScreen(
        repository: repository,
        export: (_, _, _) => exporting.future,
      ),
    );
    await tapVisible(tester, 'Save a copy', settle: false);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResumeScreen), findsOneWidget);
    exporting.complete(false);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download finishing during route exit never launches export', (
    tester,
  ) async {
    repository.resume = stored;
    repository.pendingDownload = Completer<void>();
    var exports = 0;
    await openRoute(
      tester,
      screenBuilder: (_) => ResumeScreen(
        repository: repository,
        export: (_, _, _) async {
          exports++;
          return false;
        },
      ),
    );
    await tapVisible(tester, 'Save a copy', settle: false);
    await tester.pageBack();
    await tester.pump();
    // The outgoing route is still mounted until its exit animation completes.
    expect(find.byType(ResumeScreen, skipOffstage: false), findsOneWidget);
    repository.pendingDownload!.complete();
    await tester.pumpAndSettle();
    expect(exports, 0);
    expect(find.byType(ResumeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a selected draft can be discarded during metadata reload', (
    tester,
  ) async {
    await openRoute(tester);
    await tapVisible(tester, 'Choose a résumé');
    repository.uploadFailure = const ApiException('Upload response lost');
    repository.failure = const ApiException('Metadata offline');
    await tapVisible(tester, 'Save résumé');
    repository.failure = null;
    repository.pendingRead = Completer<void>();
    await tapVisible(tester, 'Retry', settle: false);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Discard selected file?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    repository.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(repository.uploads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selection requires explicit save, retains failed file and prevents duplicate uploads',
    (tester) async {
      await show(tester);
      await tapVisible(tester, 'Choose a résumé');
      expect(repository.uploads, 0);
      repository.uploadFailure = const ApiException('Upload interrupted');
      await tapVisible(tester, 'Save résumé');
      await makeVisible(tester, find.text('Upload interrupted'));
      expect(find.text('Upload interrupted'), findsOneWidget);
      await makeVisible(tester, find.text('new.pdf'));
      expect(find.text('new.pdf'), findsOneWidget);
      repository.uploadFailure = null;
      repository.pending = Completer<void>();
      await tapVisible(tester, 'Save résumé', settle: false);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save résumé'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.uploads, 2);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Résumé saved'), findsOneWidget);
      expect(find.text('Review before you save'), findsNothing);
    },
  );
  testWidgets(
    'replacement and removal are explicit and cancellation preserves saved file',
    (tester) async {
      repository.resume = stored;
      await show(tester);
      await tapVisible(tester, 'Choose replacement');
      await tapVisible(tester, 'Save résumé');
      expect(find.text('Replace saved résumé?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(repository.uploads, 0);
      expect(repository.resume!.name, 'previous.pdf');
      await tapVisible(tester, 'Save résumé');
      await tapVisible(tester, 'Replace résumé');
      expect(repository.uploads, 1);
      await tapVisible(tester, 'Remove résumé', settle: false);
      // The screen remains busy while its destructive confirmation is open.
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.removals, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove résumé'));
      await tester.pumpAndSettle();
      expect(repository.removals, 1);
      await makeVisible(tester, find.text('No résumé saved yet'));
      expect(find.text('No résumé saved yet'), findsOneWidget);
    },
  );
  testWidgets('rapid replacement requests open only one confirmation dialog', (
    tester,
  ) async {
    repository.resume = stored;
    await show(tester);
    await tapVisible(tester, 'Choose replacement');
    final save = find.widgetWithText(FilledButton, 'Save résumé');
    await makeVisible(tester, save);
    // Invoke the callback twice before a frame can disable the rendered button.
    final requestReplacement = tester.widget<FilledButton>(save).onPressed!;
    requestReplacement();
    requestReplacement();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Replace saved résumé?'), findsOneWidget);
    expect(repository.uploads, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.resume, stored);
    expect(repository.uploads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lost upload response reconciles saved metadata and requires confirmation before retry',
    (tester) async {
      await show(tester);
      await tapVisible(tester, 'Choose a résumé');
      repository.uploadFailure = const ApiException('Upload response lost');
      repository.commitBeforeUploadFailure = true;
      await tapVisible(tester, 'Save résumé');
      expect(repository.uploads, 1);
      expect(repository.reads, 2);
      expect(repository.resume!.name, 'new.pdf');
      await makeVisible(tester, find.text('Saved résumé'));
      expect(find.text('Saved résumé'), findsOneWidget);
      expect(find.text('No résumé saved yet'), findsNothing);
      await tapVisible(tester, 'Retry');
      expect(find.text('Replace saved résumé?'), findsOneWidget);
      expect(repository.uploads, 1);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(repository.resume!.name, 'new.pdf');
      expect(repository.uploads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed reconciliation blocks file actions until metadata reload succeeds',
    (tester) async {
      repository.resume = stored;
      await show(tester);
      await tapVisible(tester, 'Choose replacement');
      await tapVisible(tester, 'Save résumé');
      repository.uploadFailure = const ApiException('Upload response lost');
      repository.commitBeforeUploadFailure = true;
      repository.failure = const ApiException('Metadata offline');
      await tapVisible(tester, 'Replace résumé');
      expect(repository.uploads, 1);
      expect(repository.reads, 2);
      for (final label in ['Save a copy', 'Remove résumé', 'Save résumé']) {
        final button = switch (label) {
          'Save a copy' => find.widgetWithText(OutlinedButton, label),
          'Remove résumé' => find.widgetWithText(TextButton, label),
          _ => find.widgetWithText(FilledButton, label),
        };
        await makeVisible(tester, button);
        expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
      }
      expect(repository.downloads, 0);
      expect(repository.removals, 0);
      repository.failure = null;
      await tapVisible(tester, 'Retry');
      expect(repository.reads, 3);
      expect(repository.uploads, 1);
      expect(repository.resume!.name, 'new.pdf');
      final saveCopy = find.widgetWithText(OutlinedButton, 'Save a copy');
      await makeVisible(tester, saveCopy);
      expect(tester.widget<OutlinedButton>(saveCopy).onPressed, isNotNull);
      final save = find.widgetWithText(FilledButton, 'Save résumé');
      await makeVisible(tester, save);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving a selected file requires keep or explicit discard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ResumeScreen(
                    repository: repository,
                    pickDocument: () async => pdf,
                  ),
                ),
              ),
              child: const Text('Open résumé'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open résumé'));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Choose a résumé');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard selected file?'), findsOneWidget);
    expect(repository.uploads, 0);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsOneWidget);
    await makeVisible(tester, find.text('new.pdf'));
    expect(find.text('new.pdf'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeScreen), findsNothing);
    expect(find.text('Open résumé'), findsOneWidget);
    expect(repository.uploads, 0);
    expect(repository.removals, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelling selected file preserves metadata reload retry after uncertain upload',
    (tester) async {
      repository.resume = stored;
      await show(tester);
      await tapVisible(tester, 'Choose replacement');
      await tapVisible(tester, 'Save résumé');
      repository.uploadFailure = const ApiException('Upload response lost');
      repository.commitBeforeUploadFailure = true;
      repository.failure = const ApiException('Metadata offline');
      await tapVisible(tester, 'Replace résumé');
      await tapVisible(tester, 'Cancel');
      await makeVisible(tester, find.text('Upload response lost'));
      expect(find.text('Upload response lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(repository.uploads, 1);
      expect(repository.reads, 2);
      repository.failure = null;
      await tapVisible(tester, 'Retry');
      expect(repository.reads, 3);
      expect(repository.uploads, 1);
      expect(find.text('Review before you save'), findsNothing);
      final copy = find.widgetWithText(OutlinedButton, 'Save a copy');
      await makeVisible(tester, copy);
      expect(tester.widget<OutlinedButton>(copy).onPressed, isNotNull);
      expect(repository.resume!.name, 'new.pdf');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported selection never reaches repository, initial read can retry',
    (tester) async {
      repository.failure = const ApiException('Offline');
      await show(
        tester,
        file: XFile.fromData(
          Uint8List(1),
          path: 'notes.txt',
          name: 'notes.txt',
        ),
      );
      expect(find.text('Offline'), findsOneWidget);
      repository.failure = null;
      await tapVisible(tester, 'Retry');
      await tapVisible(tester, 'Choose a résumé');
      await makeVisible(tester, find.text('Choose a PDF or DOCX résumé.'));
      expect(find.text('Choose a PDF or DOCX résumé.'), findsOneWidget);
      expect(repository.uploads, 0);
      expect(repository.reads, 2);
    },
  );
  testWidgets(
    'system save cancellation never reports success and failed export retries',
    (tester) async {
      repository.resume = stored;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResumeScreen(
            repository: repository,
            export: (name, mime, bytes) async {
              expect(name, 'previous.pdf');
              expect(bytes, [37, 80, 68, 70]);
              attempts++;
              if (attempts == 2) {
                throw const ApiException(
                  'Could not save this file. Please try again.',
                );
              }
              return attempts > 2;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Save a copy');
      expect(find.text('Copy saved to your chosen location.'), findsNothing);
      await tapVisible(tester, 'Save a copy');
      await makeVisible(
        tester,
        find.text('Could not save this file. Please try again.'),
      );
      expect(
        find.text('Could not save this file. Please try again.'),
        findsOneWidget,
      );
      await tapVisible(tester, 'Retry');
      expect(find.text('Copy saved to your chosen location.'), findsOneWidget);
      expect(attempts, 3);
    },
  );
  testWidgets(
    'French résumé review fits320 pixels with200 percent text and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.resume = stored;
      await showFrench(
        tester,
        ResumeScreen(repository: repository, pickDocument: () async => pdf),
        scale: 2,
      );
      await tapVisible(tester, 'Choisir un autre fichier');
      await makeVisible(tester, find.text('Enregistrer le CV'));
      expect(tester.takeException(), isNull);
      expect(repository.uploads, 0);
    },
  );
}
