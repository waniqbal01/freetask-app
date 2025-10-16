import 'package:equatable/equatable.dart';

import '../../models/user.dart';

enum AuthFlow { general, login, signup }

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoading extends AuthState {
  const AuthLoading({this.flow = AuthFlow.general});

  final AuthFlow flow;

  @override
  List<Object?> get props => [flow];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  const AuthError(this.message, {this.flow = AuthFlow.general});

  final String message;
  final AuthFlow flow;

  @override
  List<Object?> get props => [message, flow];
}
