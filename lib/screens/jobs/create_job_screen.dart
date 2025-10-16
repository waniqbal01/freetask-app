import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../utils/role_permissions.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../unauthorized/unauthorized_screen.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _attachments = [];
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _attachments.add(file));
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    setState(() => _submitted = true);
    if (!form.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    context.read<JobBloc>().add(
          CreateJobRequested(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            category: _categoryController.text.trim(),
            location: _locationController.text.trim(),
            attachments: _attachments.map((file) => file.path).toList(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.role,
    );
    if (role != UserRoles.client) {
      return const UnauthorizedScreen(
        message: 'Only clients can create new jobs.',
      );
    }

    return BlocConsumer<JobBloc, JobState>(
      listenWhen: (previous, current) =>
          previous.successMessage != current.successMessage ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Create job')),
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
                    AppInput(
                      controller: _titleController,
                      label: 'Title',
                      validator: Validators.validateRequired,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _descriptionController,
                      label: 'Description',
                      minLines: 3,
                      maxLines: 6,
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _priceController,
                      label: 'Budget (USD)',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.validateNumber,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _categoryController,
                      label: 'Category',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _locationController,
                      label: 'Location',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Attachments',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._attachments.map(
                          (file) => Chip(
                            label: Text(file.name),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () {
                              setState(() => _attachments.remove(file));
                            },
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.upload_file),
                          label: const Text('Add image'),
                          onPressed: _pickAttachment,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Create job',
                      icon: Icons.save_outlined,
                      isLoading: state.isSubmitting,
                      onPressed: state.isSubmitting ? null : _submit,
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
