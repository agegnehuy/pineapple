import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/data/system_auth_browser.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';

/// Additive PKCE handoff to the existing website's normal cookie session.
/// Old or disabled servers expose no provider control in the mobile interface.
class NativeAuthRepository {
  NativeAuthRepository({
    required ApiClient api,
    required AuthRepository auth,
    required CookieStore cookies,
    required Uri baseUri,
    AuthBrowser? browser,
    DateTime Function()? now,
  }) : _api = api,
       _auth = auth,
       _cookies = cookies,
       _baseUri = baseUri,
       _browser = browser ?? SystemAuthBrowser(),
       _now = now ?? DateTime.now;

  static const callbackUri = 'ca.occasiotech.myoccasio.auth://callback';
  static final _opaque = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static bool _validOpaque(String value) {
    if (!_opaque.hasMatch(value)) return false;
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      return bytes.length == 32 &&
          base64Url.encode(bytes).replaceAll('=', '') == value;
    } on FormatException {
      return false;
    }
  }

  final ApiClient _api;
  final AuthRepository _auth;
  final CookieStore _cookies;
  final Uri _baseUri;
  final AuthBrowser _browser;
  final DateTime Function() _now;
  _NativeAttempt? _attempt;
  Future<void>? _cancelling;
  bool get pending => _attempt != null;

  Future<void> _closeBrowser() async {
    try {
      await _browser.cancel();
    } on Object {
      // State/PKCE are already invalidated. A browser dismissal failure cannot
      // authorize a callback or prevent encrypted-cookie cleanup.
    }
  }

  Future<bool> googleAvailable() async {
    try {
      final response = await _api.request('GET', '/api/auth/native/config');
      final data = response.json;
      return response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['enabled'] == true &&
          data['callbackUri'] == callbackUri &&
          data['providers'] is List &&
          (data['providers'] as List).any(
            (provider) =>
                provider is Map<String, dynamic> && provider['id'] == 'google',
          );
    } on Object {
      return false;
    }
  }

  String _random() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  void _require(_NativeAttempt attempt) {
    if (!identical(_attempt, attempt) || attempt.cancelled) {
      throw const NativeAuthCancelled();
    }
    _api.checkSessionGeneration(attempt.generation);
  }

  Uri _authorization(dynamic value) {
    final uri = value is String && value.length <= 2048
        ? Uri.tryParse(value)
        : null;
    final expectedPath =
        '${_baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/auth/native';
    if (uri == null ||
        uri.origin != _baseUri.origin ||
        !(uri.scheme == 'https' ||
            (_baseUri.scheme == 'http' &&
                const {
                  '127.0.0.1',
                  '::1',
                  'localhost',
                }.contains(_baseUri.host))) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.path != expectedPath ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['request']?.length != 1 ||
        !_validOpaque(uri.queryParameters['request'] ?? '')) {
      throw const ApiException(
        'The sign-in service returned an invalid response.',
      );
    }
    return uri;
  }

  bool _same(String first, String second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }

  String _callbackCode(Uri callback, String state) {
    final values = callback.queryParametersAll;
    if (callback.toString().length > 2048 ||
        callback.scheme != 'ca.occasiotech.myoccasio.auth' ||
        callback.host != 'callback' ||
        callback.path.isNotEmpty ||
        callback.hasPort ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment ||
        values.length != 2 ||
        values['state']?.length != 1 ||
        !_same(values['state']!.single, state)) {
      throw const ApiException(
        'The sign-in callback could not be verified. Please try again.',
      );
    }
    if (values['error']?.length == 1) {
      throw const ApiException(
        'Google sign-in did not finish. Please try again.',
      );
    }
    if (values['code']?.length != 1 || !_validOpaque(values['code']!.single)) {
      throw const ApiException(
        'The sign-in callback could not be verified. Please try again.',
      );
    }
    return values['code']!.single;
  }

  Future<AuthSession> signIn() async {
    if (_attempt != null) throw const ApiException('Please wait…');
    final attempt = _NativeAttempt(_api.sessionGeneration);
    _attempt = attempt;
    var exchanged = false;
    var confirmed = false;
    try {
      if (!await googleAvailable()) {
        throw const ApiException(
          'Google sign-in is unavailable. Use your email and password.',
        );
      }
      _require(attempt);
      final state = _random();
      final verifier = _random();
      final challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      final response = await _api.postJson('/api/auth/native/start', {
        'provider': 'google',
        'state': state,
        'codeChallenge': challenge,
        'codeChallengeMethod': 'S256',
        'redirectUri': callbackUri,
      });
      _require(attempt);
      final data = response.json;
      final expires =
          data is Map<String, dynamic> && data['expiresAt'] is String
          ? DateTime.tryParse(data['expiresAt'])
          : null;
      if (response.statusCode != 201 ||
          expires == null ||
          !expires.isAfter(_now()) ||
          expires.isAfter(_now().add(const Duration(minutes: 11)))) {
        throw const ApiException(
          'The sign-in service returned an invalid response.',
        );
      }
      final url = _authorization(data['authorizationUrl']);
      final callback = await _browser
          .authenticate(url)
          .timeout(expires.difference(_now()));
      _require(attempt);
      final code = _callbackCode(callback, state);
      exchanged = true;
      final exchange = await _api.postJson('/api/auth/native/exchange', {
        'code': code,
        'codeVerifier': verifier,
        'redirectUri': callbackUri,
      });
      _require(attempt);
      final result = exchange.json;
      if (exchange.statusCode != 200 ||
          result is! Map<String, dynamic> ||
          result['authenticated'] != true) {
        throw const ApiException(
          'Google sign-in did not finish. Please try again.',
        );
      }
      final session = await _auth.currentSession();
      _require(attempt);
      if (!session.isAuthenticated) {
        throw const ApiException(
          'Google sign-in did not finish. Please try again.',
        );
      }
      confirmed = true;
      return session;
    } on TimeoutException {
      throw const ApiException('Sign-in expired. Please try again.');
    } finally {
      if (identical(_attempt, attempt) && !attempt.cancelled) {
        await _closeBrowser();
        if (!attempt.cancelled &&
            exchanged &&
            !confirmed &&
            _api.sessionGeneration == attempt.generation) {
          final cleanup = _api.clearSession(_cookies.clear);
          attempt.cleanupGeneration = _api.sessionGeneration;
          try {
            await cleanup;
          } on Object {
            attempt.cancelled = true;
            rethrow;
          }
        }
        if (identical(_attempt, attempt) && !attempt.cancelled) _attempt = null;
      }
    }
  }

  Future<void> cancel() {
    if (_cancelling != null) return _cancelling!;
    final attempt = _attempt;
    if (attempt == null) return Future.value();
    attempt.cancelled = true;
    // Invalidate in-flight exchange Set-Cookie before allowing another login.
    Future<void> clear = Future.value();
    if (_api.sessionGeneration ==
        (attempt.cleanupGeneration ?? attempt.generation)) {
      clear = _api.clearSession(_cookies.clear);
      attempt.cleanupGeneration = _api.sessionGeneration;
    }
    final operation = Future.wait([clear, _closeBrowser()]).then<void>((_) {
      if (identical(_attempt, attempt)) _attempt = null;
    });
    _cancelling = operation.whenComplete(() => _cancelling = null);
    return _cancelling!;
  }
}

class _NativeAttempt {
  _NativeAttempt(this.generation);
  final int generation;
  bool cancelled = false;
  int? cleanupGeneration;
}
