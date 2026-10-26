import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';

abstract interface class ApplicationCacheStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Uses the same platform encrypted-storage boundary as authenticated cookies.
/// The cache itself contains only a strict whitelist of opportunity metadata.
class SecureApplicationCacheStorage implements ApplicationCacheStorage {
  const SecureApplicationCacheStorage([
    this.storage = const FlutterSecureStorage(),
  ]);
  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class ApplicationCacheSnapshot {
  const ApplicationCacheSnapshot({
    required this.fetchedAt,
    required this.applications,
    required this.complete,
  });
  final DateTime fetchedAt;
  final List<TrackedApplication> applications;
  final bool complete;
}

/// One instance belongs to one authenticated account session. After clear(),
/// discard it and create a new instance for the next authenticated session.
class ApplicationCache extends ChangeNotifier {
  ApplicationCache({
    required this.accountId,
    String namespace = 'https://myoccasio.ca',
    ApplicationCacheStorage? storage,
    DateTime Function()? now,
  }) : _namespace = _normalizeNamespace(namespace),
       _storage = storage ?? const SecureApplicationCacheStorage(),
       _now = now ?? DateTime.now {
    if (accountId.trim().isEmpty || accountId.length > 200) {
      throw ArgumentError.value(accountId, 'accountId');
    }
  }

  static const maxEntries = 200;
  static const maxBytes = 256 * 1024;
  static const _version = 1;
  final String accountId;
  final String _namespace;
  final ApplicationCacheStorage _storage;
  final DateTime Function() _now;
  bool _active = true;
  bool _accessAllowed = true;
  int _accessEpoch = 0;
  Future<void>? _pending;

  bool get isActive => _active;
  bool get allowsOffline => _active && _accessAllowed;
  int get accessEpoch => _accessEpoch;

  /// An observed denial applies to every route sharing this account cache.
  void denyAccess() {
    if (!_active) return;
    _accessAllowed = false;
    _accessEpoch++;
    notifyListeners();
  }

  /// Only a live request started after the most recent denial can restore it.
  bool confirmAccess(int requestEpoch) {
    if (!_active || requestEpoch != _accessEpoch) return false;
    _accessAllowed = true;
    return true;
  }

  String get _key =>
      'myoccasio.applications.cache.v$_version.${base64Url.encode(utf8.encode('$_namespace\n$accountId'))}';

  static String _normalizeNamespace(String value) {
    final uri = Uri.tryParse(value);
    if (value.length > 500 ||
        uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(value, 'namespace');
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    ).toString();
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final pending = _pending;
    final result = pending == null
        ? Future<T>.sync(action)
        : pending.then((_) => action());
    // A failed platform operation must not prevent the following deletion.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ApplicationCacheSnapshot?> read() {
    if (!allowsOffline) return Future.value();
    final epoch = _accessEpoch;
    return _serialize(() async {
      if (!allowsOffline || epoch != _accessEpoch) return null;
      try {
        final raw = await _storage.read(_key);
        if (!allowsOffline || epoch != _accessEpoch || raw == null) return null;
        ApplicationCacheSnapshot? snapshot;
        try {
          snapshot = _decode(raw);
        } on Object {
          snapshot = null;
        }
        if (snapshot == null) await _storage.delete(_key);
        return allowsOffline && epoch == _accessEpoch ? snapshot : null;
      } on Object {
        // Missing, corrupt or inaccessible storage is a cache miss.
        return null;
      }
    });
  }

