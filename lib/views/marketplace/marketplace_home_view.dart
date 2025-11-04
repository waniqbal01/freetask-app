import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../auth/role_permission.dart';
import '../../models/service.dart';
import '../../services/marketplace_service.dart';
import '../../widgets/role_gate.dart';

class MarketplaceHomeView extends StatefulWidget {
  const MarketplaceHomeView({super.key});

  @override
  State<MarketplaceHomeView> createState() => _MarketplaceHomeViewState();
}

class _MarketplaceHomeViewState extends State<MarketplaceHomeView> {
  late Future<List<Service>> _servicesFuture;

  MarketplaceService get _service => RepositoryProvider.of<MarketplaceService>(context);

  @override
  void initState() {
    super.initState();
    _servicesFuture = _loadServices();
  }

  Future<List<Service>> _loadServices() {
    return _service.listServices();
  }

  Future<void> _refresh() async {
    setState(() {
      _servicesFuture = _loadServices();
    });
    await _servicesFuture;
  }

  void _openService(Service service) {
    Navigator.of(context).pushNamed(
      AppRoutes.serviceDetail,
      arguments: ServiceDetailViewArgs(serviceId: service.id, prefetchedService: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleGate(
      permission: RolePermission.viewMarketplace,
      fallback: const _UnauthorizedMessage(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          actions: [
            RoleGate(
              permission: RolePermission.manageOwnServices,
              child: IconButton(
                tooltip: 'Create service',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.createService),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Service>>(
            future: _servicesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'We were unable to load services.',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull to refresh to try again.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              final services = snapshot.data ?? const <Service>[];
              if (services.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No services available yet. Check back soon!'),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _ServiceCard(
                    service: service,
                    onTap: () => _openService(service),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              service.description,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(service.category.isEmpty ? 'General' : service.category),
                ),
                Text(
                  'USD ${service.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnauthorizedMessage extends StatelessWidget {
  const _UnauthorizedMessage();

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
                'You do not have access to the marketplace.',
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

class ServiceDetailViewArgs {
  const ServiceDetailViewArgs({
    required this.serviceId,
    this.prefetchedService,
  });

  final String serviceId;
  final Service? prefetchedService;
}
