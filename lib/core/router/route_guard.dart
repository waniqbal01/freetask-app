import 'package:flutter/material.dart';

import '../../data/services/role_service.dart';
import '../../models/user_roles.dart';

class RouteGuard extends NavigatorObserver {
  RouteGuard(this._roleService);
  final RoleService _roleService;

  String? get currentRole => _roleService.persistedRole;

  bool hasRole(UserRoles role) {
    return _roleService.hasUserRole(role);
  }
}
