import 'package:dio/dio.dart';
import 'package:freetask_app/config/app_env.dart';

class PaymentService {
  final _dio = Dio(BaseOptions(baseUrl: AppEnv.apiBaseUrl));

  Future<String> createBill({required String orderId, required int amountCents, required String email}) async {
    final res = await _dio.post('/payments/create', data: {
      'orderId': orderId,
      'amount': amountCents,
      'email': email,
    });
    // expect { "pay_url": "https://..." }
    return res.data['pay_url'] as String;
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final res = await _dio.get('/orders/$orderId/status');
    return Map<String, dynamic>.from(res.data);
  }
}
