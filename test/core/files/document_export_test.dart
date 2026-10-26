import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/network/api_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ca.occasiotech.myoccasio/documents');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'exports private bytes with a safe filename and reports cancellation',
    () async {
      MethodCall? request;
      messenger.setMockMethodCallHandler(channel, (call) async {
        request = call;
        return false;
      });
      final bytes = Uint8List.fromList([0, 255, 128, 1]);
      expect(
        await exportDocument('../private\n.pdf', 'application/pdf', bytes),
        isFalse,
      );
      expect(request!.method, 'export');
      expect(request!.arguments['name'], '.._private_.pdf');
      expect(request!.arguments['bytes'], bytes);
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      expect(await exportDocument('cv.pdf', 'application/pdf', bytes), isTrue);
    },
  );
  test(
    'rejects invalid payloads and maps native failures to retryable UI errors',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        throw PlatformException(code: 'write_failed');
      });
      await expectLater(
        exportDocument('cv.pdf', 'application/pdf', Uint8List(0)),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        exportDocument(
          'cv.pdf',
          'application/pdf',
          Uint8List(4 * 1024 * 1024 + 1),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
      await expectLater(
        exportDocument('cv.pdf', 'application/pdf', Uint8List(1)),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    },
  );
}
