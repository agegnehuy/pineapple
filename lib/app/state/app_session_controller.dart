import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/data/native_auth_repository.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';

enum AppSessionStatus { loading, authenticated, unauthenticated, failed }

class AppSessionController extends ChangeNotifier {
  AppSessionController(this._auth, {this.nativeAuth});

  final AuthRepository _auth;
  final NativeAuthRepository? nativeAuth;
  AppSessionStatus status = AppSessionStatus.loading;
  AuthSession? session;
  bool _disposed = false;
  int _generation = 0;
  int? _authenticating;
  Future<void>? _restoration;
  Future<void>? _signingOut;
  int? _nativeAuthenticating;
  bool _nativeCancellationRequired = false;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (_nativeAuthenticating != null || nativeAuth?.pending == true) {
      unawaited(nativeAuth?.cancel().catchError((Object _) {}));
    }
    super.dispose();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  /// Retry taps share one restore, which cannot interrupt explicit auth work.
  Future<void> initialize() {
    if (_restoration != null) return _restoration!;
    if (_disposed ||
        _authenticating != null ||
        _nativeCancellationRequired ||
        nativeAuth?.pending == true ||
        _signingOut != null) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    final operation = Future<void>.microtask(() => _restore(generation));
    _restoration = operation;
    status = AppSessionStatus.loading;
    _notifyIfActive();
    return operation;
  }

  Future<void> _restore(int generation) async {
    try {
      if (!_isCurrent(generation)) return;
      final restored = await _auth.currentSession();
      if (!_isCurrent(generation)) return;
      session = restored;
      status = restored.isAuthenticated
          ? AppSessionStatus.authenticated
          : AppSessionStatus.unauthenticated;
      _notifyIfActive();
    } on Object {
      if (!_isCurrent(generation)) return;
      session = null;
      status = AppSessionStatus.failed;
      _notifyIfActive();
    } finally {
      if (generation == _generation) _restoration = null;
    }
  }

  Future<void> signIn({required String email, required String password}) =>
      _authenticate(() => _auth.signIn(email: email, password: password));

  Future<void> signInWithGoogle() => _authenticate(() async {
    final repository = nativeAuth;
    if (repository == null) {
      throw const ApiException(
        'Google sign-in is unavailable. Use your email and password.',
      );
    }
    final operation = _generation;
    _nativeAuthenticating = operation;
    try {
      return await repository.signIn();
    } finally {
      if (_nativeAuthenticating == operation) _nativeAuthenticating = null;
    }
  });

  Future<void> cancelNativeSignIn() async {
    if (_nativeAuthenticating == null &&
        !_nativeCancellationRequired &&
        nativeAuth?.pending != true) {
      return;
    }
    _generation++;
    _nativeCancellationRequired = true;
    await nativeAuth?.cancel();
    _nativeCancellationRequired = false;
    _authenticating = null;
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => _authenticate(
    () => _auth.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    ),
  );

  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    if (_disposed ||
        _authenticating != null ||
        _nativeCancellationRequired ||
        nativeAuth?.pending == true ||
        _restoration != null ||
        _signingOut != null) {
      throw const ApiException('Please wait…');
    }
    final generation = ++_generation;
    _authenticating = generation;
    try {
      final authenticated = await action();
      if (!_isCurrent(generation)) {
        throw const ApiException(
          'Your session changed. Please try again.',
          statusCode: 401,
        );
      }
      session = authenticated;
      status = AppSessionStatus.authenticated;
      _notifyIfActive();
    } finally {
      if (_authenticating == generation) _authenticating = null;
    }
  }

  /// Invalidate older UI operations immediately; the repository owns encrypted
  /// cookie removal and remote sign-out before this reports success.
  Future<void> signOut() {
    if (_signingOut != null) return _signingOut!;
    if (_disposed) return Future<void>.value();
    final generation = ++_generation;
    _authenticating = null;
    _restoration = null;
    final operation = Future<void>.microtask(() => _signOut(generation));
    _signingOut = operation;
    return operation;
  }

  Future<void> _signOut(int generation) async {
    try {
      await nativeAuth?.cancel();
      _nativeCancellationRequired = false;
      await _auth.signOut();
      if (!_isCurrent(generation)) return;
      session = null;
      status = AppSessionStatus.unauthenticated;
      _notifyIfActive();
    } finally {
      if (generation == _generation) _signingOut = null;
    }
  }
}
