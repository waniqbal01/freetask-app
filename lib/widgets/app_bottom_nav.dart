import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/nav/role_nav_cubit.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<RoleNavTarget> onSelected;

  IconData _toIcon(String name, {bool selected = false}) {
    switch (name) {
      case 'dashboard_outlined':
        return Icons.dashboard_outlined;
      case 'dashboard':
        return Icons.dashboard;
      case 'dashboard_customize_outlined':
        return Icons.dashboard_customize_outlined;
      case 'dashboard_customize':
        return Icons.dashboard_customize;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'chat_bubble':
        return Icons.chat_bubble;
      case 'work_outline':
        return Icons.work_outline;
      case 'work':
        return Icons.work;
      case 'person_outline':
        return Icons.person_outline;
      case 'person':
        return Icons.person;
      case 'explore_outlined':
        return Icons.explore_outlined;
      case 'explore':
        return Icons.explore;
      default:
        return selected ? Icons.circle : Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RoleNavCubit, RoleNavState>(
      builder: (context, state) {
        final tabs = state.tabs;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BottomNavigationBar(
                  backgroundColor: Colors.white,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: theme.colorScheme.primary,
                  unselectedItemColor: Colors.grey.shade500,
                  currentIndex: state.index,
                  onTap: (index) {
                    context.read<RoleNavCubit>().setIndex(index);
                    onSelected(tabs[index].target);
                  },
                  items: [
                    for (final tab in tabs)
                      BottomNavigationBarItem(
                        icon: Icon(_toIcon(tab.icon)),
                        activeIcon: Icon(
                          _toIcon(tab.selectedIcon, selected: true),
                        ),
                        label: tab.label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
