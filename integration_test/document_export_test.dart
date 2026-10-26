import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myoccasio/core/files/document_export.dart';

/// Opt-in native check. Cancel the first system picker; save the second file.
/// No production account or credentials are used. Not part of headless CI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList(
    utf8.encode('MyOccasio native export verification\n'),
  );
  testWidgets('system export cancellation', (tester) async {
    expect(
      await exportDocument(
        'myoccasio-export-verification.txt',
        'text/plain',
        bytes,
      ),
      isFalse,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
  testWidgets(
    'system export saves chosen document',
    (tester) async {
      expect(
        await exportDocument(
          'myoccasio-export-verification.txt',
          'text/plain',
          bytes,
        ),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
