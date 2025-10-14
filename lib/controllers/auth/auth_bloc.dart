import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authService, this._storage)
      : super(const AuthLoading()) {
    on<AppLaunched>(_onAppLaunched);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<SignupSubmitted>(_onSignupSubmitted);
    on<FetchMe>(_onFetchMe);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final AuthService _authService;
  final StorageService _storage;

  Future<void> _onAppLaunched(
    AppLaunched event,
    Emitter<AuthState> emit,
  ) async {
    final token = _storage.token;
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    final cachedUser = _storage.getUser();
    if (cachedUser != null) {
      emit(AuthAuthenticated(cachedUser));
    } else {
      emit(const AuthLoading());
    }

    add(const FetchMe());
  }

  Future<void> _onFetchMe(
    FetchMe event,
    Emitter<AuthState> emit,
  ) async {
    final previousState = state;
    if (previousState is! AuthAuthenticated) {
      emit(const AuthLoading());
    }
    try {
      final User user = await _authService.fetchMe();
      emit(AuthAuthenticated(user));
    } on AuthException catch (error, stackTrace) {
      appLog('Fetch me failed', error: error, stackTrace: stackTrace);
      emit(AuthError(error.message));
      emit(const AuthUnauthenticated());
    } catch (error, stackTrace) {
      appLog('Unexpected error on FetchMe', error: error, stackTrace: stackTrace);
      emit(const AuthError('Unexpected error occurred.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authService.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(authResponse.user));
    } on AuthException catch (error, stackTrace) {
      appLog('Login failed', error: error, stackTrace: stackTrace);
      emit(AuthError(error.message));
      emit(const AuthUnauthenticated());
    } catch (error, stackTrace) {
      appLog('Unexpected error on login', error: error, stackTrace: stackTrace);
      emit(const AuthError('Unexpected error occurred.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignupSubmitted(
    SignupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authService.signup(
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      emit(AuthAuthenticated(authResponse.user));
    } on AuthException catch (error, stackTrace) {
      appLog('Signup failed', error: error, stackTrace: stackTrace);
      emit(AuthError(error.message));
      emit(const AuthUnauthenticated());
    } catch (error, stackTrace) {
      appLog('Unexpected error on signup', error: error, stackTrace: stackTrace);
      emit(const AuthError('Unexpected error occurred.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.logout();
    emit(const AuthUnauthenticated());
  }
}
