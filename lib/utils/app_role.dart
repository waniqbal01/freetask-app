import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth/auth_bloc.dart';
import '../services/storage_service.dart';
import '../utils/role_gate.dart';

AppRole resolveAppRole(BuildContext context) {
  final authState = context.watch<AuthBloc>().state;
  final storage = RepositoryProvider.of<StorageService>(context);
  final roleName = authState.user?.role ?? storage.role ?? storage.getUser()?.role;
  return _mapRole(roleName);
}

AppRole _mapRole(String? role) {
  final normalized = role?.trim().toLowerCase();
  switch (normalized) {
    case 'seller':
    case 'freelancer':
      return AppRole.seller;
    case 'admin':
    case 'manager':
    case 'support':
      return AppRole.admin;
    default:
      return AppRole.client;
  }
}
