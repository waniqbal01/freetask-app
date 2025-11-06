import 'package:flutter/widgets.dart';
import 'package:freetask_app/core/constants/app_roles.dart';

class RoleGate extends StatelessWidget {
  final AppRole current;
  final List<AppRole> allow;
  final Widget child;
  final Widget? fallback;

  const RoleGate({
    super.key,
    required this.current,
    required this.allow,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (allow.contains(current)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
