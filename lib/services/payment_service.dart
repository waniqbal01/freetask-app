import 'package:dio/dio.dart';

import 'session_api_client.dart';

class PaymentService {
  PaymentService(this._apiClient);

  final SessionApiClient _apiClient;

  Future<String> createBill({required String orderId, required int amountCents, required String email}) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/payments/create',
      data: {
        'orderId': orderId,
        'amount': amountCents,
        'email': email,
      },
      options: _apiClient.guard(),
    );
    final data = response.data ?? const <String, dynamic>{};
    final payUrl = data['pay_url'];
    if (payUrl is String && payUrl.isNotEmpty) {
      return payUrl;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: Response<Map<String, dynamic>>(
        requestOptions: response.requestOptions,
        data: data,
        statusCode: response.statusCode,
      ),
      message: 'Missing pay_url in response',
      type: DioExceptionType.badResponse,
    );
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      '/orders/$orderId/status',
      options: _apiClient.guard(),
    );
    return Map<String, dynamic>.from(response.data ?? const <String, dynamic>{});
  }
}
