import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freetask_app/services/payment_service.dart';
import 'package:freetask_app/views/checkout/checkout_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockPaymentService extends Mock implements PaymentService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes payment flow when order is paid', (tester) async {
    final service = _MockPaymentService();
    when(
      () => service.createBill(
        orderId: any(named: 'orderId'),
        amountCents: any(named: 'amountCents'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async => 'https://pay.example.com');
    when(() => service.getOrderStatus(any())).thenAnswer((_) async => {'state': 'paid'});

    var launched = false;
    Future<bool> fakeLauncher(Uri _) async {
      launched = true;
      return true;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CheckoutView(
                      orderId: 'o-1',
                      amountCents: 1000,
                      email: 'buyer@example.com',
                      paymentService: service,
                      launchPaymentUrl: fakeLauncher,
                    ),
                  ),
                ),
                child: const Text('Open checkout'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open checkout'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutView), findsOneWidget);

    await tester.tap(find.text('Pay Now'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(launched, isTrue);
    expect(find.byType(CheckoutView), findsNothing);
  });
}
