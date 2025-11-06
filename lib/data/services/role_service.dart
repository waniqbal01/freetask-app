import 'package:freetask_app/core/constants/app_roles.dart';

import '../../controllers/auth/auth_state.dart';
import '../../models/user_roles.dart';

abstract class RoleService {
  const RoleService();

  String? get persistedRole;

  AppRole resolveRole({String? overrideRole});

  AppRole resolveFromAuthState(AuthState state);

  bool hasUserRole(UserRoles role);
}
