import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:freetask_app/config/app_env.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AppNotification>> fetchNotifications(
    String userToken, {
    NotificationCategory? category,
  }) async {
    final baseUri = Uri.parse('${AppEnv.apiBaseUrl}/notifications');
    final queryParameters = <String, String>{};
    if (category != null && category != NotificationCategory.all) {
      queryParameters['category'] = category.value;
    }
    final uri = queryParameters.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParameters);
    final response = await _client.get(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $userToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }
    final dynamic decoded = json.decode(response.body);
    final List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = (decoded['data'] as List?) ?? const <dynamic>[];
    } else {
      rawList = const <dynamic>[];
    }
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> markAsRead(String id, String userToken) async {
    final response = await _client.post(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/$id/read'),
      headers: <String, String>{'Authorization': 'Bearer $userToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.statusCode}');
    }
  }
}
