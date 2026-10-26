import 'dart:async';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/application_attachment.dart';
import 'package:myoccasio/features/applications/presentation/application_attachments_screen.dart';
import 'package:myoccasio/features/applications/presentation/application_workspace_screen.dart';
import '../../support/recording_api.dart';
import 'application_attachments_repository_test.dart'
    show attachmentFixture, attachmentLimitsFixture;

class _FilesRepository extends ApplicationsRepository {
  _FilesRepository(super.api);
  List<ApplicationAttachment> files = [];
  int uploads = 0, removals = 0, reads = 0;
  bool uploadFails = false;
  Completer<void>? uploading;
  Completer<({String name, String mimeType, Uint8List bytes})>? downloading;
  @override
  Future<List<ApplicationAttachment>> getAttachments(
    String opportunityId,
  ) async {
    reads++;
    return List.of(files);
  }

  @override
  Future<ApplicationAttachment> uploadAttachment(
    String opportunityId,
    String name,
    List<int> bytes,
  ) async {
    uploads++;
    if (uploading != null) await uploading!.future;
    if (uploadFails) throw const ApiException('Upload failed.');
    final file = ApplicationAttachment.fromJson(attachmentFixture(name: name));
    files = [file];
    return file;
  }

  @override
  Future<void> removeAttachment(
    String opportunityId,
    String attachmentId,
  ) async {
    removals++;
    files.removeWhere((file) => file.id == attachmentId);
  }

  @override
  Future<({String name, String mimeType, Uint8List bytes})> downloadAttachment(
    String opportunityId,
    String attachmentId, {
    bool submitted = false,
  }) async => downloading == null
      ? (
          name: 'Newest.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList([0, 255, 42]),
        )
      : await downloading!.future;
}

class _ChangedFilesApi extends RecordingApi {
  @override
  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
  }) async {
    final response = await super.request(
      method,
      path,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
    );
    if (method == 'POST' && path == '/api/applications/catalogue') {
      responses[path]['attachments'] = [
        attachmentFixture(id: 'new-private', name: 'Changed.pdf'),
      ];
      throw const ApiException(
        'The supporting documents changed. Review them again before submitting.',
        statusCode: 409,
      );
    }
    return response;
  }
}

