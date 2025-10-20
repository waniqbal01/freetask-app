import 'package:flutter/material.dart';

import '../../controllers/nav/role_nav_cubit.dart';
import '../dashboard_client/dashboard_shell.dart';

class DashboardFreelancerView extends StatelessWidget {
  const DashboardFreelancerView({super.key});

  static const routeName = '/dashboard/freelancer';

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(initialTarget: RoleNavTarget.jobs);
  }
}
