import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/widgets/role_gate.dart';
import '../../data/models/service_model.dart';
import '../../data/services/service_service.dart';
import '../../utils/app_role.dart';

class CreateServiceView extends StatefulWidget {
  const CreateServiceView({super.key, this.initialService});

  final Service? initialService;

  @override
  State<CreateServiceView> createState() => _CreateServiceViewState();
}

class _CreateServiceViewState extends State<CreateServiceView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _deliveryController = TextEditingController(text: '3');
  final _priceController = TextEditingController(text: '50');
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  ServiceService get _marketplace => RepositoryProvider.of<ServiceService>(context);

  @override
  void initState() {
    super.initState();
    final service = widget.initialService;
    if (service != null) {
      _titleController.text = service.title;
      _categoryController.text = service.category;
      _deliveryController.text = service.deliveryTime.toString();
      _priceController.text = service.price.toStringAsFixed(2);
      _descriptionController.text = service.description;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _deliveryController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final service = await _marketplace.createService(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        deliveryTime: int.parse(_deliveryController.text.trim()),
        status: widget.initialService?.status ?? 'published',
      );
      if (!mounted) return;
      Navigator.of(context).pop(service);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully.')),
      );
    } catch (error) {
      setState(() => _error = 'Unable to save service. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = resolveAppRole(context);
    return RoleGate(
      current: role,
      allow: const [AppRole.seller, AppRole.admin],
      fallback: const _UnauthorizedCreateView(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialService == null ? 'Create service' : 'Update service'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Service title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (USD)'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deliveryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Delivery time (days)'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid delivery time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 20) {
                      return 'Describe your service (at least 20 characters).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.initialService == null ? 'Create service' : 'Update service'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnauthorizedCreateView extends StatelessWidget {
  const _UnauthorizedCreateView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'You are not permitted to manage services.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