void main() {
  late RecordingApi api;
  late _FilesRepository repository;
  setUp(() {
    api = RecordingApi();
    repository = _FilesRepository(api);
  });
  tearDown(() {
    repository.dispose();
    api.close();
  });

  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    DocumentPicker? picker,
    DocumentExporter? exporter,
    bool french = false,
    bool submitted = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(french ? 2 : 1)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ApplicationAttachmentsScreen(
                    repository: repository,
                    opportunityId: 'cat:catalogue',
                    limits: ApplicationAttachmentLimits.supported(
                      attachmentLimitsFixture,
                    )!,
                    submittedAttachments: submitted ? repository.files : null,
                    pickDocument:
                        picker ??
                        () async => XFile.fromData(
                          Uint8List.fromList([1, 2, 3, 4]),
                          path: 'Proof.pdf',
                          name: 'Proof.pdf',
                        ),
                    export: exporter ?? (_, _, _) async => false,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'file selection is private, cancellable, retained on failure and retried only explicitly',
    (tester) async {
      await open(tester);
      await tap(tester, 'Choose document');
      expect(repository.uploads, 0);
      await tap(tester, 'Cancel');
      expect(find.text('Review selected file'), findsNothing);
      await tap(tester, 'Choose document');
      repository.uploadFails = true;
      await tap(tester, 'Upload privately');
      expect(repository.uploads, 1);
      expect(find.text('Upload failed.'), findsOneWidget);
      expect(find.text('Review selected file'), findsOneWidget);
      repository.uploadFails = false;
      await tap(tester, 'Retry');
      expect(repository.uploads, 2);
      expect(find.text('Review selected file'), findsNothing);
      expect(find.text('Proof.pdf'), findsOneWidget);
    },
  );

  testWidgets(
    'pending upload blocks Back and removal requires explicit confirmation',
    (tester) async {
      await open(tester);
      await tap(tester, 'Choose document');
      repository.uploading = Completer<void>();
      await tester.scrollUntilVisible(
        find.text('Upload privately'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Upload privately'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload privately'));
      await tester.pump();
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ApplicationAttachmentsScreen), findsOneWidget);
      repository.uploading!.complete();
      await tester.pumpAndSettle();
      await tap(tester, 'Remove document');
      expect(repository.removals, 0);
      await tap(tester, 'Cancel');
      expect(repository.removals, 0);
      await tap(tester, 'Remove document');
      await tap(tester, 'Remove document');
      expect(repository.removals, 1);
      expect(find.text('No supporting documents'), findsOneWidget);
    },
  );

  testWidgets(
    'three files disable additions and submitted snapshots expose no mutations',
    (tester) async {
      repository.files = [
        for (var i = 0; i < 3; i++)
          ApplicationAttachment.fromJson(
            attachmentFixture(id: '$i', name: '$i.pdf'),
          ),
      ];
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('Choose document'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Choose document'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      repository.reads = 0;
      await open(tester, submitted: true);
      expect(repository.reads, 0);
      expect(find.text('Choose document'), findsNothing);
      expect(find.text('Remove document'), findsNothing);
    },
  );

  testWidgets(
    'export uses downloaded metadata, blocks Back during the system picker and handles cancellation',
    (tester) async {
      repository.files = [ApplicationAttachment.fromJson(attachmentFixture())];
      final exported = Completer<bool>();
      String? savedName;
      await open(
        tester,
        exporter: (name, mime, bytes) {
          savedName = name;
          expect(mime, 'application/pdf');
          expect(bytes, [0, 255, 42]);
          return exported.future;
        },
      );
      await tester.tap(find.text('Save a copy'));
      await tester.pump();
      expect(savedName, 'Newest.pdf');
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ApplicationAttachmentsScreen), findsOneWidget);
      exported.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Copy saved to your chosen location.'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'a read-only download permits Back and never opens an exporter after leaving',
    (tester) async {
      repository.files = [ApplicationAttachment.fromJson(attachmentFixture())];
      repository.downloading =
          Completer<({String name, String mimeType, Uint8List bytes})>();
      var exports = 0;
      await open(
        tester,
        exporter: (_, _, _) async {
          exports++;
          return true;
        },
      );
      await tester.tap(find.text('Save a copy'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      repository.downloading!.complete((
        name: 'Evidence.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList([1]),
      ));
      await tester.pumpAndSettle();
      expect(exports, 0);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'large French attachment cards fit a narrow viewport without translating names',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.files = [
        ApplicationAttachment.fromJson(
          attachmentFixture(
            name: 'Save Settings original supporting document.pdf',
          ),
        ),
      ];
      await open(tester, french: true);
      await tester.scrollUntilVisible(
        find.text('Save Settings original supporting document.pdf'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old production capability makes no attachment calls', (
    tester,
  ) async {
    api.responses['/api/applications/catalogue'] = {
      'opportunity': {'title': 'Real opportunity'},
      'submissionMode': 'internal',
      'draft': {'statement': 'My statement'},
      'submission': null,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationWorkspaceScreen(
          repository: ApplicationsRepository(api),
          opportunityId: 'cat:catalogue',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Document attachments are not supported'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Manage supporting documents'), findsNothing);
    expect(api.calls.map((call) => call.path), ['/api/applications/catalogue']);
  });

  testWidgets(
    'submission requires an explicit review and sends private IDs rather than snapshot IDs',
    (tester) async {
      api.responses['/api/applications/catalogue'] = {
        'opportunity': {'title': 'Real opportunity'},
        'submissionMode': 'internal',
        'draft': {'statement': 'My statement'},
        'submission': null,
        'attachmentLimits': attachmentLimitsFixture,
        'attachments': [attachmentFixture(id: 'private-one')],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationWorkspaceScreen(
            repository: ApplicationsRepository(api),
            opportunityId: 'cat:catalogue',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Review & submit');
      expect(find.text('Evidence.pdf (1 KB)'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm submission'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tap(tester, 'Confirm submission');
      expect(api.calls.where((call) => call.method == 'POST').single.body, {
        'confirmation': true,
        'attachmentIds': ['private-one'],
      });
    },
  );

  testWidgets(
    'changed supporting documents force a fresh review without resubmitting automatically',
    (tester) async {
      final changedApi = _ChangedFilesApi();
      changedApi.responses['/api/applications/catalogue'] = {
        'opportunity': {'title': 'Real opportunity'},
        'submissionMode': 'internal',
        'draft': {'statement': 'My statement'},
        'submission': null,
        'attachmentLimits': attachmentLimitsFixture,
        'attachments': [attachmentFixture(id: 'old-private')],
      };
      final changedRepository = ApplicationsRepository(changedApi);
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationWorkspaceScreen(
            repository: changedRepository,
            opportunityId: 'cat:catalogue',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Review & submit');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tap(tester, 'Confirm submission');
      expect(
        changedApi.calls.where((call) => call.method == 'POST'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, 'Review & submit');
      expect(find.text('Changed.pdf (1 KB)'), findsOneWidget);
      expect(find.text('Evidence.pdf (1 KB)'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm submission'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      changedRepository.dispose();
      changedApi.close();
    },
  );

  testWidgets(
    'rapid review triggers open one confirmation and cancellation restores actions',
    (tester) async {
      api.responses['/api/applications/catalogue'] = {
        'opportunity': {'title': 'Real opportunity'},
        'submissionMode': 'internal',
        'draft': {'statement': 'My statement'},
        'submission': null,
      };
      final workspaceRepository = ApplicationsRepository(api);
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationWorkspaceScreen(
            repository: workspaceRepository,
            opportunityId: 'cat:catalogue',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review & submit'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final review = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Review & submit'),
          )
          .onPressed!;
      review();
      review();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Edit statement'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review & submit'),
            )
            .onPressed,
        isNotNull,
      );
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      workspaceRepository.dispose();
    },
  );
}
