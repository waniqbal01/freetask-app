import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/profile/profile_bloc.dart';
import '../../controllers/theme/theme_cubit.dart';
import '../../models/user.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.user, this.readOnly = false});

  final User? user;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    return BlocProvider<ProfileBloc>(
      create: (_) => ProfileBloc(
        getIt<ProfileService>(),
        getIt<StorageService>(),
      )..add(ProfileStarted(initialUser: user, forceReadOnly: readOnly)),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 280);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _submitted = false;
  Completer<void>? _refreshCompleter;
  ProfileState? _lastState;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _applyUser(User? user) {
    if (user == null) return;
    _setIfChanged(_nameController, user.name);
    _setIfChanged(_emailController, user.email);
    _setIfChanged(_roleController, user.role.toUpperCase());
    _setIfChanged(_bioController, user.bio ?? '');
    _setIfChanged(_locationController, user.location ?? '');
    _setIfChanged(_phoneController, user.phoneNumber ?? '');
  }

  void _setIfChanged(TextEditingController controller, String value) {
    if (controller.text != value) {
      final selection = controller.selection;
      controller.text = value;
      controller.selection = selection.copyWith(
        baseOffset: value.length,
        extentOffset: value.length,
      );
    }
  }

  Future<void> _pickAvatar(ProfileState state) async {
    if (state.isReadOnly) return;
    final theme = Theme.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update profile picture',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Capture with camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;
    if (!mounted) return;

    context.read<ProfileBloc>().add(
          ProfileAvatarUploadRequested(file: File(image.path)),
        );
  }

  Future<void> _handleRefresh() {
    _refreshCompleter?.complete();
    _refreshCompleter = Completer<void>();
    context.read<ProfileBloc>().add(const ProfileRefreshed());
    return _refreshCompleter!.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        if (!(_refreshCompleter?.isCompleted ?? true)) {
          _refreshCompleter?.complete();
        }
      },
    );
  }

  void _submit(ProfileState state) {
    final form = _formKey.currentState;
    if (form == null || state.isReadOnly) return;
    setState(() => _submitted = true);
    if (!form.validate()) return;

    FocusScope.of(context).unfocus();
    context.read<ProfileBloc>().add(
          ProfileSubmitted(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          ),
        );
  }

  void _showThemeSheet() {
    final themeCubit = context.read<ThemeCubit>();
    final currentMode = themeCubit.state;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              final selected = mode == currentMode;
              final title = switch (mode) {
                ThemeMode.dark => 'Dark',
                ThemeMode.light => 'Light',
                _ => 'System',
              };
              return ListTile(
                leading: Icon(
                  switch (mode) {
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.light => Icons.wb_sunny_outlined,
                    _ => Icons.auto_mode_outlined,
                  },
                ),
                title: Text(title),
                trailing: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: _animationDuration,
                  child: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: () {
                  themeCubit.updateTheme(mode);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _showChangePasswordSheet() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool submitted = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Form(
                key: formKey,
                autovalidateMode: submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Change password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: currentController,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: Validators.requiredField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newController,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      obscureText: true,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      obscureText: true,
                      validator:
                          Validators.confirmPassword(() => newController.text),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Update password',
                      icon: Icons.save_outlined,
                      onPressed: () {
                        setSheetState(() => submitted = true);
                        final form = formKey.currentState;
                        if (form == null || !form.validate()) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
        ),
      );
    }
  }

  void _logout() {
    context.read<AuthBloc>().add(const LogoutRequested());
  }

  String? _validateBio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length < 10) {
      return 'Tell us a little more (min 10 characters).';
    }
    return null;
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required ProfileState state,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    Iterable<String>? autofillHints,
    int maxLines = 1,
    int? minLines,
    TextInputAction? textInputAction,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !state.isReadOnly && !readOnly,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (previous, current) => previous != current,
      listener: (context, state) {
        final previous = _lastState;
        _lastState = state;
        if (state.user != null && state.user != previous?.user) {
          _applyUser(state.user);
        }
        if ((previous?.isRefreshing ?? false) && !state.isRefreshing) {
          _refreshCompleter?.complete();
          _refreshCompleter = null;
        }
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty &&
            state.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          context.read<ProfileBloc>().add(const ProfileMessageCleared());
        }
        if (state.successMessage != null && state.successMessage!.isNotEmpty &&
            state.successMessage != previous?.successMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
          context.read<AuthBloc>().add(const FetchMe());
          context.read<ProfileBloc>().add(const ProfileMessageCleared());
        }
      },
      builder: (context, state) {
        final user = state.user;
        final content = _buildContent(context, state, user);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              if (!state.isReadOnly)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: state.isLoading
                      ? null
                      : () => context.read<ProfileBloc>().add(
                            const ProfileRefreshed(),
                          ),
                  icon: AnimatedSwitcher(
                    duration: _animationDuration,
                    child: state.isRefreshing
                        ? const SizedBox(
                            key: ValueKey('progress'),
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            key: ValueKey('refresh'),
                          ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              AnimatedSwitcher(
                duration: _animationDuration,
                child: (state.isSaving || state.isUploadingAvatar)
                    ? const LinearProgressIndicator(minHeight: 3)
                    : const SizedBox(height: 3),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ProfileState state, User? user) {
    final theme = Theme.of(context);

    final body = SingleChildScrollView(
      physics: state.isReadOnly
          ? const BouncingScrollPhysics()
          : const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: AnimatedSize(
        duration: _animationDuration,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        vsync: this,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: _animationDuration,
              child: user == null && state.isLoading
                  ? SizedBox(
                      key: const ValueKey('loader'),
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _buildProfileForm(context, state, user),
            ),
          ],
        ),
      ),
    );

    if (state.isReadOnly) {
      return SafeArea(child: body);
    }

    return SafeArea(
      child: RefreshIndicator.adaptive(
        onRefresh: _handleRefresh,
        color: theme.colorScheme.primary,
        child: body,
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context, ProfileState state, User? user) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      autovalidateMode:
          _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'profile_avatar_hero',
                      child: AnimatedContainer(
                        duration: _animationDuration,
                        curve: Curves.easeOut,
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                        image: (user?.avatarUrl?.isNotEmpty ?? false)
                            ? DecorationImage(
                                image: NetworkImage(user!.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: (user?.avatarUrl?.isNotEmpty ?? false)
                          ? null
                          : Text(
                              (user?.name.isNotEmpty ?? false)
                                  ? user!.name[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      ),
                    ),
                    if (state.isUploadingAvatar)
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    if (!state.isReadOnly)
                      Positioned(
                        bottom: 0,
                        right: 8,
                        child: AnimatedScale(
                          duration: _animationDuration,
                          scale: state.isUploadingAvatar ? 0 : 1,
                          child: FloatingActionButton.small(
                            heroTag: 'avatarFab',
                            elevation: 2,
                            backgroundColor: theme.colorScheme.primary,
                            onPressed: state.isUploadingAvatar
                                ? null
                                : () => _pickAvatar(state),
                            child: const Icon(Icons.camera_alt_outlined),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'Your Name',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'your@email.com',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.lastSyncedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last synced ${_formatTimestamp(state.lastSyncedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Full name',
            icon: Icons.person_outline,
            controller: _nameController,
            state: state,
            textInputAction: TextInputAction.next,
            validator: Validators.name,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Email address',
            icon: Icons.alternate_email,
            controller: _emailController,
            state: state,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: Validators.email,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Role',
            icon: Icons.verified_user_outlined,
            controller: _roleController,
            state: state,
            readOnly: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Bio',
            icon: Icons.short_text,
            controller: _bioController,
            state: state,
            maxLines: 4,
            minLines: 3,
            validator: _validateBio,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Location',
            icon: Icons.location_on_outlined,
            controller: _locationController,
            state: state,
            validator: Validators.requiredField,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Phone number',
            icon: Icons.phone_outlined,
            controller: _phoneController,
            state: state,
            keyboardType: TextInputType.phone,
            validator: Validators.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: 28),
          if (!state.isReadOnly)
            AppButton(
              label: 'Save changes',
              icon: Icons.save_outlined,
              isLoading: state.isSaving,
              onPressed: state.isSaving ? null : () => _submit(state),
            ),
          const SizedBox(height: 32),
          Text(
            'Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showChangePasswordSheet,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_mode_outlined),
                  title: const Text('Switch theme'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showThemeSheet,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }
}
