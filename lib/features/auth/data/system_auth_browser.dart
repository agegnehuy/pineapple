import 'package:flutter/services.dart';

class NativeAuthCancelled implements Exception {
  const NativeAuthCancelled();
}

abstract interface class AuthBrowser {
  Future<Uri> authenticate(Uri url);
  Future<void> cancel();
}

/// Credentials stay in the system browser; only the one-use callback returns.
class SystemAuthBrowser implements AuthBrowser {
  static const _channel = MethodChannel(
    'ca.occasiotech.myoccasio/authentication',
  );

  @override
  Future<Uri> authenticate(Uri url) async {
    try {
      final result = await _channel.invokeMethod<String>('authenticate', {
        'url': url.toString(),
      });
      if (result == null) throw const NativeAuthCancelled();
      return Uri.parse(result);
    } on PlatformException catch (error) {
      if (error.code == 'cancelled' || error.code == 'interrupted') {
        throw const NativeAuthCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
