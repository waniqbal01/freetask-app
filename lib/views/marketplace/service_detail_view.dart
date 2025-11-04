import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/role_permission.dart';
import '../../config/routes.dart';
import '../../models/service.dart';
import '../../services/marketplace_service.dart';
import '../../widgets/role_gate.dart';

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

  MarketplaceService get _serviceApi => RepositoryProvider.of<MarketplaceService>(context);

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
    if (_service == null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _serviceApi.getService(widget.serviceId);
      setState(() => _service = result);
    } catch (error) {
      setState(() => _error = 'Failed to load service details.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startCheckout(Service service) {
    Navigator.of(context).pushNamed(
      AppRoutes.checkout,
      arguments: CheckoutViewArgs(service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleGate(
      permission: RolePermission.viewServiceDetail,
      fallback: const _UnauthorizedView(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Service detail'),
          actions: [
            if (_service != null)
              RoleGate(
                permission: RolePermission.manageOwnServices,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit service',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.createService,
                    arguments: _service,
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _service == null
                    ? const _EmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _service!.title,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Chip(
                              label: Text(_service!.category.isEmpty ? 'General' : _service!.category),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _service!.description,
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
                                    Text('${_service!.deliveryTime} day(s)'),
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
                                      'USD ${_service!.price.toStringAsFixed(2)}',
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
                              permission: RolePermission.purchaseServices,
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _startCheckout(_service!),
                                  child: const Text('Proceed to checkout'),
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
  const CheckoutViewArgs({required this.service});

  final Service service;
}
