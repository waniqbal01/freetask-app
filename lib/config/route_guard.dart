import 'package:flutter/material.dart';

import '../models/user_roles.dart';
import '../services/storage_service.dart';

class RouteGuard extends NavigatorObserver {
  RouteGuard(this._storage);
  final StorageService _storage;

  bool hasRole(UserRoles role) {
    final r = _storage.role ?? _storage.getUser()?.role;
    return parseUserRole(r) == role;
  }
}
