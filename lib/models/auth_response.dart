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

    final rawUser = (json['user'] as Map<String, dynamic>?) ??
        (json['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return AuthResponse(
      token: json['accessToken'] as String? ?? json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ??
          json['refresh_token'] as String? ??
          json['refresh'] as String?,
      expiresAt: AuthResponse.parseExpiry(expiresRaw),
      user: User.fromJson(rawUser),
    );
  }

  static DateTime? parseExpiry(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is String) {
      final parsedDate = DateTime.tryParse(raw);
      if (parsedDate != null) {
        return parsedDate.toLocal();
      }
      final parsedInt = int.tryParse(raw);
      if (parsedInt != null) {
        return DateTime.now().add(Duration(seconds: parsedInt));
      }
    }

    if (raw is num) {
      // Treat large numbers as epoch milliseconds to support backend variants
      // that return absolute expiry timestamps, while smaller numbers are
      // interpreted as relative seconds.
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw.toInt()).toLocal();
      }
      return DateTime.now().add(Duration(seconds: raw.toInt()));
    }

    return null;
  }
}
