class AuthSession {
  const AuthSession({required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSession(user: rawUser is Map<String, dynamic> ? rawUser : null);
  }

  final Map<String, dynamic>? user;

  bool get isAuthenticated => user != null;

  String get firstName => (user?['firstName'] ?? '').toString();

  String get email => (user?['email'] ?? '').toString();
}
