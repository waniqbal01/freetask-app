import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../models/user_roles.dart';

class RoleNavCubit extends Cubit<RoleNavState> {
  RoleNavCubit({String initialRole = kDefaultUserRoleName})
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
  final String icon;
  final String selectedIcon;
  final RoleNavTarget target;

  @override
  List<Object?> get props => [label, icon, selectedIcon, target];
}

enum RoleNavTarget { home, chat, jobs, profile }

List<RoleNavTab> _tabsFor(String role) {
  const clientTabs = [
    RoleNavTab(
      label: 'Home',
      icon: 'dashboard_outlined',
      selectedIcon: 'dashboard',
      target: RoleNavTarget.home,
    ),
    RoleNavTab(
      label: 'Chat',
      icon: 'chat_bubble_outline',
      selectedIcon: 'chat_bubble',
      target: RoleNavTarget.chat,
    ),
    RoleNavTab(
      label: 'Jobs',
      icon: 'work_outline',
      selectedIcon: 'work',
      target: RoleNavTarget.jobs,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: 'person_outline',
      selectedIcon: 'person',
      target: RoleNavTarget.profile,
    ),
  ];

  const freelancerTabs = [
    RoleNavTab(
      label: 'Home',
      icon: 'explore_outlined',
      selectedIcon: 'explore',
      target: RoleNavTarget.home,
    ),
    RoleNavTab(
      label: 'Chat',
      icon: 'chat_bubble_outline',
      selectedIcon: 'chat_bubble',
      target: RoleNavTarget.chat,
    ),
    RoleNavTab(
      label: 'Jobs',
      icon: 'work_outline',
      selectedIcon: 'work',
      target: RoleNavTarget.jobs,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: 'person_outline',
      selectedIcon: 'person',
      target: RoleNavTarget.profile,
    ),
  ];

  const adminTabs = [
    RoleNavTab(
      label: 'Home',
      icon: 'dashboard_customize_outlined',
      selectedIcon: 'dashboard_customize',
      target: RoleNavTarget.home,
    ),
    RoleNavTab(
      label: 'Chat',
      icon: 'chat_bubble_outline',
      selectedIcon: 'chat_bubble',
      target: RoleNavTarget.chat,
    ),
    RoleNavTab(
      label: 'Jobs',
      icon: 'work_outline',
      selectedIcon: 'work',
      target: RoleNavTarget.jobs,
    ),
    RoleNavTab(
      label: 'Profile',
      icon: 'person_outline',
      selectedIcon: 'person',
      target: RoleNavTarget.profile,
    ),
  ];

  final mapping = <String, List<RoleNavTab>>{
    UserRoles.client.name: clientTabs,
    UserRoles.freelancer.name: freelancerTabs,
    UserRoles.admin.name: adminTabs,
    UserRoles.manager.name: adminTabs,
    UserRoles.support.name: adminTabs,
    UserRoles.seller.name: freelancerTabs,
  };

  return mapping[role] ?? clientTabs;
}
