import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth/auth_bloc.dart';
import '../core/widgets/role_gate.dart';
import '../data/services/role_service.dart';

AppRole resolveAppRole(BuildContext context) {
  final authState = context.watch<AuthBloc>().state;
  final roleService = RepositoryProvider.of<RoleService>(context);
  return roleService.resolveFromAuthState(authState);
}
