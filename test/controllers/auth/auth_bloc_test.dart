import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:freetask_app/controllers/auth/auth_bloc.dart';
import 'package:freetask_app/controllers/auth/auth_event.dart';
import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/models/auth_response.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/services/auth_service.dart';
import 'package:freetask_app/services/storage_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockAuthService authService;
  late MockStorageService storageService;

  setUp(() {
    authService = MockAuthService();
    storageService = MockStorageService();

    when(() => storageService.token).thenReturn(null);
    when(() => storageService.getUser()).thenReturn(null);
  });

  test('initial state is loading', () {
    final bloc = AuthBloc(authService, storageService);
    expect(bloc.state, const AuthLoading());
    bloc.close();
  });

  blocTest<AuthBloc, AuthState>(
    'emits unauthenticated when app launched without token',
    build: () {
      when(() => storageService.token).thenReturn(null);
      return AuthBloc(authService, storageService);
    },
    act: (bloc) => bloc.add(const AppLaunched()),
    expect: () => [const AuthUnauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'emits loading then authenticated on successful login',
    build: () {
      final user = const User(
        id: '1',
        name: 'Jane Doe',
        email: 'jane@example.com',
        role: 'client',
        verified: true,
      );
      when(
        () => authService.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse(token: 'token', user: user));
      return AuthBloc(authService, storageService);
    },
    act: (bloc) => bloc.add(
      const LoginSubmitted(email: 'jane@example.com', password: 'password'),
    ),
    expect: () => [
      const AuthLoading(),
      isA<AuthAuthenticated>().having((state) => state.user.email, 'user email',
          'jane@example.com'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits unauthenticated after logout request',
    build: () {
      when(() => authService.logout()).thenAnswer((_) async {});
      return AuthBloc(authService, storageService);
    },
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [const AuthUnauthenticated()],
  );
}
