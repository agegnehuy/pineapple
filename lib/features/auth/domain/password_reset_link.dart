/// Tokens stay opaque: only the server verifies their signature and expiry.
class PasswordResetLink {
  const PasswordResetLink._(this.token);
  final String? token;
  bool get isValid => token != null;

  /// Null means an unrelated or untrusted URL. A recognized destination with
  /// a missing/malformed token returns an invalid link instead.
  static PasswordResetLink? parse(String input, {bool fromPlatform = false}) {
    if (input.length > 4096) {
      return null;
    }
    final uri = Uri.tryParse(input.trim());
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) {
      return null;
    }
    final bool destination;
    if (uri.scheme == 'https') {
      destination =
          uri.host == 'myoccasio.ca' &&
          (!uri.hasPort || uri.port == 443) &&
          _path(uri.path);
    } else if (uri.scheme == 'ca.occasiotech.myoccasio') {
      destination =
          !uri.hasPort &&
          ((uri.host == 'reset-password' && uri.path.isEmpty) ||
              (uri.host.isEmpty && _path(uri.path)));
    } else {
      destination =
          fromPlatform &&
          !uri.hasScheme &&
          !uri.hasAuthority &&
          _path(uri.path);
    }
    if (!destination) {
      return null;
    }
    final List<String>? values;
    try {
      values = uri.queryParametersAll['token'];
    } on FormatException {
      return const PasswordResetLink._(null);
    }
    if (values == null || values.length != 1 || !validToken(values.single)) {
      return const PasswordResetLink._(null);
    }
    return PasswordResetLink._(values.single);
  }

  static bool validToken(String token) =>
      token.isNotEmpty &&
      token.length <= 2048 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token);
  static bool _path(String path) =>
      path == '/reset-password' || path == '/reset-password/';
  @override
  String toString() => 'PasswordResetLink(${isValid ? 'present' : 'invalid'})';
}
