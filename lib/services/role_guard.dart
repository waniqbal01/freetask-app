import '../utils/role_permissions.dart';
import 'storage_service.dart';

class RoleUnauthorizedException implements Exception {
  RoleUnauthorizedException(this.message, {this.requiredRoles});

  final String message;
  final Set<String>? requiredRoles;

  @override
  String toString() => 'RoleUnauthorizedException: $message';
}

/// Provides reusable checks for enforcing role-based permissions.
class RoleGuard {
  RoleGuard(this._storage);

  final StorageService _storage;

  String? get currentRole => _storage.role ?? _storage.getUser()?.role;

  void ensurePermission(RolePermission permission) {
    final config = RolePermissions.config(permission);
    final role = currentRole;
    if (!config.isAllowed(role)) {
      throw RoleUnauthorizedException(
        'You do not have permission to ${config.description}.',
        requiredRoles: config.allowedRoles,
      );
    }
  }

  void ensureRoleIn(Set<String> roles, {String? actionDescription}) {
    if (roles.isEmpty) return;
    final role = currentRole;
    if (role == null || !roles.contains(role)) {
      throw RoleUnauthorizedException(
        actionDescription ?? 'You do not have permission to continue.',
        requiredRoles: roles,
      );
    }
  }
}
