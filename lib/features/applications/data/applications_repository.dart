import 'package:myoccasio/core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/applications/domain/application_attachment.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';

class ApplicationsRepository extends ChangeNotifier {
  ApplicationsRepository(this._api);

  final ApiClient _api;

  /// Bookmarking must not move an existing application back to Saved.
  Future<void> bookmark(String opportunityId) async {
    final generation = _api.sessionGeneration;
    final existing = await getTrackedApplications();
    _api.checkSessionGeneration(generation);
    if (existing.any((item) => item.opportunityId == opportunityId)) return;
    await saveTrackedApplication(opportunityId: opportunityId);
  }

  String _workspacePath(String opportunityId) =>
      '/api/applications/${Uri.encodeComponent(opportunityId.replaceFirst(RegExp(r'^cat:'), ''))}';

  Future<Map<String, dynamic>> getWorkspace(String opportunityId) async =>
      (await _api.get(_workspacePath(opportunityId))).json
          as Map<String, dynamic>;

  Future<void> saveStatement(
    String opportunityId,
    String statement, {
    List<String> checklist = const [],
    List<String> missingFields = const [],
  }) async {
    await _api.putJson(_workspacePath(opportunityId), {
      'statement': statement,
      'checklist': checklist,
      'missingFields': missingFields,
    });
    notifyListeners();
  }

  Future<void> submitApplication(
    String opportunityId, {
    List<String>? attachmentIds,
  }) async {
    if (attachmentIds != null &&
        (attachmentIds.length > maxApplicationAttachments ||
            attachmentIds.any((id) => id.isEmpty) ||
            attachmentIds.toSet().length != attachmentIds.length)) {
      throw const ApiException(
        'Review your supporting documents before submitting.',
      );
    }
    await _api.postJson(_workspacePath(opportunityId), {
      'confirmation': true,
      if (attachmentIds != null)
        'attachmentIds': List<String>.of(attachmentIds),
    });
    notifyListeners();
  }

  Future<List<ApplicationAttachment>> getAttachments(
    String opportunityId,
  ) async {
    final json = (await _api.get(
      '${_workspacePath(opportunityId)}/attachments',
    )).json;
    if (ApplicationAttachmentLimits.supported(json['limits']) == null) {
      throw const ApiException(
        'Supporting documents are unavailable on this server.',
      );
    }
    return ApplicationAttachment.parseList(json['attachments']);
  }

  Future<ApplicationAttachment> uploadAttachment(
    String opportunityId,
    String name,
    List<int> bytes,
  ) async {
    final mime = name.toLowerCase().endsWith('.pdf')
        ? 'application/pdf'
        : applicationDocxMime;
    if (!validApplicationDocument(name, mime)) {
      throw const ApiException('Choose a PDF or DOCX document.');
    }
    if (bytes.isEmpty || bytes.length > maxApplicationAttachmentBytes) {
      throw const ApiException('Choose a non-empty file under 4 MB.');
    }
    final response = await _api.postFile(
      '${_workspacePath(opportunityId)}/attachments',
      filename: name,
      bytes: bytes,
    );
    final attachment = ApplicationAttachment.fromJson(
      response.json['attachment'] as Map<String, dynamic>,
    );
    notifyListeners();
    return attachment;
  }

  Future<ApplicationAttachment> attachProfileResume(
    String opportunityId,
  ) async {
    final response = await _api.postJson(
      '${_workspacePath(opportunityId)}/attachments',
      {'source': 'profile_resume'},
    );
    final attachment = ApplicationAttachment.fromJson(
      response.json['attachment'] as Map<String, dynamic>,
    );
    notifyListeners();
    return attachment;
  }

  Future<void> removeAttachment(
    String opportunityId,
    String attachmentId,
  ) async {
    await _api.deleteJson(
      '${_workspacePath(opportunityId)}/attachments/${Uri.encodeComponent(attachmentId)}',
    );
    notifyListeners();
  }

  Future<({String name, String mimeType, Uint8List bytes})> downloadAttachment(
    String opportunityId,
    String attachmentId, {
    bool submitted = false,
  }) async {
    final download = await _api.getDownload(
      '${_workspacePath(opportunityId)}/${submitted ? 'submission-attachments' : 'attachments'}/${Uri.encodeComponent(attachmentId)}',
      maxBytes: maxApplicationAttachmentBytes,
    );
    final name = download.filename;
    if (download.bytes.isEmpty ||
        name == null ||
        !validApplicationDocument(name, download.mimeType)) {
      throw const ApiException(
        'The supporting document could not be downloaded safely. Please refresh.',
      );
    }
    return (name: name, mimeType: download.mimeType!, bytes: download.bytes);
  }

  Future<Map<String, dynamic>> generateDraft(
    String opportunityId,
    String instruction,
  ) async =>
      (await _api.postJson(
            '/api/ai/application-draft/${Uri.encodeComponent(opportunityId.replaceFirst(RegExp(r'^cat:'), ''))}',
            {'consent': true, 'instruction': instruction},
          )).json
          as Map<String, dynamic>;

  Future<void> withdrawApplication(String opportunityId) async {
    await _api.deleteJson(_workspacePath(opportunityId));
    notifyListeners();
  }

  Future<void> removeSaved(String trackingId) async {
    await _api.deleteJson('/api/tracking/${Uri.encodeComponent(trackingId)}');
    notifyListeners();
  }

  Future<List<TrackedApplication>> getTrackedApplications() async {
    final response = await _api.get('/api/tracking');
    final json = response.json as List<dynamic>;
    return json
        .whereType<Map<String, dynamic>>()
        .map(TrackedApplication.fromJson)
        .toList(growable: false);
  }

  Future<void> saveTrackedApplication({
    required String opportunityId,
    String status = 'saved',
  }) async {
    await _api.postJson('/api/tracking', {
      'opportunityId': opportunityId,
      'status': status,
    });
    notifyListeners();
  }
}
