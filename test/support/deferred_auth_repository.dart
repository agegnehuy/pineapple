import 'dart:async';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/auth_session.dart';
import 'recording_api.dart';

/// Explicitly controlled async completions for auth ordering regressions.
class DeferredAuthRepository extends AuthRepository {
  DeferredAuthRepository(RecordingApi api) : super(api, MemoryCookieStore());

  final restores = <Completer<AuthSession>>[];
  final signIns = <Completer<AuthSession>>[];
  final registrations = <Completer<AuthSession>>[];
  final signOuts = <Completer<void>>[];

  @override
  Future<AuthSession> currentSession() {
    final operation = Completer<AuthSession>();
    restores.add(operation);
    return operation.future;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    final operation = Completer<AuthSession>();
    signIns.add(operation);
    return operation.future;
  }

  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    final operation = Completer<AuthSession>();
    registrations.add(operation);
    return operation.future;
  }

  @override
  Future<void> signOut() {
    final operation = Completer<void>();
    signOuts.add(operation);
    return operation.future;
  }
}
