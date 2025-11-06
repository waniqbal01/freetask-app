import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freetask_app/config/route_guard.dart';
import 'package:freetask_app/config/routes.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/models/user_roles.dart';
import 'package:freetask_app/services/storage_service.dart';
import 'package:freetask_app/views/common/forbidden_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client users are redirected to forbidden view for seller pages', (tester) async {
    final storage = _MockStorageService();
    when(() => storage.role).thenReturn('client');
    when(() => storage.getUser()).thenReturn(
      const User(id: 'u1', name: 'Client', email: 'client@example.com', role: 'client'),
    );

    final guard = RouteGuard(storage);
    final router = AppRouter(guard);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: router.onGenerateRoute,
        navigatorObservers: [guard],
        initialRoute: AppRoutes.sellerDashboard,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ForbiddenView), findsOneWidget);
  });

  test('seller role passes guard checks', () {
    final storage = _MockStorageService();
    when(() => storage.role).thenReturn('seller');
    when(() => storage.getUser()).thenReturn(null);

    final guard = RouteGuard(storage);
    expect(guard.hasRole(UserRoles.seller), isTrue);
    expect(guard.hasRole(UserRoles.admin), isFalse);
  });

  test('admin role passes admin guard check', () {
    final storage = _MockStorageService();
    when(() => storage.role).thenReturn('admin');
    when(() => storage.getUser()).thenReturn(null);

    final guard = RouteGuard(storage);
    expect(guard.hasRole(UserRoles.admin), isTrue);
    expect(guard.hasRole(UserRoles.seller), isFalse);
  });
}
