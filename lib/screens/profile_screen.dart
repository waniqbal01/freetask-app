import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth/auth_bloc.dart';
import '../controllers/auth/auth_event.dart';
import '../controllers/profile/profile_bloc.dart';
import '../controllers/profile/profile_event.dart';
import '../controllers/profile/profile_state.dart';
import '../models/user.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileBloc>().add(const ProfileStarted());
    });
  }

  void _onLogout() {
    context.read<AuthBloc>().add(const LogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out successfully.')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final user = state.user;
        if (state.isLoading && user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.15),
                    child: Text(
                      _initialsFor(user),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Your profile',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.role.toUpperCase() ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile editing is coming soon.'),
                        ),
                      );
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoTile(
                label: 'Email',
                value: user?.email ?? '-',
              ),
              const SizedBox(height: 12),
              _InfoTile(
                label: 'Location',
                value: (user?.location?.isNotEmpty ?? false)
                    ? user!.location!
                    : 'Not set',
              ),
              const SizedBox(height: 12),
              _InfoTile(
                label: 'Bio',
                value: (user?.bio?.isNotEmpty ?? false)
                    ? user!.bio!
                    : 'Tell others about yourself.',
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Logout',
                onPressed: _onLogout,
                icon: Icons.logout,
              ),
            ],
          ),
        );
      },
    );
  }

  String _initialsFor(User? user) {
    if (user == null || user.name.trim().isEmpty) {
      return 'FT';
    }
    final parts = user.name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return '$first$last'.toUpperCase();
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
