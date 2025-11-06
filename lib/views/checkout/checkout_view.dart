import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/payment_service.dart';

class CheckoutView extends StatefulWidget {
  final String orderId;
  final int amountCents;
  final String email;
  final PaymentService? paymentService;
  final Future<bool> Function(Uri uri)? launchPaymentUrl;
  const CheckoutView({
    super.key,
    required this.orderId,
    required this.amountCents,
    required this.email,
    this.paymentService,
    this.launchPaymentUrl,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  late final PaymentService _svc;
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _svc = widget.paymentService ?? PaymentService();
  }

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
    setState(() => _loading = true);
    try {
      final url = await _svc.createBill(
        orderId: widget.orderId,
        amountCents: widget.amountCents,
        email: widget.email,
      );
      final uri = Uri.parse(url);
      final ok = await (widget.launchPaymentUrl != null
          ? widget.launchPaymentUrl!(uri)
          : launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            ));
      if (!ok) {
        setState(() => _err = 'Tidak dapat buka halaman pembayaran');
        setState(() => _loading = false);
        return;
      }
      final success = await _pollStatus(widget.orderId);
      if (success && mounted) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => _err =
              'Bayaran belum disahkan, semak Orders atau cuba lagi',
        );
      }
    } catch (e) {
      setState(() => _err = 'Payment error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _pollStatus(String orderId) async {
    for (var i = 0; i < 20; i++) {
      final res = await _svc.getOrderStatus(orderId);
      if (res['state'] == 'paid') return true;
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }
}
