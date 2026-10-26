import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myoccasio/features/academics/domain/study_plan.dart';

abstract interface class StudyPlanPreferencesStore {
  Future<StudyPlanPreferences> read(String accountId);
  Future<void> write(String accountId, StudyPlanPreferences preferences);
  Future<void> clear(String accountId);
}

class SecureStudyPlanPreferencesStore implements StudyPlanPreferencesStore {
  SecureStudyPlanPreferencesStore({
    FlutterSecureStorage? storage,
    this.namespace = 'https://myoccasio.ca',
  }) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  final String namespace;
  final _pending = <String, Future<void>>{};
  final _generation = <String, int>{};
  final _inactive = <String>{};

  void _requireActive(String key) {
    if (_inactive.contains(key)) {
      throw StateError('Study preferences belong to an ended session.');
    }
  }

  Future<void> _serialize(String key, Future<void> Function() action) {
    final previous = _pending[key] ?? Future<void>.value();
    final operation = previous.catchError((Object _) {}).then((_) => action());
    _pending[key] = operation;
    void remove() {
      if (identical(_pending[key], operation)) _pending.remove(key);
    }

    operation.then(
      (_) => remove(),
      onError: (Object _, StackTrace _) => remove(),
    );
    return operation;
  }

  static String keyForAccount(
    String accountId, {
    String namespace = 'https://myoccasio.ca',
  }) {
    if (accountId.trim().isEmpty || accountId.length > 256) {
      throw ArgumentError('A signed-in account ID is required.');
    }
    if (namespace.trim().isEmpty || namespace.length > 2048) {
      throw ArgumentError('A backend namespace is required.');
    }
    return 'myoccasio.study-plan.preferences.v1.'
        '${Uri.encodeComponent(namespace)}.${Uri.encodeComponent(accountId)}';
  }

  @override
  Future<StudyPlanPreferences> read(String accountId) async {
    final key = keyForAccount(accountId, namespace: namespace);
    _requireActive(key);
    final generation = _generation[key] ?? 0;
    await _pending[key]?.catchError((Object _) {});
    _requireActive(key);
    final raw = await _storage.read(key: key);
    _requireActive(key);
    if (generation != (_generation[key] ?? 0)) {
      throw StateError('Study preferences were cleared.');
    }
    if (raw == null) return StudyPlanPreferences();
    if (raw.length > 65536) {
      throw const FormatException('Invalid study preferences.');
    }
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid study preferences.');
    }
    return StudyPlanPreferences.fromJson(data);
  }

  @override
  Future<void> write(String accountId, StudyPlanPreferences preferences) async {
    final key = keyForAccount(accountId, namespace: namespace);
    _requireActive(key);
    if (!preferences.isValid) throw ArgumentError('Invalid study preferences.');
    final raw = jsonEncode(preferences.toJson());
    if (raw.length > 65536) throw ArgumentError('Too many study preferences.');
    final generation = _generation[key] ?? 0;
    await _serialize(key, () async {
      _requireActive(key);
      if (generation != (_generation[key] ?? 0)) {
        throw StateError('Study preferences were cleared.');
      }
      await _storage.write(key: key, value: raw);
    });
  }

  @override
  Future<void> clear(String accountId) async {
    final key = keyForAccount(accountId, namespace: namespace);
    _inactive.add(key);
    _generation[key] = (_generation[key] ?? 0) + 1;
    // A store belongs to one MainShell session. Deactivate before awaiting so
    // neither existing nor newly opened routes can write after sign-out starts.
    // Delete after any active write, and invalidate writes queued before clear.
    await _serialize(key, () => _storage.delete(key: key));
  }
}
