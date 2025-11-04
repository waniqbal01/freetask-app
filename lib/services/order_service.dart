import '../auth/role_permission.dart';
import '../models/order.dart';
import 'api_client.dart';

class OrderService {
  OrderService(this._client);

  final ApiClient _client;

  Future<OrderModel> createOrder({
    required String serviceId,
    String? requirements,
  }) async {
    final response = await _client.client.post<Map<String, dynamic>>(
      '/api/orders',
      data: {
        'serviceId': serviceId,
        if (requirements != null) 'requirements': requirements,
      },
      options: _client.guard(permission: RolePermission.purchaseServices),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<List<OrderModel>> listOrders() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/orders',
      options: _client.guard(permission: RolePermission.viewOrders),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList(growable: false);
  }

  Future<OrderModel> getOrder(String id) async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/orders/$id',
      options: _client.guard(permission: RolePermission.viewOrders),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<OrderModel> acceptOrder(String id) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/orders/$id/accept',
      options: _client.guard(permission: RolePermission.manageSellerOrders),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<OrderModel> deliverOrder(
    String id, {
    required String deliveredWork,
    String? revisionNotes,
  }) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/orders/$id/deliver',
      data: {
        'deliveredWork': deliveredWork,
        if (revisionNotes != null) 'revisionNotes': revisionNotes,
      },
      options: _client.guard(permission: RolePermission.manageSellerOrders),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<OrderModel> completeOrder(String id) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/orders/$id/complete',
      options: _client.guard(permission: RolePermission.manageBuyerOrders),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<OrderModel> cancelOrder(String id) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/orders/$id/cancel',
      options: _client.guard(permission: RolePermission.viewOrders),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }
}
