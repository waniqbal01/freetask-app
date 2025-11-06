import 'package:bloc_test/bloc_test.dart';
import 'package:freetask_app/controllers/auth/auth_bloc.dart';
import 'package:freetask_app/controllers/auth/auth_event.dart';
import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/repositories/auth_repository.dart';
import 'package:freetask_app/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  const user = User(
    id: 'u1',
    name: 'Test User',
    email: 'test@example.com',
    role: 'client',
  );
  const session = AuthSession(user: user, token: 'token');

  setUp(() {
    repository = _MockAuthRepository();
  });

  group('AuthBloc login flow', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading then authenticated on login success',
      build: () {
        when(
          () => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => session);
        return AuthBloc(repository);
      },
      act: (bloc) =>
          bloc.add(const LoginRequested(email: 'test@example.com', password: 'secret')),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.loading),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.user?.id, 'user id', user.id),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits loading then error on login failure',
      build: () {
        when(
          () => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(AuthException('Invalid credentials'));
        return AuthBloc(repository);
      },
      act: (bloc) =>
          bloc.add(const LoginRequested(email: 'bad@example.com', password: 'wrong')),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.loading),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.message?.isError, 'is error', true),
      ],
    );
  });
}
