import 'package:myoccasio/core/network/api_exception.dart';

const maxApplicationAttachmentBytes = 4 * 1024 * 1024;
const maxApplicationAttachments = 3;
const applicationDocxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

class ApplicationAttachmentLimits {
  const ApplicationAttachmentLimits._();
  int get maxBytes => maxApplicationAttachmentBytes;
  int get maxCount => maxApplicationAttachments;

  /// Old deployments expose neither this capability nor attachment endpoints.
  static ApplicationAttachmentLimits? supported(dynamic json) =>
      json is Map &&
          json['maxBytes'] == maxApplicationAttachmentBytes &&
          json['maxCount'] == maxApplicationAttachments
      ? const ApplicationAttachmentLimits._()
      : null;
}

class ApplicationAttachment {
  const ApplicationAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.createdAt,
  });

  factory ApplicationAttachment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['fileName'];
    final mime = json['mimeType'];
    final size = json['byteSize'];
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        !validApplicationDocument(name, mime?.toString()) ||
        size is! int ||
        size <= 0 ||
        size > maxApplicationAttachmentBytes ||
        created == null) {
      throw const ApiException(
        'Could not read the supporting document details. Please refresh.',
      );
    }
    return ApplicationAttachment(
      id: id,
      fileName: name,
      mimeType: mime.toString(),
      byteSize: size,
      createdAt: created,
    );
  }

  static List<ApplicationAttachment> parseList(dynamic json) {
    if (json is! List) {
      throw const ApiException(
        'Could not read the supporting document details. Please refresh.',
      );
    }
    return json
        .map(
          (item) => ApplicationAttachment.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  final String id, fileName, mimeType;
  final int byteSize;
  final DateTime createdAt;
}

bool validApplicationDocument(String name, String? mime) {
  if (name.trim().isEmpty || RegExp(r'[\\/\x00-\x1f\x7f]').hasMatch(name)) {
    return false;
  }
  final lower = name.toLowerCase();
  return (lower.endsWith('.pdf') && mime == 'application/pdf') ||
      (lower.endsWith('.docx') && mime == applicationDocxMime);
}
