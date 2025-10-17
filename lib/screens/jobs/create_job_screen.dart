import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../utils/role_permissions.dart';
import '../../utils/validators.dart';
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
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      final existing = _attachments.map((file) => file.path).toSet();
      for (final file in files) {
        if (existing.add(file.path)) {
          _attachments.add(file);
        }
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    setState(() => _attachments.add(file));
  }

  void _removeAttachment(XFile file) {
    setState(() => _attachments.remove(file));
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
            imagePaths: _attachments.map((file) => file.path).toList(),
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
          Navigator.of(context).maybePop();
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
                    _BuildInput(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'Eg. Design a landing page',
                      validator: Validators.requiredField,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _BuildInput(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe the scope, expectations and deliverables',
                      validator: Validators.requiredField,
                      minLines: 4,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 16),
                    _BuildInput(
                      controller: _priceController,
                      label: 'Budget (USD)',
                      hint: 'Enter total budget',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.number,
                    ),
                    const SizedBox(height: 16),
                    _BuildInput(
                      controller: _categoryController,
                      label: 'Category',
                      hint: 'Eg. Design, Development, Marketing',
                      validator: Validators.requiredField,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _BuildInput(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Eg. Remote, Kuala Lumpur',
                      validator: Validators.requiredField,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Attachments',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._attachments.map(
                          (file) => Chip(
                            avatar: const Icon(Icons.image_outlined),
                            label: Text(file.name),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () => _removeAttachment(file),
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                          onPressed: _pickAttachment,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Camera'),
                          onPressed: _pickFromCamera,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: state.isSubmitting ? null : _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(state.isSubmitting ? 'Creating...' : 'Create job'),
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

class _BuildInput extends StatelessWidget {
  const _BuildInput({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
