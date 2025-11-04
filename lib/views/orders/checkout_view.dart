import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../models/service.dart';
import '../../services/order_service.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/role_gate.dart';
import '../marketplace/service_detail_view.dart';

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key, this.service});

  final Service? service;

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _requirementsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  OrderService get _orders => RepositoryProvider.of<OrderService>(context);

  @override
  void dispose() {
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _submit(Service service) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await _orders.createOrder(
        serviceId: service.id,
        requirements: _requirementsController.text.trim().isEmpty
            ? null
            : _requirementsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.orderDetail,
        (route) => route.isFirst,
        arguments: OrderDetailViewArgs(orderId: order.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully.')),
      );
    } catch (error) {
      setState(() => _error = 'Unable to create order. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final theme = Theme.of(context);
    return RoleGate(
      permission: RolePermission.checkoutService,
      fallback: const _UnauthorizedCheckoutView(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: service == null
            ? const _MissingServiceView()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(service.description, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery: ${service.deliveryTime} day(s)'),
                        Text(
                          'Total: USD ${service.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _requirementsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Requirements for the freelancer',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : () => _submit(service),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Confirm purchase'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MissingServiceView extends StatelessWidget {
  const _MissingServiceView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No service was provided for checkout.'),
      ),
    );
  }
}

class _UnauthorizedCheckoutView extends StatelessWidget {
  const _UnauthorizedCheckoutView();

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
                'Only clients can checkout services.',
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

class OrderDetailViewArgs {
  const OrderDetailViewArgs({required this.orderId});

  final String orderId;
}
