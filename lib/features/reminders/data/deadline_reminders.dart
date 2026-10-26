import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';
import 'package:myoccasio/features/reminders/domain/deadline_reminder.dart';

abstract interface class ReminderStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureReminderStorage implements ReminderStorage {
  const SecureReminderStorage([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

/// A single coordinator serializes native scheduling and encrypted persistence
/// across account transitions. A session token never authorizes a later account.
class DeadlineReminders extends ChangeNotifier {
  DeadlineReminders({
    required this.platform,
    required String namespace,
    ReminderStorage? storage,
    DateTime Function()? now,
    String Function()? language,
  }) : _storage = storage ?? const SecureReminderStorage(),
       _namespace = _normalizeNamespace(namespace),
       _now = now ?? DateTime.now,
       _language = language ?? (() => 'en');

  static const maxReminders = 50;
  static const maxStorageBytes = 65536;
  final ReminderPlatform platform;
  final ReminderStorage _storage;
  final String _namespace;
  final DateTime Function() _now;
  final String Function() _language;
  Future<void> _pending = Future.value();
  Future<void>? _initializing;
  int _generation = 0;
  String? _accountId;
  List<DeadlineReminder> _items = [];
  bool _ready = false;
  bool _disposed = false;
  String? _error;
  ReminderPermission _permission = ReminderPermission.unavailable;
  ReminderSession? _session;
  Duration? _timeZoneOffset;
  ReminderSession? get session => _session?.active == true ? _session : null;

  static String _normalizeNamespace(String value) {
    final uri = Uri.tryParse(value);
    if (value.length > 2048 ||
        uri == null ||
        uri.host.isEmpty ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('A backend namespace is required.');
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    ).toString();
  }

  String _key(String account) =>
      'myoccasio.deadline-reminders.v1.'
      '${base64Url.encode(utf8.encode('$_namespace\n$account'))}';
  bool _current(int token) =>
      !_disposed && token == _generation && _accountId != null;
  void _require(int token) {
    if (!_current(token)) {
      throw const ApiException(
        'Your session changed. Please try again.',
        statusCode: 401,
      );
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  ReminderSession beginSession(String accountId) {
    if (_disposed || accountId.trim().isEmpty || accountId.length > 256) {
      throw ArgumentError('A signed-in account is required.');
    }
    final token = ++_generation;
    _accountId = accountId;
    _items = [];
    _ready = false;
    _error = null;
    _permission = ReminderPermission.unavailable;
    _initializing = null;
    final session = ReminderSession._(this, token, accountId);
    _session = session;
    unawaited(_initialize(token));
    return session;
  }

  Future<void> _initialize(int token, {bool force = false}) {
    if (!_current(token)) return Future.value();
    if (_initializing != null) return _initializing!;
    if (!force && _ready) return Future.value();
    _ready = false;
    _error = null;
    final account = _accountId!;
    final operation = _enqueue(() async {
      _require(token);
      await platform.cancelAll();
      _require(token);
      final raw = await _storage.read(_key(account));
      _require(token);
      List<DeadlineReminder> restored;
      try {
        restored = raw == null ? [] : _decode(raw, account);
      } on FormatException {
        await _storage.delete(_key(account));
        rethrow;
      }
      _require(token);
      // Recompute from the actual deadline/choice. Date-only reminders follow
      // the device's current time zone after travel; timestamps keep an instant.
      restored = restored
          .map(
            (item) => DeadlineReminder(
              notificationId: item.notificationId,
              opportunityId: item.opportunityId,
              title: item.title,
              deadline: item.deadline,
              daysBefore: item.daysBefore,
              scheduledAt: DeadlineReminder.timeFor(
                item.deadline,
                item.daysBefore,
              )!.toUtc(),
            ),
          )
          .where((item) => item.scheduledAt.isAfter(_now()))
          .toList();
      final permission = await platform.permission();
      _require(token);
      if (permission == ReminderPermission.allowed) {
        for (final item in restored) {
          _require(token);
          await platform.schedule(item, french: _language() == 'fr');
        }
      }
      _require(token);
      await _persist(account, restored);
      _require(token);
      _items = restored;
      _permission = permission;
      _ready = true;
      _timeZoneOffset = _now().timeZoneOffset;
    });
    final handled = operation.then<void>(
      (_) {
        if (_current(token)) _changed();
      },
      onError: (Object _, StackTrace _) {
        if (_current(token)) {
          _error = 'Could not load your device reminders. Please try again.';
          _ready = false;
          _changed();
        }
      },
    );
    _initializing = handled;
    if (force) _changed();
    return handled.whenComplete(() {
      if (_current(token) && identical(_initializing, handled)) {
        _initializing = null;
      }
    });
  }

  String _encode(String account, List<DeadlineReminder> items) => jsonEncode({
    'version': 1,
    'accountId': account,
    'namespace': _namespace,
    'items': items.map((item) => item.toJson()).toList(),
  });

  List<DeadlineReminder> _decode(String raw, String account) {
    if (raw.length > maxStorageBytes ||
        utf8.encode(raw).length > maxStorageBytes) {
      throw const FormatException('Invalid device reminders.');
    }
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data.length != 4 ||
        data['version'] != 1 ||
        data['accountId'] != account ||
        data['namespace'] != _namespace ||
        data['items'] is! List ||
        (data['items'] as List).length > maxReminders) {
      throw const FormatException('Invalid device reminders.');
    }
    final ids = <int>{};
    final opportunities = <String>{};
    return (data['items'] as List).map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid reminder.');
      }
      final item = DeadlineReminder.fromJson(raw);
      if (!ids.add(item.notificationId) ||
          !opportunities.add(item.opportunityId)) {
        throw const FormatException('Duplicate device reminders.');
      }
      return item;
    }).toList();
  }

  Future<void> _persist(String account, List<DeadlineReminder> items) {
    final raw = _encode(account, items);
    if (items.length > maxReminders ||
        utf8.encode(raw).length > maxStorageBytes) {
      throw const ApiException(
        'This device has reached its reminder limit. Remove a reminder first.',
      );
    }
    return _storage.write(_key(account), raw);
  }

  void _needsReconciliation(int token) {
    if (!_current(token)) return;
    _ready = false;
    _error = 'Could not load your device reminders. Please try again.';
    _changed();
  }

  void _requireReady(int token) {
    _require(token);
    if (!_ready) {
      throw const ApiException(
        'Could not load your device reminders. Please try again.',
      );
    }
  }

  Future<void> _save(
    int token, {
    required String opportunityId,
    required String title,
    required String deadline,
    required int daysBefore,
  }) async {
    _require(token);
    await _initialize(token);
    _require(token);
    if (!_ready) {
      throw const ApiException(
        'Could not load your device reminders. Please try again.',
      );
    }
    return _enqueue(() async {
      _requireReady(token);
      final when = DeadlineReminder.timeFor(deadline, daysBefore);
      if (opportunityId.trim().isEmpty ||
          opportunityId.length > 256 ||
          title.trim().isEmpty ||
          title.length > 500 ||
          deadline.length > 80 ||
          when == null ||
          !when.isAfter(_now())) {
        throw const ApiException(
          'Choose a reminder time that is still in the future.',
        );
      }
      var permission = await platform.permission();
      _require(token);
      if (permission == ReminderPermission.denied) {
        permission = await platform.requestPermission();
        _require(token);
      }
      _permission = permission;
      _changed();
      _require(token);
      if (permission != ReminderPermission.allowed) {
        throw const ApiException(
          'Allow notifications in device settings to save a reminder.',
        );
      }
      _items = _items
          .where((item) => item.scheduledAt.isAfter(_now()))
          .toList();
      final matches = _items.where(
        (item) => item.opportunityId == opportunityId,
      );
      final old = matches.isEmpty ? null : matches.first;
      if (old == null && _items.length >= maxReminders) {
        throw const ApiException(
          'This device has reached its reminder limit. Remove a reminder first.',
        );
      }
      final usedIds = _items.map((item) => item.notificationId).toSet();
      var id = old?.notificationId ?? 1;
      if (old == null) {
        while (usedIds.contains(id)) {
          id++;
        }
      }
      final item = DeadlineReminder(
        notificationId: id,
        opportunityId: opportunityId,
        title: title,
        deadline: deadline,
        daysBefore: daysBefore,
        scheduledAt: when.toUtc(),
      );
      final next = [
        ..._items.where((item) => item.opportunityId != opportunityId),
        item,
      ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _require(token);
      try {
        await platform.schedule(item, french: _language() == 'fr');
      } on Object {
        _needsReconciliation(token);
        rethrow;
      }
      _require(token);
      try {
        await _persist(_accountId!, next);
      } on Object {
        _needsReconciliation(token);
        try {
          if (old != null && old.scheduledAt.isAfter(_now())) {
            await platform.schedule(old, french: _language() == 'fr');
          } else {
            await platform.cancel(id);
          }
        } on Object {
          _needsReconciliation(token);
          rethrow;
        }
        rethrow;
      }
      _require(token);
      _items = next;
      _changed();
    });
  }

  Future<void> _remove(int token, String opportunityId) async {
    _require(token);
    await _initialize(token);
    _require(token);
    if (!_ready) {
      throw const ApiException(
        'Could not load your device reminders. Please try again.',
      );
    }
    return _enqueue(() async {
      _requireReady(token);
      final matching = _items.where(
        (item) => item.opportunityId == opportunityId,
      );
      if (matching.isEmpty) return;
      final old = matching.first;
      try {
        await platform.cancel(old.notificationId);
      } on Object {
        _needsReconciliation(token);
        rethrow;
      }
      _require(token);
      final next = _items.where((item) => item != old).toList();
      try {
        await _persist(_accountId!, next);
      } on Object {
        _needsReconciliation(token);
        try {
          if (old.scheduledAt.isAfter(_now())) {
            await platform.schedule(old, french: _language() == 'fr');
          }
        } on Object {
          _needsReconciliation(token);
          rethrow;
        }
        rethrow;
      }
      _require(token);
      _items = next;
      _changed();
    });
  }

  Future<void> _refreshPermission(int token) async {
    var reconcile = false;
    await _enqueue(() async {
      _require(token);
      final permission = await platform.permission();
      _require(token);
      reconcile =
          permission == ReminderPermission.allowed &&
          (_permission != permission ||
              _timeZoneOffset != _now().timeZoneOffset);
      _permission = permission;
      _changed();
    });
    // Never await a queued initializer from within the queue itself.
    if (reconcile) await _initialize(token, force: true);
  }

  Future<void> _end(int token, String account) {
    final wasCurrent = _current(token);
    if (wasCurrent) {
      _generation++;
      _accountId = null;
      _items = [];
      _ready = false;
      _initializing = null;
    }
    final endedGeneration = _generation;
    final operation = _enqueue(() async {
      try {
        if (wasCurrent && _generation == endedGeneration) {
          await platform.cancelAll();
        }
      } finally {
        if (wasCurrent || _accountId != account) {
          await _storage.delete(_key(account));
        }
      }
    });
    // Queue cleanup before notifying: a listener may immediately begin the
    // same account again, whose initialization must follow this deletion.
    if (wasCurrent) _changed();
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class ReminderSession {
  ReminderSession._(this._owner, this._token, this.accountId);
  final DeadlineReminders _owner;
  final int _token;
  final String accountId;
  Listenable get changes => _owner;
  bool get active => _owner._current(_token);
  DateTime get now => _owner._now();
  bool get ready => active && _owner._ready;
  String? get error =>
      active ? _owner._error : 'Your session changed. Please try again.';
  ReminderPermission get permission =>
      active ? _owner._permission : ReminderPermission.unavailable;
  List<DeadlineReminder> get items =>
      active ? List.unmodifiable(_owner._items) : const [];
  Future<void> initialize({bool force = false}) =>
      _owner._initialize(_token, force: force);
  Future<void> refreshPermission() => _owner._refreshPermission(_token);
  Future<void> save({
    required String opportunityId,
    required String title,
    required String deadline,
    required int daysBefore,
  }) => _owner._save(
    _token,
    opportunityId: opportunityId,
    title: title,
    deadline: deadline,
    daysBefore: daysBefore,
  );
  Future<void> remove(String opportunityId) =>
      _owner._remove(_token, opportunityId);
  Future<void> openSettings() async {
    _owner._require(_token);
    await _owner.platform.openSettings();
    _owner._require(_token);
  }

  Future<void> end() => _owner._end(_token, accountId);
}
