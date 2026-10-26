import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/profile_resume.dart';

import '../../support/recording_api.dart';

void main() {
  late _ResumeApi api;
  late ProfileRepository repository;
  late int notifications;

  setUp(() {
    api = _ResumeApi();
    repository = ProfileRepository(api);
    notifications = 0;
    repository.addListener(() => notifications++);
  });

  tearDown(() {
    repository.dispose();
    api.close();
  });

  test(
    'reads resume metadata from profile without changing the me contract',
    () async {
      api.responses['/api/profile'] = {
        'profile': {
          'resumeName': 'Mon CV.pdf',
          'resumeMimeType': 'application/pdf',
          'resumeSize': 1234,
        },
      };
      final resume = await repository.getResume();
      expect(resume?.name, 'Mon CV.pdf');
      expect(resume?.mimeType, 'application/pdf');
      expect(resume?.size, 1234);
      expect(api.calls.single.path, '/api/profile');
      expect(notifications, 0);

      api.responses['/api/me'] = {
        'user': {'id': 'student', 'firstName': 'Mihret'},
      };
      expect((await repository.getCurrentUser()).firstName, 'Mihret');
      expect(api.calls.last.path, '/api/me');
    },
  );

  test('a profile without a resume is an empty state', () async {
    api.responses['/api/profile'] = {
      'profile': {
        'resumeName': null,
        'resumeMimeType': null,
        'resumeSize': null,
      },
    };
    expect(await repository.getResume(), isNull);
  });

  test(
    'saves the original file and returns confirmed server metadata',
    () async {
      api.responses['/api/profile/resume'] = {
        'resume': {
          'name': 'Approved CV.PDF',
          'mimeType': 'application/pdf',
          'size': 4,
        },
      };
      final resume = await repository.saveResume('Approved CV.PDF', [
        0,
        255,
        1,
        42,
      ]);
      expect(resume.name, 'Approved CV.PDF');
      expect(resume.size, 4);
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/api/profile/resume');
      final multipart = api.calls.single.body as List<int>;
      final start = multipart.indexOf(0);
      expect(multipart.sublist(start, start + 4), [0, 255, 1, 42]);
      expect(notifications, 1);
    },
  );

  test(
    'rejects unsupported, empty and oversized resumes before sending',
    () async {
      for (final file in [
        (name: 'notes.txt', bytes: [1]),
        (name: 'resume.pdf.exe', bytes: [1]),
        (name: 'resume.pdf', bytes: <int>[]),
        (name: 'resume.docx', bytes: Uint8List(maxResumeBytes + 1)),
      ]) {
        await expectLater(
          repository.saveResume(file.name, file.bytes),
          throwsA(isA<ApiException>()),
        );
      }
      expect(api.calls, isEmpty);
      expect(notifications, 0);
    },
  );

  test('confirmed removal notifies dependents; failures do not', () async {
    await repository.removeResume();
    expect(api.calls.single.method, 'DELETE');
    expect(api.calls.single.path, '/api/profile/resume');
    expect(notifications, 1);
    api.failure = const ApiException('Please try again.', statusCode: 503);
    await expectLater(repository.removeResume(), throwsA(isA<ApiException>()));
    await expectLater(
      repository.saveResume('resume.pdf', [1]),
      throwsA(isA<ApiException>()),
    );
    expect(notifications, 1);
  });

  test(
    'downloads bounded original bytes and refuses an empty saved file',
    () async {
      api.bytes = Uint8List.fromList([0, 255, 13, 10]);
      expect(await repository.downloadResume(), [0, 255, 13, 10]);
      expect(api.downloadPath, '/api/profile/resume');
      expect(api.downloadLimit, maxResumeBytes);
      expect(notifications, 0);
      api.bytes = Uint8List(0);
      await expectLater(
        repository.downloadResume(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'exports the downloaded file metadata even if profile metadata is stale',
    () async {
      api.responses['/api/profile'] = {
        'profile': {
          'resumeName': 'old.pdf',
          'resumeMimeType': 'application/pdf',
          'resumeSize': 12,
        },
      };
      expect((await repository.getResume())?.name, 'old.pdf');
      api.download = ApiDownload(
        bytes: Uint8List.fromList([0, 255, 42]),
        filename: 'Updated CV.docx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      final file = await repository.downloadResumeFile();
      expect(file.name, 'Updated CV.docx');
      expect(
        file.mimeType,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(file.bytes, [0, 255, 42]);
      expect(api.downloadLimit, maxResumeBytes);
      expect(notifications, 0);
    },
  );

  test(
    'refuses missing, unsafe or inconsistent download names and types',
    () async {
      final bytes = Uint8List.fromList([0, 255, 42]);
      for (final download in [
        ApiDownload(bytes: bytes, mimeType: 'application/pdf'),
        ApiDownload(bytes: bytes, filename: 'cv.pdf'),
        ApiDownload(
          bytes: bytes,
          filename: '../cv.pdf',
          mimeType: 'application/pdf',
        ),
        ApiDownload(
          bytes: bytes,
          filename: 'cv\n.pdf',
          mimeType: 'application/pdf',
        ),
        ApiDownload(
          bytes: bytes,
          filename: 'cv.docx',
          mimeType: 'application/pdf',
        ),
        ApiDownload(
          bytes: bytes,
          filename: 'cv.pdf',
          mimeType: 'application/octet-stream',
        ),
        ApiDownload(
          bytes: Uint8List(0),
          filename: 'cv.pdf',
          mimeType: 'application/pdf',
        ),
      ]) {
        api.download = download;
        await expectLater(
          repository.downloadResumeFile(),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
}

class _ResumeApi extends RecordingApi {
  Uint8List bytes = Uint8List(0);
  String? downloadPath;
  int? downloadLimit;
  ApiDownload? download;

  @override
  Future<ApiDownload> getDownload(String path, {required int maxBytes}) async {
    downloadPath = path;
    downloadLimit = maxBytes;
    if (failure != null) throw failure!;
    return download ?? ApiDownload(bytes: bytes);
  }

  @override
  Future<Uint8List> getBytes(String path, {required int maxBytes}) async {
    downloadPath = path;
    downloadLimit = maxBytes;
    if (failure != null) throw failure!;
    return bytes;
  }
}
