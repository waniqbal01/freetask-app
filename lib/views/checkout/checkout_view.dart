import 'package:flutter/material.dart';
import '../../services/payment_service.dart';

class CheckoutView extends StatefulWidget {
  final String orderId;
  final int amountCents;
  final String email;
  const CheckoutView({super.key, required this.orderId, required this.amountCents, required this.email});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _svc = PaymentService();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _pay,
              child: Text(_loading ? 'Processing...' : 'Pay Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(()=>_loading=true);
    try {
      final url = await _svc.createBill(orderId: widget.orderId, amountCents: widget.amountCents, email: widget.email);
      // In real app, use url_launcher and handle deep link redirect.
      // For now, print:
      // ignore: avoid_print
      print('Open payment URL: $url');
      setState(()=>_loading=false);
    } catch (e) {
      setState(()=>_err='Payment error: $e');
      setState(()=>_loading=false);
    }
  }
}
