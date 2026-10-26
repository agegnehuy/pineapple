import 'package:flutter/services.dart';
import 'package:myoccasio/core/network/api_exception.dart';

typedef DocumentExporter =
    Future<bool> Function(String name, String mimeType, Uint8List bytes);

/// The system picker grants access only to the destination the user chooses.
/// Authentication cookies and download URLs never leave the API client.
Future<bool> exportDocument(
  String name,
  String mimeType,
  Uint8List bytes,
) async {
  if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
    throw const ApiException('Choose a non-empty file under 4 MB.');
  }
  final safeName = name.replaceAll(RegExp(r'[\\/\x00-\x1f\x7f]'), '_');
  try {
    return await const MethodChannel(
          'ca.occasiotech.myoccasio/documents',
        ).invokeMethod<bool>('export', {
          'name': safeName.isEmpty || safeName == '.' || safeName == '..'
              ? 'resume.pdf'
              : safeName,
          'mimeType': mimeType,
          'bytes': bytes,
        }) ??
        false;
  } on PlatformException {
    throw const ApiException('Could not save this file. Please try again.');
  } on MissingPluginException {
    throw const ApiException('File export is unavailable on this device.');
  }
}
