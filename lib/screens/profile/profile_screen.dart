import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final ImagePicker _picker = ImagePicker();
  File? _avatar;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state;
    final name = user is AuthAuthenticated ? user.user.name : '';
    final email = user is AuthAuthenticated ? user.user.email : '';
    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _avatar = File(file.path));
    }
  }

  void _saveProfile() {
    final form = _formKey.currentState;
    if (form == null) return;
    setState(() => _submitted = true);
    if (!form.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile changes saved.')),
    );
  }

  void _logout() {
    context.read<AuthBloc>().add(const LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: () {
                          if (_avatar != null) {
                            return FileImage(_avatar!);
                          }
                          if (user?.avatarUrl != null) {
                            return NetworkImage(user!.avatarUrl!);
                          }
                          return null;
                        }(),
                        child: (_avatar == null && user?.avatarUrl == null)
                            ? Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 20),
                            onPressed: _pickAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppInput(
                  controller: _nameController,
                  label: 'Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _emailController,
                  label: 'Email',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(user?.role ?? 'Unknown'),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Save changes',
                  icon: Icons.save_outlined,
                  onPressed: _saveProfile,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
