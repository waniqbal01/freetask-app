import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/role_gate.dart';
import '../../../data/models/service_model.dart';
import '../../../data/services/order_service.dart';
import '../../../data/services/service_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/app_role.dart';
import '../marketplace_controller.dart';

class ServiceDetailViewArgs {
  const ServiceDetailViewArgs({
    required this.serviceId,
    this.prefetchedService,
  });

  final String serviceId;
  final Service? prefetchedService;
}

class ServiceDetailView extends StatefulWidget {
  const ServiceDetailView({
    super.key,
    required this.serviceId,
    this.initialService,
  });

  final String serviceId;
  final Service? initialService;

  @override
  State<ServiceDetailView> createState() => _ServiceDetailViewState();
}

class _ServiceDetailViewState extends State<ServiceDetailView> {
  Service? _service;
  bool _loading = false;
  String? _error;
  bool _creatingOrder = false;
  MarketplaceController? _controller;

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= MarketplaceController(
      serviceService: RepositoryProvider.of<ServiceService>(context),
      orderService: RepositoryProvider.of<OrderService>(context),
      storageService: RepositoryProvider.of<StorageService>(context),
    );
    if (_service == null && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = _controller!;
      final result = await controller.fetchService(widget.serviceId);
      setState(() => _service = result);
    } catch (error) {
      setState(() => _error = 'Failed to load service details.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startCheckout(Service service) async {
    setState(() => _creatingOrder = true);
    try {
      final controller = _controller!;
      final order = await controller.createOrder(serviceId: service.id);
      if (!mounted) return;
      final email = controller.resolveUserEmail() ?? 'client@example.com';
      Navigator.of(context).pushNamed(
        AppRoutes.checkout,
        arguments: CheckoutViewArgs(
          orderId: order.id,
          amountCents: (order.totalAmount * 100).round(),
          email: email,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start checkout. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = resolveAppRole(context);
    final service = _service;
    final error = _error;
    return RoleGate(
      current: role,
      allow: const [AppRole.client, AppRole.seller, AppRole.admin],
      fallback: const _UnauthorizedView(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Service detail'),
          actions: [
            if (service != null)
              RoleGate(
                current: role,
                allow: const [AppRole.seller, AppRole.admin],
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit service',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.createService,
                    arguments: service,
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _ErrorState(message: error, onRetry: _load)
                : service == null
                    ? const _EmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Chip(
                              label: Text(service.category.isEmpty ? 'General' : service.category),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              service.description,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delivery time',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text('${service.deliveryTime} day(s)'),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Price',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'USD ${service.price.toStringAsFixed(2)}',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            RoleGate(
                              current: role,
                              allow: const [AppRole.client],
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _creatingOrder ? null : () => _startCheckout(service),
                                  child: Text(_creatingOrder ? 'Processing...' : 'Proceed to checkout'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Service not found.'));
  }
}

class _UnauthorizedView extends StatelessWidget {
  const _UnauthorizedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'You are not allowed to view this service.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckoutViewArgs {
  const CheckoutViewArgs({
    required this.orderId,
    required this.amountCents,
    required this.email,
  });

  final String orderId;
  final int amountCents;
  final String email;
}
