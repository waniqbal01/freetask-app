import 'package:bloc/bloc.dart';

import '../../repositories/auth_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(AuthState.initial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<SignupRequested>(_onSignupRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
  }

  final AuthRepository _repository;

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.general,
        clearMessage: true,
      ),
    );

    try {
      final session = await _repository.restoreSession();
      if (session == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            flow: AuthFlow.general,
            resetUser: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
          flow: AuthFlow.general,
          clearMessage: true,
        ),
      );
    } on AuthException catch (error, stackTrace) {
      AppLogger.e('Auth check failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.general,
          message: AuthMessage.error(error.message),
          resetUser: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error during auth check',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.general,
          message: AuthMessage.error('Unexpected error occurred.'),
          resetUser: true,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.login,
        clearMessage: true,
      ),
    );

    try {
      final session = await _repository.login(
        email: event.email,
        password: event.password,
      );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
          flow: AuthFlow.login,
          message: AuthMessage.success(
            'Welcome back, ${session.user.name.split(' ').first}!',
          ),
        ),
      );
    } on AuthException catch (error, stackTrace) {
      AppLogger.e('Login failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.login,
          message: AuthMessage.error(error.message),
          resetUser: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error on login', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.login,
          message: const AuthMessage.error('Unexpected error occurred.'),
          resetUser: true,
        ),
      );
    }
  }

  Future<void> _onSignupRequested(
    SignupRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.signup,
        clearMessage: true,
      ),
    );

    try {
      final session = await _repository.signup(
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
          flow: AuthFlow.signup,
          message: AuthMessage.success(
            'Account created successfully. Please verify your email.',
          ),
        ),
      );
    } on AuthException catch (error, stackTrace) {
      AppLogger.e('Signup failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.signup,
          message: AuthMessage.error(error.message),
          resetUser: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error on signup',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          flow: AuthFlow.signup,
          message: const AuthMessage.error('Unexpected error occurred.'),
          resetUser: true,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.logout();
    } catch (error, stackTrace) {
      AppLogger.e('Logout encountered an issue',
          error: error, stackTrace: stackTrace);
    }

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        flow: AuthFlow.general,
        message: event.showMessage
            ? const AuthMessage.success('You have been logged out.')
            : null,
        clearMessage: !event.showMessage,
        resetUser: true,
      ),
    );
  }

  Future<void> _onPasswordResetRequested(
    PasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.passwordReset,
        clearMessage: true,
      ),
    );

    try {
      await _repository.requestPasswordReset(event.email);
      emit(
        state.copyWith(
          status: state.user != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          flow: AuthFlow.passwordReset,
          message: AuthMessage.success(
            'Password reset instructions have been sent to ${event.email}.',
          ),
        ),
      );
    } on AuthException catch (error, stackTrace) {
      AppLogger.e('Password reset request failed',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: state.user != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          flow: AuthFlow.passwordReset,
          message: AuthMessage.error(error.message),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error on password reset',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: state.user != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          flow: AuthFlow.passwordReset,
          message: const AuthMessage.error('Unexpected error occurred.'),
        ),
      );
    }
  }
}
