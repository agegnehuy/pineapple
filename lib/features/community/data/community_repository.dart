import 'package:myoccasio/core/network/api_client.dart';

class CommunityRepository {
  CommunityRepository(this._api);
  final ApiClient _api;
  Future<List<Map<String, dynamic>>> posts({bool wins = false}) async =>
      ((await _api.get('/api/community/${wins ? 'wins' : 'posts'}')).json
              as List)
          .cast<Map<String, dynamic>>();
  Future<void> createPost(String body, {bool win = false}) async {
    await _api.postJson('/api/community/${win ? 'wins' : 'posts'}', {
      'body': body,
      'group': 'General',
    });
  }

  Future<void> like(String id, {required bool liked, bool win = false}) async {
    final path =
        '/api/community/${win ? 'wins' : 'posts'}/${Uri.encodeComponent(id)}/like';
    if (liked) {
      await _api.postJson(path, {});
    } else {
      await _api.deleteJson(path);
    }
  }

  Future<List<Map<String, dynamic>>> comments(
    String id, {
    bool win = false,
  }) async =>
      ((await _api.get(
                '/api/community/${win ? 'wins' : 'posts'}/${Uri.encodeComponent(id)}/comments',
              )).json['comments']
              as List)
          .cast<Map<String, dynamic>>();
  Future<void> comment(String id, String text, {bool win = false}) async {
    await _api.postJson(
      '/api/community/${win ? 'wins' : 'posts'}/${Uri.encodeComponent(id)}/comments',
      {'content': text},
    );
  }

  Future<List<Map<String, dynamic>>> people() async =>
      ((await _api.get('/api/community/people')).json as List)
          .cast<Map<String, dynamic>>();
  Future<bool> requestChat(String userId) async =>
      (await _api.postJson('/api/community/chat-requests', {
        'toUserId': userId,
      })).json['alreadyExists'] ==
      true;
  Future<List<Map<String, dynamic>>> events() async =>
      ((await _api.get('/api/community/events')).json as List)
          .cast<Map<String, dynamic>>();
  Future<void> register(String id, {bool cancel = false}) async {
    final path = '/api/community/events/${Uri.encodeComponent(id)}/register';
    if (cancel) {
      await _api.deleteJson(path);
    } else {
      await _api.postJson(path, {});
    }
  }
}
