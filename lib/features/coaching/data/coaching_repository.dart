import 'package:myoccasio/core/network/api_client.dart';

class CoachingRepository {
  CoachingRepository(this._api);
  final ApiClient _api;
  Future<Map<String, dynamic>> ask(
    String prompt, {
    String? conversationId,
    bool useProfile = true,
    bool useSaved = true,
    List<String> attachmentIds = const [],
  }) async =>
      (await _api.postJson('/api/ai/coach', {
            'prompt': prompt,
            'conversationId': ?conversationId,
            'useProfile': useProfile,
            'useSaved': useSaved,
            if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
          })).json
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> history({String? id}) async =>
      (await _api.get(
            '/api/ai/coach${id == null ? '' : '?conversation=${Uri.encodeQueryComponent(id)}'}',
          )).json
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> getStory() async =>
      (await _api.get('/api/academic/story')).json as Map<String, dynamic>;
  Future<void> saveStory(Map<String, Object?> story) async {
    await _api.putJson('/api/academic/story', story);
  }

  Future<Map<String, dynamic>> draftStory(
    List<String> sources,
    String instruction,
  ) async =>
      (await _api.postJson('/api/ai/story-draft', {
            'sources': sources,
            'instruction': instruction,
            'consent': true,
          })).json
          as Map<String, dynamic>;
  Future<void> saveDraft(String draft) async {
    await _api.putJson('/api/academic/story/draft', {'draft': draft});
  }

  Future<Map<String, dynamic>> uploadDocument(
    String filename,
    List<int> bytes,
  ) async =>
      (await _api.postFile(
            '/api/ai/uploads',
            filename: filename,
            bytes: bytes,
          )).json
          as Map<String, dynamic>;
}
