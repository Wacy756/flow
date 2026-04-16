import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final List<PlatformFile> _mediaFiles = [];
  bool _uploadingMedia = false;

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
    final isLoading = createState.isLoading || _uploadingMedia;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgSurface,
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
                  color: AppTheme.border,
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
                      color: AppTheme.greenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 20, color: AppTheme.green),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Report an Incident',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
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
                        // Property selector
                        if (widget.activeTenancies.length > 1) ...[
                          _label('Property'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedTenancyId),
                            initialValue: _selectedTenancyId,
                            decoration: const InputDecoration(
                                hintText: 'Select property'),
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

                        _label('Title'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Leaking kitchen tap',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter a title'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        _label('Category'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                              hintText: 'Select category'),
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

                        _label('Description'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Describe the issue in as much detail as possible...',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please add a description'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Photos
                        _label('Photos (optional)'),
                        const SizedBox(height: 6),
                        if (_mediaFiles.isNotEmpty) ...[
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _mediaFiles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final f = _mediaFiles[i];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: f.path != null
                                          ? Image.file(File(f.path!),
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover)
                                          : Container(
                                              width: 80,
                                              height: 80,
                                              color: AppTheme.bgPage,
                                              child: const Icon(
                                                  Icons.image_outlined,
                                                  color: AppTheme.textMuted)),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _mediaFiles.removeAt(i)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        GestureDetector(
                          onTap: _pickMedia,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.border, width: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 18, color: AppTheme.textMuted),
                                SizedBox(width: 8),
                                Text('Add Photos',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Error
                        if (createState.hasError)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.border, width: 0.5),
                            ),
                            child: Text(
                              createState.error.toString(),
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13),
                            ),
                          ),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Report Incident'),
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

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _mediaFiles.addAll(result.files));
  }

  Future<List<String>> _uploadMedia() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final urls = <String>[];
    for (final file in _mediaFiles) {
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) continue;

      final ext = file.extension ?? 'jpg';
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await client.storage.from('incidents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
                upsert: true),
          );

      final url =
          client.storage.from('incidents').getPublicUrl(path);
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenancyId == null) return;

    setState(() => _uploadingMedia = true);
    final mediaUrls = await _uploadMedia();
    setState(() => _uploadingMedia = false);

    final ok = await ref.read(createIncidentProvider.notifier).submit(
          tenancyId: _selectedTenancyId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
          mediaUrls: mediaUrls,
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
}
