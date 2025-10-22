import 'package:equatable/equatable.dart';

import '../../models/user.dart';

enum AuthFlow { general, login, signup, passwordReset }

enum AuthStatus { authenticated, unauthenticated, loading, unknown }

enum AuthMessageType { success, error }

class AuthMessage extends Equatable {
  const AuthMessage._({
    required this.text,
    required this.type,
    required this.timestamp,
  });

  factory AuthMessage.success(String text) {
    return AuthMessage._(
      text: text,
      type: AuthMessageType.success,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    );
  }

  factory AuthMessage.error(String text) {
    return AuthMessage._(
      text: text,
      type: AuthMessageType.error,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    );
  }

  final String text;
  final AuthMessageType type;
  final int timestamp;

  bool get isError => type == AuthMessageType.error;

  @override
  List<Object?> get props => [text, type, timestamp];
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.flow = AuthFlow.general,
    this.message,
  });

  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.unknown);
  }

  final AuthStatus status;
  final User? user;
  final AuthFlow flow;
  final AuthMessage? message;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool resetUser = false,
    AuthFlow? flow,
    AuthMessage? message,
    bool clearMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: resetUser ? null : user ?? this.user,
      flow: flow ?? this.flow,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, user, flow, message];
}