  Future<void> write(
    List<TrackedApplication> applications, {
    DateTime? fetchedAt,
  }) {
    if (!allowsOffline) return Future.value();
    final epoch = _accessEpoch;
    final checkedAt = (fetchedAt ?? _now()).toUtc();
    if (!_validTime(checkedAt)) return Future.value();
    final records = <Map<String, dynamic>>[];
    var bytes = 4096;
    var complete = true;
    final ids = <String>{};
    for (final item in applications.where((item) => !item.removed)) {
      final record = _record(item);
      final size = utf8.encode(jsonEncode(record)).length;
      if (_parseRecord(record) == null ||
          !ids.add(item.id) ||
          records.length >= maxEntries ||
          bytes + size > maxBytes - 4096) {
        complete = false;
        continue;
      }
      records.add(record);
      bytes += size;
    }
    final raw = jsonEncode({
      'version': _version,
      'accountId': accountId,
      'namespace': _namespace,
      'fetchedAt': checkedAt.toIso8601String(),
      'complete': complete,
      'applications': records,
    });
    if (utf8.encode(raw).length > maxBytes) return Future.value();
    return _serialize(() async {
      if (allowsOffline && epoch == _accessEpoch) {
        await _storage.write(_key, raw);
      }
    });
  }

  /// Deactivate before any await. Queued writers are suppressed, and a running
  /// write finishes before this deletion, so it cannot resurrect signed-out data.
  Future<void> clear() {
    if (_active) {
      _active = false;
      notifyListeners();
    }
    return _serialize(() => _storage.delete(_key));
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  bool _validTime(DateTime time) =>
      !time.isBefore(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)) &&
      !time.isAfter(_now().toUtc().add(const Duration(minutes: 5)));

  ApplicationCacheSnapshot? _decode(String raw) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        !_onlyKeys(decoded, const {
          'version',
          'accountId',
          'namespace',
          'fetchedAt',
          'complete',
          'applications',
        }) ||
        decoded['version'] != _version ||
        decoded['accountId'] != accountId ||
        decoded['namespace'] != _namespace ||
        decoded['complete'] is! bool ||
        decoded['fetchedAt'] is! String ||
        decoded['applications'] is! List) {
      return null;
    }
    if (!(decoded['fetchedAt'] as String).endsWith('Z')) return null;
    final time = DateTime.tryParse(decoded['fetchedAt'] as String);
    if (time == null || !_validTime(time)) return null;
    final rawItems = decoded['applications'] as List;
    if (rawItems.length > maxEntries) return null;
    final applications = <TrackedApplication>[];
    final ids = <String>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) return null;
      final item = _parseRecord(rawItem);
      if (item == null || !ids.add(item.id)) return null;
      applications.add(item);
    }
    return ApplicationCacheSnapshot(
      fetchedAt: time.toUtc(),
      applications: List.unmodifiable(applications),
      complete: decoded['complete'] as bool,
    );
  }

  static Map<String, dynamic> _record(TrackedApplication item) => {
    'id': item.id,
    'opportunityId': item.opportunityId,
    'title': item.title,
    'org': item.organization,
    'amount': item.amount,
    'deadlineLabel': item.deadlineLabel,
    'status': item.status,
    'match': item.match,
    'kindLabel': item.kindLabel,
    'deadline': item.deadline,
  };

  static bool _onlyKeys(Map<String, dynamic> value, Set<String> keys) =>
      value.length == keys.length && value.keys.every(keys.contains);

  static TrackedApplication? _parseRecord(Map<String, dynamic> record) {
    const limits = {
      'id': 256,
      'opportunityId': 256,
      'title': 500,
      'org': 500,
      'amount': 160,
      'deadlineLabel': 160,
      'status': 32,
      'kindLabel': 120,
      'deadline': 64,
    };
    if (!_onlyKeys(record, {...limits.keys, 'match'})) return null;
    for (final entry in limits.entries) {
      final value = record[entry.key];
      if (value is! String || value.length > entry.value) return null;
    }
    if ((record['id'] as String).trim().isEmpty ||
        (record['opportunityId'] as String).trim().isEmpty ||
        (record['title'] as String).trim().isEmpty ||
        !const {
          'saved',
          'drafting',
          'submitted',
          'awarded',
          'rejected',
        }.contains(record['status']) ||
        record['match'] is! int ||
        (record['match'] as int) < 0 ||
        (record['match'] as int) > 100 ||
        ((record['deadline'] as String).isNotEmpty &&
            DateTime.tryParse(record['deadline'] as String) == null)) {
      return null;
    }
    return TrackedApplication.fromJson(record);
  }
}
