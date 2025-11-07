import '../../auth/role_permission.dart';
import '../models/order_model.dart';
import '../models/service_model.dart';
import '../../services/session_api_client.dart';

class ServiceService {
  ServiceService(this._client);

  final SessionApiClient _client;

  Future<List<Service>> listServices({
    String? category,
    String? freelancerId,
    String? status,
  }) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/services',
      queryParameters: <String, dynamic>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (freelancerId != null && freelancerId.isNotEmpty) 'freelancerId': freelancerId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      options: _client.guard(
        permission: RolePermission.viewMarketplace,
        requiresAuth: false,
      ),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }

  Future<List<Service>> listOwnServices() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/services/mine',
      options: _client.guard(permission: RolePermission.manageOwnServices),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }

  Future<Service> getService(String id) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/services/$id',
      options: _client.guard(
        permission: RolePermission.viewServiceDetail,
        requiresAuth: false,
      ),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return Service.fromJson(payload);
  }

  Future<Service> createService({
    required String title,
    required String description,
    required String category,
    required double price,
    required int deliveryTime,
    List<String> media = const [],
    String status = 'published',
  }) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '/api/services',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'deliveryTime': deliveryTime,
        'media': media,
        'status': status,
      },
      options: _client.guard(permission: RolePermission.manageOwnServices),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return Service.fromJson(payload);
  }

  Future<Service> updateService(
    String id, {
    String? title,
    String? description,
    String? category,
    double? price,
    int? deliveryTime,
    List<String>? media,
    String? status,
  }) async {
    final response = await _client.client.put<Map<String, dynamic>>(
      '/api/services/$id',
      data: <String, dynamic>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (price != null) 'price': price,
        if (deliveryTime != null) 'deliveryTime': deliveryTime,
        if (media != null) 'media': media,
        if (status != null) 'status': status,
      },
      options: _client.guard(permission: RolePermission.manageOwnServices),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return Service.fromJson(payload);
  }

  Future<List<OrderModel>> fetchSellerOrders() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/orders',
      options: _client.guard(permission: RolePermission.manageSellerOrders),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList(growable: false);
  }
}
