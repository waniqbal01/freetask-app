import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/controllers/auth/auth_bloc.dart';
import 'package:freetask_app/controllers/auth/auth_event.dart';
import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/repositories/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  test('initial state has unknown status', () {
    final bloc = AuthBloc(repository);
    expect(bloc.state.status, AuthStatus.unknown);
    bloc.close();
  });

  blocTest<AuthBloc, AuthState>(
    'emits loading then unauthenticated when restoreSession returns null',
    build: () {
      when(() => repository.restoreSession()).thenAnswer((_) async => null);
      return AuthBloc(repository);
    },
    act: (bloc) => bloc.add(const AuthCheckRequested()),
    expect: () => [
      const AuthState(status: AuthStatus.loading, flow: AuthFlow.general),
      const AuthState(status: AuthStatus.unauthenticated, flow: AuthFlow.general),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits authenticated state after successful login',
    build: () {
      final user = const User(
        id: '1',
        name: 'Jane Doe',
        email: 'jane@example.com',
        role: 'client',
        verified: true,
      );
      final session = AuthSession(
        user: user,
        token: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );
      when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => session);
      return AuthBloc(repository);
    },
    act: (bloc) => bloc.add(
      const LoginRequested(email: 'jane@example.com', password: 'password'),
    ),
    expect: () => [
      const AuthState(status: AuthStatus.loading, flow: AuthFlow.login),
      predicate<AuthState>((state) =>
          state.status == AuthStatus.authenticated && state.user?.email == 'jane@example.com'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits unauthenticated after logout request',
    build: () {
      when(() => repository.logout()).thenAnswer((_) async {});
      return AuthBloc(repository);
    },
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [
      const AuthState(status: AuthStatus.unauthenticated, flow: AuthFlow.general),
    ],
  );
}
