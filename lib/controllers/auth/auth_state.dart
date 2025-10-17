import 'package:equatable/equatable.dart';

import '../../models/user.dart';

enum AuthFlow { general, login, signup }

enum AuthStatus { authenticated, unauthenticated, unknown }

abstract class AuthState extends Equatable {
  const AuthState(this.status);

  final AuthStatus status;

  String? get role => null;

  @override
  List<Object?> get props => [status];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated() : super(AuthStatus.unauthenticated);
}

class AuthLoading extends AuthState {
  const AuthLoading({this.flow = AuthFlow.general}) : super(AuthStatus.unknown);

  final AuthFlow flow;

  @override
  List<Object?> get props => [status, flow];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user) : super(AuthStatus.authenticated);

  final User user;

  @override
  String? get role => user.role;

  @override
  List<Object?> get props => [status, user];
}

class AuthError extends AuthState {
  const AuthError(this.message, {this.flow = AuthFlow.general})
      : super(AuthStatus.unknown);

  final String message;
  final AuthFlow flow;

  @override
  List<Object?> get props => [status, message, flow];
}
