import 'package:freetask_app/core/constants/app_roles.dart';

import '../controllers/auth/auth_state.dart';
import '../data/services/role_service.dart';
import '../models/user_roles.dart';
import 'storage_service.dart';

class RoleStorageService implements RoleService {
  RoleStorageService(this._storage);

  final StorageService _storage;

  @override
  String? get persistedRole => _storage.role ?? _storage.getUser()?.role;

  @override
  AppRole resolveRole({String? overrideRole}) {
    return _mapRole(overrideRole ?? persistedRole);
  }

  @override
  AppRole resolveFromAuthState(AuthState state) {
    return resolveRole(overrideRole: state.user?.role);
  }

  @override
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
