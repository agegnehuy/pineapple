import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:myoccasio/core/network/api_exception.dart';

typedef DocumentPicker = Future<XFile?> Function();
const maxDocumentBytes = 4 * 1024 * 1024;
Future<XFile?> selectResume() => openFile(
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'Résumé',
      extensions: ['pdf', 'docx'],
      uniformTypeIdentifiers: [
        'com.adobe.pdf',
        'org.openxmlformats.wordprocessingml.document',
      ],
    ),
  ],
);
Future<XFile?> selectDocument() => openFile(
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'Document',
      extensions: ['pdf', 'docx', 'txt', 'md'],
      uniformTypeIdentifiers: [
        'com.adobe.pdf',
        'org.openxmlformats.wordprocessingml.document',
        'public.plain-text',
        'net.daringfireball.markdown',
      ],
    ),
  ],
);

Future<({String name, Uint8List bytes})?> readSelectedDocument(
  DocumentPicker picker,
) async {
  final file = await picker();
  if (file == null) return null;
  if (await file.length() > maxDocumentBytes) {
    throw const ApiException('Choose a file under 4 MB.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
    throw const ApiException('Choose a non-empty file under 4 MB.');
  }
  return (name: file.name, bytes: bytes);
}
