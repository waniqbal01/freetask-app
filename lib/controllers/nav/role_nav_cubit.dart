import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../utils/role_permissions.dart';

class RoleNavCubit extends Cubit<RoleNavState> {
  RoleNavCubit({String initialRole = UserRoles.defaultRole})
      : super(RoleNavState.forRole(initialRole));

  void updateRole(String role) {
    if (state.role == role) return;
    emit(RoleNavState.forRole(role));
  }

  void setIndex(int index) {
    emit(state.copyWith(index: index));
  }
}

class RoleNavState extends Equatable {
  const RoleNavState({
    required this.role,
    required this.index,
    required this.tabs,
  });

  factory RoleNavState.forRole(String role) {
    return RoleNavState(
      role: role,
      index: 0,
      tabs: _tabsFor(role),
    );
  }

  final String role;
  final int index;
  final List<RoleNavTab> tabs;

  RoleNavState copyWith({
    String? role,
    int? index,
    List<RoleNavTab>? tabs,
  }) {
    return RoleNavState(
      role: role ?? this.role,
      index: index ?? this.index,
      tabs: tabs ?? this.tabs,
    );
  }

  @override
  List<Object?> get props => [role, index, tabs];
}

class RoleNavTab extends Equatable {
  const RoleNavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.target,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final RoleNavTarget target;

  @override
  List<Object?> get props => [label, icon, selectedIcon, target];
}

enum RoleNavTarget {
  availableJobs,
  myJobs,
  createJob,
  chat,
  profile,
  overview,
  users,
  jobs,
}

List<RoleNavTab> _tabsFor(String role) {
  const clientTabs = [
    RoleNavTab(
      label: 'Home',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      target: RoleNavTarget.myJobs,
    ),
    RoleNavTab(
      label: 'Create',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      target: RoleNavTarget.createJob,
    ),
    RoleNavTab(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      target: RoleNavTarget.chat,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      target: RoleNavTarget.profile,
    ),
  ];

  const freelancerTabs = [
    RoleNavTab(
      label: 'Home',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      target: RoleNavTarget.availableJobs,
    ),
    RoleNavTab(
      label: 'My Jobs',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      target: RoleNavTarget.myJobs,
    ),
    RoleNavTab(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      target: RoleNavTarget.chat,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      target: RoleNavTarget.profile,
    ),
  ];

  const adminTabs = [
    RoleNavTab(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      target: RoleNavTarget.overview,
    ),
    RoleNavTab(
      label: 'Users',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
      target: RoleNavTarget.users,
    ),
    RoleNavTab(
      label: 'Jobs',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      target: RoleNavTarget.jobs,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      target: RoleNavTarget.profile,
    ),
  ];

  final mapping = <String, List<RoleNavTab>>{
    UserRoles.client: clientTabs,
    UserRoles.freelancer: freelancerTabs,
    UserRoles.admin: adminTabs,
    UserRoles.manager: adminTabs,
    UserRoles.support: adminTabs,
  };

  return mapping[role] ?? mapping[UserRoles.defaultRole]!;
}
