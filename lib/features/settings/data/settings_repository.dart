import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';

class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<void> sendSupportMessage({
    required String name,
    required String email,
    required String message,
  }) async {
    await _api.postJson('/api/contact', {
      'name': name,
      'email': email,
      'topic': 'student',
      'message': message,
    });
  }

  Future<Map<String, dynamic>> notifications() async =>
      (await _api.get('/api/me/notifications')).json as Map<String, dynamic>;
  Future<void> updateNotifications(Map<String, bool> preferences) async {
    await _api.patchJson('/api/me/notifications', preferences);
  }

  Future<List<Map<String, dynamic>>> activity() async =>
      ((await _api.get('/api/activity')).json as List)
          .cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> plan() async =>
      (await _api.get('/api/subscription/state')).json as Map<String, dynamic>;
  Future<Map<String, dynamic>> allowance() async =>
      (await _api.get('/api/ai/credits')).json as Map<String, dynamic>;
  Future<void> deleteAccount(String email) async {
    try {
      await _api.deleteJson('/api/me/account', {
        'confirmEmail': email,
        'confirmation': 'DELETE',
      });
    } on ApiException catch (error) {
      // A previous confirmed deletion may have succeeded before local session
      // removal failed. Permit the user to finish local sign-out on retry.
      if (error.statusCode != 404 || error.message != 'Account not found.') {
        rethrow;
      }
    }
  }

  Future<String> billingPortal() async =>
      (await _api.postJson('/api/subscription/portal', {})).json['portalUrl']
          as String;
}
