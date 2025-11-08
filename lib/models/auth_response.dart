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
    Map<String, dynamic> payload = json;

    String? readString(dynamic value) {
      if (value is String) {
        return value;
      }
      if (value is num || value is bool) {
        return value.toString();
      }
      return null;
    }

    String? firstString(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        final value = readString(map[key]);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    bool hasTokenLikeField(Map<String, dynamic> data) {
      return firstString(data, const [
            'accessToken',
            'access_token',
            'access-token',
            'token',
            'jwt',
            'bearerToken',
            'bearer_token',
            'access'
          ]) !=
          null;
    }

    Map<String, dynamic> resolvePayload(Map<String, dynamic> source) {
      Map<String, dynamic> current = source;
      for (var depth = 0; depth < 6; depth++) {
        if (hasTokenLikeField(current)) {
          return current;
        }

        final candidates = [
          current['data'],
          current['result'],
          current['payload'],
          current['attributes'],
          current['token'],
        ];

        final next = candidates.firstWhere(
          (value) => value is Map<String, dynamic>,
          orElse: () => null,
        );

        if (next is Map<String, dynamic>) {
          current = next;
          continue;
        }

        break;
      }

      return current;
    }

    Map<String, dynamic>? mapOrNull(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      return null;
    }

    Map<String, dynamic>? extractUser(Map<String, dynamic>? source) {
      if (source == null) {
        return null;
      }
      return mapOrNull(source['user']) ?? mapOrNull(source['profile']);
    }

    payload = resolvePayload(payload);

    final expiresRaw = payload['expiresAt'] ??
        payload['expires_at'] ??
        payload['expires_in'] ??
        payload['expiresIn'] ??
        json['expiresAt'] ??
        json['expires_at'] ??
        json['expires_in'] ??
        json['expiresIn'];

    final rawUser = extractUser(payload) ??
        extractUser(mapOrNull(json['data'])) ??
        extractUser(mapOrNull(json['result'])) ??
        extractUser(mapOrNull(json['payload'])) ??
        extractUser(json) ??
        const <String, dynamic>{};

    return AuthResponse(
      token: firstString(payload, const [
            'accessToken',
            'access_token',
            'access-token',
            'token',
            'jwt',
            'bearerToken',
            'bearer_token',
            'access'
          ]) ??
          '',
      refreshToken: firstString(payload, const [
            'refreshToken',
            'refresh_token',
            'refresh-token',
            'refresh'
          ]),
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
