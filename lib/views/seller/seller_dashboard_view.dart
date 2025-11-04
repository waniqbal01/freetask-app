import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../models/order.dart';
import '../../models/service.dart';
import '../../models/payout.dart';
import '../../models/transaction.dart';
import '../../services/admin_service.dart';
import '../../services/marketplace_service.dart';
import '../../services/order_service.dart';
import '../../services/storage_service.dart';
import '../../auth/role_permission.dart';
import '../../models/user_roles.dart';
import '../../widgets/role_gate.dart';
import '../marketplace/service_detail_view.dart';

class SellerDashboardView extends StatefulWidget {
  const SellerDashboardView({super.key});

  @override
  State<SellerDashboardView> createState() => _SellerDashboardViewState();
}

class _SellerDashboardViewState extends State<SellerDashboardView> {
  late Future<List<Service>> _servicesFuture;
  late Future<List<OrderModel>> _ordersFuture;
  Future<List<Service>>? _adminServicesFuture;
  Future<List<TransactionModel>>? _transactionsFuture;
  Future<List<PayoutModel>>? _payoutsFuture;
  bool _checkedAdmin = false;

  MarketplaceService get _marketplace => RepositoryProvider.of<MarketplaceService>(context);
  OrderService get _orders => RepositoryProvider.of<OrderService>(context);
  StorageService get _storage => RepositoryProvider.of<StorageService>(context);

  bool get _isAdmin {
    final role = _storage.role ?? _storage.getUser()?.role;
    final parsedRole = parseUserRole(role);
    return parsedRole == UserRoles.admin ||
        parsedRole == UserRoles.manager ||
        parsedRole == UserRoles.support;
  }

  AdminService? get _adminService => _isAdmin ? RepositoryProvider.of<AdminService>(context) : null;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _marketplace.listOwnServices();
    _ordersFuture = _orders.listOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedAdmin && _isAdmin) {
      _checkedAdmin = true;
      final admin = _adminService;
      if (admin != null) {
        _adminServicesFuture = admin.listServices();
        _transactionsFuture = admin.listTransactions();
        _payoutsFuture = admin.listPayouts();
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _servicesFuture = _marketplace.listOwnServices();
      _ordersFuture = _orders.listOrders();
      if (_isAdmin && _adminService != null) {
        _adminServicesFuture = _adminService!.listServices();
        _transactionsFuture = _adminService!.listTransactions();
        _payoutsFuture = _adminService!.listPayouts();
      }
    });
    final futures = <Future<dynamic>>[_servicesFuture, _ordersFuture];
    if (_isAdmin) {
      if (_adminServicesFuture != null) futures.add(_adminServicesFuture!);
      if (_transactionsFuture != null) futures.add(_transactionsFuture!);
      if (_payoutsFuture != null) futures.add(_payoutsFuture!);
    }
    await Future.wait(futures);
  }

  Future<void> _refundOrder(String orderId) async {
    final admin = _adminService;
    if (admin == null) return;
    try {
      await admin.refundOrder(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order refunded.')),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refund order.')),
        );
      }
    }
  }

  Future<void> _releasePayout(String payoutId) async {
    final admin = _adminService;
    if (admin == null) return;
    try {
      await admin.releasePayout(payoutId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout released.')),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to release payout.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleGate(
      permission: RolePermission.accessSellerDashboard,
      fallback: const _UnauthorizedSellerView(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seller dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Create service',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.createService),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Your services', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<List<Service>>(
                future: _servicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final services = snapshot.data ?? const <Service>[];
                  if (services.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No services yet. Create your first offering!'),
                    );
                  }
                  return Column(
                    children: [
                      for (final service in services)
                        Card(
                          child: ListTile(
                            title: Text(service.title),
                            subtitle: Text('USD ${service.price.toStringAsFixed(2)} • ${service.status}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.serviceDetail,
                              arguments: ServiceDetailViewArgs(
                                serviceId: service.id,
                                prefetchedService: service,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Recent orders', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<List<OrderModel>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orders = snapshot.data ?? const <OrderModel>[];
                  if (orders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No orders yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final order in orders)
                        Card(
                          child: ListTile(
                            title: Text(order.service?.title ?? 'Service order'),
                            subtitle: Text('Status: ${order.status}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.orderDetail,
                              arguments: OrderDetailViewArgs(orderId: order.id),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 24),
                Text('Admin moderation', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                FutureBuilder<List<Service>>(
                  future: _adminServicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final services = snapshot.data ?? const <Service>[];
                    if (services.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No services to moderate.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final service in services)
                          Card(
                            child: ListTile(
                              title: Text(service.title),
                              subtitle: Text('Status: ${service.status}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.serviceDetail,
                                arguments: ServiceDetailViewArgs(
                                  serviceId: service.id,
                                  prefetchedService: service,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Transactions', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<List<TransactionModel>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final transactions = snapshot.data ?? const <TransactionModel>[];
                    if (transactions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No transactions recorded.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final transaction in transactions.take(10))
                          ListTile(
                            title: Text('Order ${transaction.orderId}'),
                            subtitle: Text(
                              'Status: ${transaction.status} • Amount: USD ${transaction.amount.toStringAsFixed(2)}',
                            ),
                            trailing: transaction.status == 'escrow'
                                ? TextButton(
                                    onPressed: () => _refundOrder(transaction.orderId),
                                    child: const Text('Refund'),
                                  )
                                : null,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Payouts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<List<PayoutModel>>(
                  future: _payoutsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final payouts = snapshot.data ?? const <PayoutModel>[];
                    if (payouts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No payouts available.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final payout in payouts.take(10))
                          ListTile(
                            title: Text('Payout ${payout.id}'),
                            subtitle: Text(
                              'Status: ${payout.status} • Amount: USD ${payout.amount.toStringAsFixed(2)}',
                            ),
                            trailing: payout.status == 'pending'
                                ? TextButton(
                                    onPressed: () => _releasePayout(payout.id),
                                    child: const Text('Release'),
                                  )
                                : null,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnauthorizedSellerView extends StatelessWidget {
  const _UnauthorizedSellerView();

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
                'Only freelancers and admins can access the seller dashboard.',
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
