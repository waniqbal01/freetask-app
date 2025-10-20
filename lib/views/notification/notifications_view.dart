import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controllers/notifications/notifications_cubit.dart';
import '../../controllers/notifications/notifications_state.dart';
import '../../models/app_notification.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<NotificationCategory> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = NotificationCategory.values;
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsCubit>().load();
    });
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      context
          .read<NotificationsCubit>()
          .changeTab(_tabs[_tabController.index]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map((category) => Tab(text: category.label))
              .toList(growable: false),
        ),
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.isLoading && state.activeNotifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = state.activeNotifications;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none, size: 48),
                  const SizedBox(height: 12),
                  Text('No notifications in this tab', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                onTap: () => context.read<NotificationsCubit>().markAsRead(notification),
                leading: CircleAvatar(
                  backgroundColor: notification.isRead
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(
                    _iconFor(notification.category),
                    color: notification.isRead
                        ? Colors.grey.shade600
                        : theme.colorScheme.primary,
                  ),
                ),
                title: Text(notification.title),
                subtitle: Text(notification.message),
                trailing: notification.isRead
                    ? null
                    : const Icon(Icons.circle, color: Colors.blueAccent, size: 12),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: notifications.length,
          );
        },
      ),
    );
  }

  IconData _iconFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.all:
        return Icons.notifications;
      case NotificationCategory.job:
        return Icons.work_outline;
      case NotificationCategory.chat:
        return Icons.chat_bubble_outline;
      case NotificationCategory.payment:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.system:
        return Icons.settings_outlined;
    }
  }
}
