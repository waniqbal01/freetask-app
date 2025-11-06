import '../../data/models/order_model.dart';
import '../../data/models/service_model.dart';
import '../../data/services/order_service.dart';
import '../../data/services/service_service.dart';
import '../../services/storage_service.dart';

class MarketplaceController {
  MarketplaceController({
    required ServiceService serviceService,
    required OrderService orderService,
    required StorageService storageService,
  })  : _serviceService = serviceService,
        _orderService = orderService,
        _storageService = storageService;

  final ServiceService _serviceService;
  final OrderService _orderService;
  final StorageService _storageService;

  Future<List<Service>> fetchServices({
    String? category,
    String? freelancerId,
    String? status,
  }) {
    return _serviceService.listServices(
      category: category,
      freelancerId: freelancerId,
      status: status,
    );
  }

  Future<Service> fetchService(String id) {
    return _serviceService.getService(id);
  }

  Future<OrderModel> createOrder({
    required String serviceId,
    String? requirements,
  }) {
    return _orderService.createOrder(
      serviceId: serviceId,
      requirements: requirements,
    );
  }

  String? resolveUserEmail() {
    final user = _storageService.getUser();
    final email = user?.email.trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }
    return null;
  }
}
