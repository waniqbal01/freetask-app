import 'package:equatable/equatable.dart';

class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class SignupSubmitted extends AuthEvent {
  const SignupSubmitted({
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

class FetchMe extends AuthEvent {
  const FetchMe();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
