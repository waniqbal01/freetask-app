import '../models/order.dart';
import '../models/payout.dart';
import '../models/service.dart';
import '../models/transaction.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';

class AdminService {
  AdminService(this._client);

  final ApiClient _client;

  Future<List<Service>> listServices() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/admin/services',
      options: _client.guard(permission: RolePermission.accessAdminConsole),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }

  Future<Service> updateServiceStatus(String id, String status) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/admin/services/$id/status',
      data: {'status': status},
      options: _client.guard(permission: RolePermission.moderateServices),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return Service.fromJson(payload);
  }

  Future<List<OrderModel>> listOrders() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/admin/orders',
      options: _client.guard(permission: RolePermission.accessAdminConsole),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList(growable: false);
  }

  Future<OrderModel> refundOrder(String id) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/admin/orders/$id/refund',
      options: _client.guard(permission: RolePermission.accessAdminConsole),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return OrderModel.fromJson(payload);
  }

  Future<List<TransactionModel>> listTransactions() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/admin/transactions',
      options: _client.guard(permission: RolePermission.manageTransactions),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(TransactionModel.fromJson)
        .toList(growable: false);
  }

  Future<List<PayoutModel>> listPayouts() async {
    final response = await _client.client.get<Map<String, dynamic>>(
      '/api/admin/payouts',
      options: _client.guard(permission: RolePermission.managePayouts),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PayoutModel.fromJson)
        .toList(growable: false);
  }

  Future<PayoutModel> releasePayout(String id) async {
    final response = await _client.client.patch<Map<String, dynamic>>(
      '/api/admin/payouts/$id/release',
      options: _client.guard(permission: RolePermission.managePayouts),
    );
    final payload = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return PayoutModel.fromJson(payload);
  }
}
