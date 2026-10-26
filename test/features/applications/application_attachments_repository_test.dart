import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/application_attachment.dart';
import '../../support/recording_api.dart';

Map<String, dynamic> attachmentFixture({
  String id = 'private/one',
  String name = 'Evidence.pdf',
}) => {
  'id': id,
  'fileName': name,
  'mimeType': 'application/pdf',
  'byteSize': 4,
  'createdAt': '2026-10-23T12:00:00Z',
};
const attachmentLimitsFixture = {'maxBytes': 4194304, 'maxCount': 3};

class AttachmentDownloadApi extends RecordingApi {
  ApiDownload download = ApiDownload(
    bytes: Uint8List.fromList([0, 255, 13, 10]),
    filename: 'Current.pdf',
    mimeType: 'application/pdf',
  );
  String? downloadPath;
  int? maxBytes;
  @override
  Future<ApiDownload> getDownload(String path, {required int maxBytes}) async {
    downloadPath = path;
    this.maxBytes = maxBytes;
    return download;
  }
}

void main() {
  late AttachmentDownloadApi api;
  late ApplicationsRepository repository;
  setUp(() {
    api = AttachmentDownloadApi();
    repository = ApplicationsRepository(api);
  });
  tearDown(() {
    repository.dispose();
    api.close();
  });

  test(
    'capability is absent unless the deployed workspace advertises supported limits',
    () {
      for (final unsupported in [
        null,
        {},
        {'maxBytes': 1, 'maxCount': 3},
        {'maxBytes': 4194304, 'maxCount': 5},
      ]) {
        expect(ApplicationAttachmentLimits.supported(unsupported), isNull);
      }
      expect(
        ApplicationAttachmentLimits.supported(attachmentLimitsFixture),
        isNotNull,
      );
    },
  );
  test(
    'private list, original multipart bytes, profile copy and removal use owner routes',
    () async {
      const path = '/api/applications/catalogue/attachments';
      api.responses[path] = {
        'attachments': [attachmentFixture()],
        'limits': attachmentLimitsFixture,
        'attachment': attachmentFixture(),
      };
      expect(
        (await repository.getAttachments('cat:catalogue')).single.fileName,
        'Evidence.pdf',
      );
      await repository.uploadAttachment('cat:catalogue', 'Proof.PDF', [
        0,
        255,
        13,
        10,
      ]);
      final body = api.calls.last.body as List<int>;
      final start = body.indexOf(0);
      expect(body.sublist(start, start + 4), [0, 255, 13, 10]);
      await repository.attachProfileResume('cat:catalogue');
      expect(api.calls.last.body, {'source': 'profile_resume'});
      await repository.removeAttachment('cat:catalogue', 'private/one');
      expect(api.calls.last.path, '$path/private%2Fone');
      expect(api.calls.last.method, 'DELETE');
    },
  );
  test('invalid document uploads are rejected before any mutation', () async {
    for (final file in [
      (name: 'bad.txt', bytes: [1]),
      (name: '../resume.pdf', bytes: [1]),
      (name: 'empty.pdf', bytes: <int>[]),
      (name: 'huge.docx', bytes: Uint8List(maxApplicationAttachmentBytes + 1)),
    ]) {
      await expectLater(
        repository.uploadAttachment('cat:catalogue', file.name, file.bytes),
        throwsA(isA<ApiException>()),
      );
    }
    expect(api.calls, isEmpty);
  });
  test(
    'submission sends exactly the reviewed private IDs while the legacy request stays unchanged',
    () async {
      await repository.submitApplication('cat:catalogue');
      expect(api.calls.last.body, {'confirmation': true});
      await repository.submitApplication(
        'cat:catalogue',
        attachmentIds: ['private/one'],
      );
      expect(api.calls.last.body, {
        'confirmation': true,
        'attachmentIds': ['private/one'],
      });
      final count = api.calls.length;
      await expectLater(
        repository.submitApplication(
          'cat:catalogue',
          attachmentIds: ['same', 'same'],
        ),
        throwsA(isA<ApiException>()),
      );
      expect(api.calls.length, count);
    },
  );
  test(
    'downloads use atomic response metadata and separate immutable snapshot routes',
    () async {
      final file = await repository.downloadAttachment(
        'cat:catalogue',
        'private/one',
      );
      expect(file.name, 'Current.pdf');
      expect(file.bytes, [0, 255, 13, 10]);
      expect(
        api.downloadPath,
        '/api/applications/catalogue/attachments/private%2Fone',
      );
      expect(api.maxBytes, maxApplicationAttachmentBytes);
      await repository.downloadAttachment(
        'cat:catalogue',
        'snapshot/one',
        submitted: true,
      );
      expect(
        api.downloadPath,
        '/api/applications/catalogue/submission-attachments/snapshot%2Fone',
      );
      api.download = ApiDownload(
        bytes: Uint8List.fromList([1]),
        filename: 'bad.exe',
        mimeType: 'application/pdf',
      );
      await expectLater(
        repository.downloadAttachment('cat:catalogue', 'private/one'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
