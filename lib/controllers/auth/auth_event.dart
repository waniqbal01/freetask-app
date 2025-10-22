import 'package:equatable/equatable.dart';

class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class SignupRequested extends AuthEvent {
  const SignupRequested({
    required this.name,
    required this.email,
    required this.password,
    this.role = 'client',
  });

  final String name;
  final String email;
  final String password;
  final String role;

  @override
  List<Object?> get props => [name, email, password, role];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested({this.showMessage = false});

  final bool showMessage;

  @override
  List<Object?> get props => [showMessage];
}

class PasswordResetRequested extends AuthEvent {
  const PasswordResetRequested(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}
