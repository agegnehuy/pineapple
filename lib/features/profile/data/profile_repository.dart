import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:myoccasio/features/profile/domain/profile_resume.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';

class ProfileRepository extends ChangeNotifier {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<ProfileResume?> getResume() async {
    final response = await _api.get('/api/profile');
    final profile = response.json['profile'] as Map<String, dynamic>;
    final name = (profile['resumeName'] ?? '').toString();
    if (name.trim().isEmpty) return null;
    return ProfileResume.fromJson({
      'name': name,
      'mimeType': profile['resumeMimeType'],
      'size': profile['resumeSize'],
    });
  }

  Future<ProfileResume> saveResume(String name, List<int> bytes) async {
    final normalized = name.trim().toLowerCase();
    if (!normalized.endsWith('.pdf') && !normalized.endsWith('.docx')) {
      throw const ApiException('Choose a PDF or .docx résumé.');
    }
    if (bytes.isEmpty || bytes.length > maxResumeBytes) {
      throw const ApiException('Choose a non-empty file under 4 MB.');
    }
    final response = await _api.postFile(
      '/api/profile/resume',
      filename: name,
      bytes: bytes,
    );
    final resume = ProfileResume.fromJson(
      response.json['resume'] as Map<String, dynamic>,
    );
    notifyListeners();
    return resume;
  }

  Future<void> removeResume() async {
    await _api.deleteJson('/api/profile/resume');
    notifyListeners();
  }

  Future<Uint8List> downloadResume() async {
    final bytes = await _api.getBytes(
      '/api/profile/resume',
      maxBytes: maxResumeBytes,
    );
    if (bytes.isEmpty) {
      throw const ApiException(
        'The saved résumé is empty. Please upload it again.',
      );
    }
    return bytes;
  }

  Future<({String name, String mimeType, Uint8List bytes})>
  downloadResumeFile() async {
    final download = await _api.getDownload(
      '/api/profile/resume',
      maxBytes: maxResumeBytes,
    );
    final name = download.filename?.trim();
    final mimeType = download.mimeType;
    final pdf =
        mimeType == 'application/pdf' &&
        (name?.toLowerCase().endsWith('.pdf') ?? false);
    final word =
        mimeType ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' &&
        (name?.toLowerCase().endsWith('.docx') ?? false);
    if (download.bytes.isEmpty ||
        name == null ||
        name.isEmpty ||
        RegExp(r'[\\/\x00-\x1f\x7f]').hasMatch(name) ||
        (!pdf && !word)) {
      throw const ApiException(
        'The saved résumé could not be downloaded safely. Please upload it again.',
      );
    }
    return (name: name, mimeType: mimeType!, bytes: download.bytes);
  }

  Future<List<Map<String, dynamic>>> suggestImport(String text) async =>
      ((await _api.postJson('/api/profile/import', {
                'text': text,
              })).json['suggestions']
              as List)
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> suggestFileImport(
    String name,
    List<int> bytes,
  ) async =>
      ((await _api.postFile(
                '/api/profile/import',
                filename: name,
                bytes: bytes,
              )).json['suggestions']
              as List)
          .cast<Map<String, dynamic>>();

  Future<UserProfile> getCurrentUser() async {
    final response = await _api.get('/api/me');
    return UserProfile.fromJson(response.json as Map<String, dynamic>);
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    await _api.patchJson('/api/me', fields);
    notifyListeners();
  }
}
