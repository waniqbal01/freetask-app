import '../models/bid.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';

class BidService {
  BidService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Bid>> fetchBids(String jobId) async {
    final response = await _apiClient.client.get<List<dynamic>>(
      '/jobs/$jobId/bids',
      options: _apiClient.guard(permission: RolePermission.viewBids),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Bid.fromJson)
        .toList(growable: false);
  }

  Future<Bid> submitBid({
    required String jobId,
    required double amount,
    required String message,
  }) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/jobs/$jobId/bids',
      data: {
        'amount': amount,
        'message': message,
      },
      options: _apiClient.guard(permission: RolePermission.viewBids),
    );
    final data = response.data ?? <String, dynamic>{};
    return Bid.fromJson(data);
  }

  Future<Bid> acceptBid(String jobId, String bidId) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/jobs/$jobId/bids/$bidId/accept',
      options: _apiClient.guard(permission: RolePermission.manageBids),
    );
    final data = response.data ?? <String, dynamic>{};
    return Bid.fromJson(data);
  }

  Future<Bid> rejectBid(String jobId, String bidId) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/jobs/$jobId/bids/$bidId/reject',
      options: _apiClient.guard(permission: RolePermission.manageBids),
    );
    final data = response.data ?? <String, dynamic>{};
    return Bid.fromJson(data);
  }
}
