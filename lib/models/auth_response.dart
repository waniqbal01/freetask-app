import 'user.dart';

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.user,
    this.refreshToken,
    this.expiresAt,
  });

  final String token;
  final User user;
  final String? refreshToken;
  final DateTime? expiresAt;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt'] ?? json['expires_in'] ?? json['expiresIn'];
    DateTime? expiresAt;
    if (expiresRaw is String) {
      expiresAt = DateTime.tryParse(expiresRaw)?.toLocal();
    } else if (expiresRaw is int) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresRaw));
    }

    final rawUser = (json['user'] as Map<String, dynamic>?) ??
        (json['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return AuthResponse(
      token: json['accessToken'] as String? ?? json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ??
          json['refresh_token'] as String? ??
          json['refresh'] as String?,
      expiresAt: expiresAt,
      user: User.fromJson(rawUser),
    );
  }
}
