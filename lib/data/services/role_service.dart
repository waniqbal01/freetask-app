import 'package:freetask_app/core/constants/app_roles.dart';

import '../../controllers/auth/auth_state.dart';
import '../../models/user_roles.dart';
import '../../services/storage_service.dart';

class RoleService {
  RoleService(this._storage);

  final StorageService _storage;

  String? get persistedRole => _storage.role ?? _storage.getUser()?.role;

  AppRole resolveRole({String? overrideRole}) {
    return _mapRole(overrideRole ?? persistedRole);
  }

  AppRole resolveFromAuthState(AuthState state) {
    return resolveRole(overrideRole: state.user?.role);
  }

  bool hasUserRole(UserRoles role) {
    return parseUserRole(persistedRole) == role;
  }

  AppRole _mapRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    switch (normalized) {
      case 'seller':
      case 'freelancer':
        return AppRole.freelancer;
      case 'admin':
      case 'manager':
      case 'support':
        return AppRole.admin;
      default:
        return AppRole.client;
    }
  }
}
