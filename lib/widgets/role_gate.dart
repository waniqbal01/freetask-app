import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth/auth_bloc.dart';
import '../controllers/auth/auth_state.dart';
import '../services/storage_service.dart';
import '../utils/role_permissions.dart';

/// Conditionally renders content based on the authenticated user's role or
/// permissions. Falls back to an empty box if access is denied.
class RoleGate extends StatelessWidget {
  const RoleGate({
    super.key,
    required this.child,
    this.fallback,
    this.allowedRoles,
    this.permission,
  });

  final Widget child;
  final Widget? fallback;
  final Set<String>? allowedRoles;
  final RolePermission? permission;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final storage = RepositoryProvider.of<StorageService>(context);
    final role = _resolveRole(authState, storage);

    final bool allowed = _canAccess(role);
    if (!allowed) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }

  String? _resolveRole(AuthState state, StorageService storage) {
    if (state.user != null) {
      return state.user!.role;
    }
    return storage.role ?? storage.getUser()?.role;
  }

  bool _canAccess(String? role) {
    if (role == null) {
      return false;
    }
    if (permission != null && !RolePermissions.isAllowed(role, permission!)) {
      return false;
    }
    if (allowedRoles != null && allowedRoles!.isNotEmpty) {
      return allowedRoles!.contains(role);
    }
    return true;
  }
}
