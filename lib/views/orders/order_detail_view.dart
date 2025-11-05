import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/order.dart';
import '../../models/service.dart';
import '../../services/order_service.dart';
import '../../utils/app_role.dart';
import '../../utils/role_gate.dart';

class OrderDetailViewArgs {
  const OrderDetailViewArgs({
    required this.orderId,
    this.clientId,
    this.isEditable = true,
  });

  final String orderId;
  final String? clientId;
  final bool isEditable;
}

class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.orderId,
    this.clientId,
    this.isEditable = true,
  });

  final String orderId;
  final String? clientId;
  final bool isEditable;

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  OrderModel? _order;
  bool _loading = false;
  String? _error;

  OrderService get _orders => RepositoryProvider.of<OrderService>(context);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _orders.getOrder(widget.orderId);
      setState(() => _order = result);
    } catch (error) {
      setState(() => _error = 'Unable to load order.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept() async {
    await _perform(() => _orders.acceptOrder(widget.orderId));
  }

  Future<void> _deliver() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deliver work'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Delivery notes or link',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty) return;
    await _perform(() => _orders.deliverOrder(widget.orderId, deliveredWork: result));
  }

  Future<void> _complete() async {
    await _perform(() => _orders.completeOrder(widget.orderId));
  }

  Future<void> _cancel() async {
    await _perform(() => _orders.cancelOrder(widget.orderId));
  }

  Future<void> _perform(Future<OrderModel> Function() task) async {
    setState(() => _loading = true);
    try {
      final updated = await task();
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = resolveAppRole(context);
    return RoleGate(
      current: role,
      allow: const [AppRole.client, AppRole.seller, AppRole.admin],
      fallback: const _UnauthorizedOrderView(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Order detail')),
        body: _loading && _order == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _fetch)
                : _order == null
                    ? const _EmptyOrderView()
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            _OrderSummaryCard(order: _order!),
                            const SizedBox(height: 24),
                            if (_order!.service != null)
                              _ServiceSummaryCard(service: _order!.service!),
                            const SizedBox(height: 24),
                            _OrderActions(
                              order: _order!,
                              onAccept: _accept,
                              onDeliver: _deliver,
                              onComplete: _complete,
                              onCancel: _cancel,
                              loading: _loading,
                              isEditable: widget.isEditable,
                              role: role,
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${order.status}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Total paid: USD ${order.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            if (order.requirements != null && order.requirements!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Requirements', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(order.requirements!),
                ],
              ),
            if (order.deliveredWork != null && order.deliveredWork!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Delivered work', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(order.deliveredWork!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceSummaryCard extends StatelessWidget {
  const _ServiceSummaryCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(service.description, maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.onAccept,
    required this.onDeliver,
    required this.onComplete,
    required this.onCancel,
    required this.loading,
    required this.isEditable,
    required this.role,
  });

  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onDeliver;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final bool loading;
  final bool isEditable;
  final AppRole role;

  bool get _isPending => order.status == 'pending';
  bool get _isAccepted => order.status == 'accepted';
  bool get _isDelivered => order.status == 'delivered';
  bool get _isCompleted => order.status == 'completed';

  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      return const SizedBox.shrink();
    }
    final buttons = <Widget>[];

    buttons.add(
      RoleGate(
        current: role,
        allow: const [AppRole.client, AppRole.admin],
        child: ElevatedButton.icon(
          onPressed: loading ? null : onCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel order'),
        ),
      ),
    );

    if (_isPending) {
      buttons.add(
        RoleGate(
          current: role,
          allow: const [AppRole.seller, AppRole.admin],
          child: ElevatedButton.icon(
            onPressed: loading ? null : onAccept,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Accept order'),
          ),
        ),
      );
    }

    if (_isAccepted || _isPending) {
      buttons.add(
        RoleGate(
          current: role,
          allow: const [AppRole.seller, AppRole.admin],
          child: ElevatedButton.icon(
            onPressed: loading ? null : onDeliver,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Deliver work'),
          ),
        ),
      );
    }

    if (_isDelivered) {
      buttons.add(
        RoleGate(
          current: role,
          allow: const [AppRole.client, AppRole.admin],
          child: ElevatedButton.icon(
            onPressed: loading ? null : onComplete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark as complete'),
          ),
        ),
      );
    }

    if (_isCompleted) {
      buttons.add(
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Order completed. Payout will be processed shortly.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buttons
          .map((button) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: button,
              ))
          .toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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

class _EmptyOrderView extends StatelessWidget {
  const _EmptyOrderView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Order not found.'));
  }
}

class _UnauthorizedOrderView extends StatelessWidget {
  const _UnauthorizedOrderView();

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
                'You are not allowed to view this order.',
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
