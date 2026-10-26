import 'dart:io';

import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';

class AuthRepository {
  AuthRepository(this._api, this._cookieStore);

  final ApiClient _api;
  final CookieStore _cookieStore;

  Future<void> requestPasswordReset(String email) async {
    await _api.postJson('/api/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    if (!PasswordResetLink.validToken(token)) {
      throw const ApiException(
        'Reset link is invalid or has expired.',
        statusCode: 400,
      );
    }
    if (password.length < 8) {
      throw const ApiException(
        'Password must be at least 8 characters.',
        statusCode: 400,
      );
    }
    // Token-authorized mutation; no automatic retry or session creation.
    final response = await _api.postJson('/api/auth/reset-password', {
      'token': token,
      'password': password,
    });
    final json = response.json;
    if (json is! Map<String, dynamic> || json['ok'] != true) {
      throw const ApiException(
        'The server did not confirm the password update. Please try again.',
      );
    }
  }

  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final generation = _api.sessionGeneration;
    await _api.postJson('/api/register', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    _api.checkSessionGeneration(generation);
    return signIn(email: email, password: password);
  }

  Future<AuthSession> currentSession() async {
    final generation = _api.sessionGeneration;
    final response = await _api.get('/api/auth/session');
    _api.checkSessionGeneration(generation);
    final json = response.json;
    return AuthSession.fromJson(
      json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final generation = _api.sessionGeneration;
    final csrfToken = await _csrfToken();
    _api.checkSessionGeneration(generation);

    await _api.postForm(
      '/api/auth/callback/credentials',
      {
        'csrfToken': csrfToken,
        'email': email.trim().toLowerCase(),
        'password': password,
        'callbackUrl': '/',
        'json': 'true',
      },
      headers: {'X-Auth-Return-Redirect': '1'},
    );
    _api.checkSessionGeneration(generation);
    final session = await currentSession();
    _api.checkSessionGeneration(generation);
    if (!session.isAuthenticated) {
      throw const ApiException('Incorrect email or password.', statusCode: 401);
    }
    return session;
  }

  Future<void> signOut() async {
    final generation = _api.sessionGeneration;
    try {
      final csrfToken = await _csrfToken(retryRead: false);
      _api.checkSessionGeneration(generation);
      await _api.postForm(
        '/api/auth/signout',
        {'csrfToken': csrfToken, 'callbackUrl': '/', 'json': 'true'},
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          'X-Auth-Return-Redirect': '1',
        },
      );
    } on Exception {
      // Remote sign-out is best effort. Local sign-out succeeds only after
      // encrypted session removal below; storage failures still propagate.
    } finally {
      if (generation == _api.sessionGeneration) {
        await _api.clearSession(_cookieStore.clear);
      }
    }
  }

  Future<String> _csrfToken({bool retryRead = true}) async {
    final response = retryRead
        ? await _api.get('/api/auth/csrf')
        : await _api.request('GET', '/api/auth/csrf');
    final json = response.json;
    final token = json is Map<String, dynamic> ? json['csrfToken'] : null;
    if (token is! String || token.isEmpty) {
      throw const ApiException('The server did not provide a CSRF token.');
    }
    return token;
  }
}
