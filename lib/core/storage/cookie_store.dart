import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CookieStore {
  Future<List<Cookie>> read();
  Future<void> write(List<Cookie> cookies);
  Future<void> clear();
}

class SecureCookieStore implements CookieStore {
  SecureCookieStore(this._storage);

  static const _storageKey = 'myoccasio.api.cookies.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<Cookie>> read() async {
    final value = await _storage.read(key: _storageKey);
    if (value == null || value.isEmpty) return [];

    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      final now = DateTime.now();
      return decoded
          .map((item) => _cookieFromJson(item as Map<String, dynamic>))
          .where(
            (cookie) => cookie.expires == null || cookie.expires!.isAfter(now),
          )
          .toList(growable: false);
    } on FormatException {
      await clear();
      return [];
    } on TypeError {
      await clear();
      return [];
    }
  }

  @override
  Future<void> write(List<Cookie> cookies) async {
    final value = jsonEncode(
      cookies.map(_cookieToJson).toList(growable: false),
    );
    await _storage.write(key: _storageKey, value: value);
  }

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);

  Map<String, dynamic> _cookieToJson(Cookie cookie) => {
    'name': cookie.name,
    'value': cookie.value,
    'domain': cookie.domain,
    'path': cookie.path,
    'expires': cookie.expires?.toUtc().toIso8601String(),
    'secure': cookie.secure,
    'httpOnly': cookie.httpOnly,
  };

  Cookie _cookieFromJson(Map<String, dynamic> json) {
    final cookie = Cookie(json['name'] as String, json['value'] as String)
      ..secure = json['secure'] as bool? ?? false
      ..httpOnly = json['httpOnly'] as bool? ?? true;
    final domain = json['domain'] as String?;
    final path = json['path'] as String?;
    final expires = json['expires'] as String?;
    if (domain != null) cookie.domain = domain;
    if (path != null) cookie.path = path;
    if (expires != null) cookie.expires = DateTime.tryParse(expires);
    return cookie;
  }
}

class MemoryCookieStore implements CookieStore {
  List<Cookie> _cookies = [];

  @override
  Future<List<Cookie>> read() async => List.unmodifiable(_cookies);

  @override
  Future<void> write(List<Cookie> cookies) async => _cookies = List.of(cookies);

  @override
  Future<void> clear() async => _cookies = [];
}
