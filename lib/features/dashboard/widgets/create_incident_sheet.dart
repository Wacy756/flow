import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';

const _kCategories = [
  'Plumbing',
  'Electrical',
  'Heating',
  'Structural',
  'Pest Control',
  'Appliances',
  'Other',
];

void showCreateIncidentSheet(
  BuildContext context, {
  required List<Tenancy> activeTenancies,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateIncidentSheet(activeTenancies: activeTenancies),
  );
}

class _CreateIncidentSheet extends ConsumerStatefulWidget {
  final List<Tenancy> activeTenancies;
  const _CreateIncidentSheet({required this.activeTenancies});

  @override
  ConsumerState<_CreateIncidentSheet> createState() =>
      _CreateIncidentSheetState();
}

class _CreateIncidentSheetState extends ConsumerState<_CreateIncidentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedTenancyId;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.activeTenancies.length == 1) {
      _selectedTenancyId = widget.activeTenancies.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createIncidentProvider);
    final isLoading = createState.isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 20, color: Color(0xFFF97316)),
                  ),
                  const SizedBox(width: 12),
                  Text('Report an Incident',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Describe the issue and we\'ll notify your landlord.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
            const Divider(height: 24),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Property selector (only when multiple tenancies)
                        if (widget.activeTenancies.length > 1) ...[
                          _label('Property'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedTenancyId),
                            initialValue: _selectedTenancyId,
                            decoration: _inputDec('Select property'),
                            items: widget.activeTenancies
                                .map((t) => DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.shortAddress,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedTenancyId = v),
                            validator: (v) =>
                                v == null ? 'Select a property' : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Title
                        _label('Title'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration:
                              _inputDec('e.g. Leaking kitchen tap'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter a title'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Category
                        _label('Category'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedCategory),
                          initialValue: _selectedCategory,
                          decoration: _inputDec('Select category'),
                          items: _kCategories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        _label('Description'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: _inputDec(
                              'Describe the issue in as much detail as possible...'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please add a description'
                                  : null,
                        ),
                        const SizedBox(height: 28),

                        // Error
                        if (createState.hasError)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              createState.error.toString(),
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text(
                                    'Report Incident',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenancyId == null) return;

    final ok = await ref.read(createIncidentProvider.notifier).submit(
          tenancyId: _selectedTenancyId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
        );

    if (ok && mounted) Navigator.of(context).pop();
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppTheme.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      );
}
