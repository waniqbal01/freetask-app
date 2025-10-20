import 'package:flutter/material.dart';

import '../../controllers/nav/role_nav_cubit.dart';
import 'dashboard_shell.dart';

class DashboardClientView extends StatelessWidget {
  const DashboardClientView({super.key});

  static const routeName = DashboardShell.routeName;

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(initialTarget: RoleNavTarget.home);
  }
}
