import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freetask_app/core/constants/app_roles.dart';

import '../controllers/auth/auth_bloc.dart';
import '../data/services/role_service.dart';

AppRole resolveAppRole(BuildContext context) {
  final authState = context.watch<AuthBloc>().state;
  final roleService = RepositoryProvider.of<RoleService>(context);
  return roleService.resolveFromAuthState(authState);
}
