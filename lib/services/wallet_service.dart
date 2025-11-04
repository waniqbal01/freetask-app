import '../auth/role_permission.dart';
import '../models/payment.dart';
import 'api_client.dart';

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.pending,
    required this.released,
    required this.withdrawn,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ??
          (json['escrow'] as num?)?.toDouble() ??
          0,
      released: (json['released'] as num?)?.toDouble() ?? 0,
      withdrawn: (json['withdrawn'] as num?)?.toDouble() ?? 0,
    );
  }

  final double balance;
  final double pending;
  final double released;
  final double withdrawn;
}

class WalletService {
  WalletService(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletSummary> fetchSummary() async {
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      '/wallet',
      options: _apiClient.guard(permission: RolePermission.viewWallet),
    );
    final data = response.data ?? <String, dynamic>{};
    return WalletSummary.fromJson(data);
  }

  Future<List<Payment>> fetchPayments() async {
    final response = await _apiClient.client.get<List<dynamic>>(
      '/wallet/payments',
      options: _apiClient.guard(permission: RolePermission.viewWallet),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Payment.fromJson)
        .toList(growable: false);
  }

  Future<Payment> releasePayment(String paymentId) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/wallet/payments/$paymentId/release',
      options: _apiClient.guard(permission: RolePermission.releasePayment),
    );
    final data = response.data ?? <String, dynamic>{};
    return Payment.fromJson(data);
  }
}
