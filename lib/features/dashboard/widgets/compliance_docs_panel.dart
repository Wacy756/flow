import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../models/compliance_doc.dart';
import '../providers/dashboard_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Doc type metadata ────────────────────────────────────────────────────────

class _DocMeta {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String section;

  const _DocMeta({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.section,
  });
}

const _kDocMeta = <String, _DocMeta>{
  'Tenancy agreement': _DocMeta(
    label: 'Tenancy Agreement',
    subtitle: 'Signed rental contract',
    icon: Icons.handshake_outlined,
    color: Color(0xFF14B8A6),
    section: 'Tenancy Documents',
  ),
  'How to Rent Guide': _DocMeta(
    label: 'How to Rent Guide',
    subtitle: 'Government guide — legally required',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF3B82F6),
    section: 'Tenancy Documents',
  ),
  'EPC (Energy Performance Certificate)': _DocMeta(
    label: 'Energy Performance Certificate',
    subtitle: 'EPC rating for this property',
    icon: Icons.bolt_outlined,
    color: Color(0xFFF59E0B),
    section: 'Safety Certificates',
  ),
  'Gas Safety': _DocMeta(
    label: 'Gas Safety Certificate',
    subtitle: 'Annual gas safety inspection',
    icon: Icons.local_fire_department_outlined,
    color: Color(0xFFEF4444),
    section: 'Safety Certificates',
  ),
  'ECIR (Electrical Installation Condition Report)': _DocMeta(
    label: 'Electrical Condition Report',
    subtitle: 'ECIR — wiring & installation safety',
    icon: Icons.electrical_services_outlined,
    color: Color(0xFF8B5CF6),
    section: 'Safety Certificates',
  ),
};

// ─── Public panel (used in landlord dashboard & elsewhere) ────────────────────

class ComplianceDocsPanel extends ConsumerWidget {
  final String tenancyId;
  final bool canUpload;

  const ComplianceDocsPanel({
    super.key,
    required this.tenancyId,
    this.canUpload = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final docsAsync = ref.watch(complianceDocsProvider(tenancyId));

    return docsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: p.green)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading docs: $e',
            style: const TextStyle(color: Colors.red)),
      ),
      data: (docs) => _DocList(
        docs: docs,
        tenancyId: tenancyId,
        canUpload: canUpload,
        onRefresh: () => ref.invalidate(complianceDocsProvider(tenancyId)),
      ),
    );
  }
}

// ─── Full tenant documents page ───────────────────────────────────────────────

class TenantDocumentsView extends ConsumerWidget {
  final String tenancyId;
  final String propertyAddress;
  final String postcode;

  const TenantDocumentsView({
    super.key,
    required this.tenancyId,
    required this.propertyAddress,
    required this.postcode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final docsAsync = ref.watch(complianceDocsProvider(tenancyId));

    return docsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: p.green)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load documents: $e',
            style: TextStyle(color: p.sub)),
      ),
      data: (docs) {
        // Build sections
        final sections = <String, List<String>>{};
        for (final type in kComplianceDocTypes) {
          final meta = _kDocMeta[type];
          if (meta == null) continue;
          sections.putIfAbsent(meta.section, () => []).add(type);
        }

        final uploadedCount =
            docs.where((d) => d.id.isNotEmpty).length;

        return RefreshIndicator(
          color: const Color(0xFF14B8A6),
          onRefresh: () async =>
              ref.invalidate(complianceDocsProvider(tenancyId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              // ── Property strip ─────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: 0.5),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_outlined,
                        color: Color(0xFF14B8A6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(propertyAddress,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                        Text(postcode,
                            style:
                                TextStyle(color: p.sub, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: uploadedCount == kComplianceDocTypes.length
                          ? const Color(0xFF14B8A6).withValues(alpha: 0.12)
                          : p.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: uploadedCount == kComplianceDocTypes.length
                            ? const Color(0xFF14B8A6).withValues(alpha: 0.3)
                            : p.border,
                      ),
                    ),
                    child: Text(
                      '$uploadedCount / ${kComplianceDocTypes.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: uploadedCount == kComplianceDocTypes.length
                            ? const Color(0xFF14B8A6)
                            : p.sub,
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Sections ───────────────────────────────────────────────
              for (final entry in sections.entries) ...[
                _SectionHeader(title: entry.key),
                const SizedBox(height: 10),
                _DocSection(
                  types: entry.value,
                  docs: docs,
                  tenancyId: tenancyId,
                  canUpload: false,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Doc section card ─────────────────────────────────────────────────────────

class _DocSection extends StatelessWidget {
  final List<String> types;
  final List<ComplianceDoc> docs;
  final String tenancyId;
  final bool canUpload;
  final VoidCallback? onRefresh;

  const _DocSection({
    required this.types,
    required this.docs,
    required this.tenancyId,
    required this.canUpload,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 0.5),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < types.length; i++) ...[
            _DocRow(
              type: types[i],
              doc: docs.firstWhere(
                (d) => d.docType == types[i],
                orElse: () => ComplianceDoc(
                  id: '',
                  tenancyId: tenancyId,
                  docType: types[i],
                  filePath: '',
                  fileName: '',
                ),
              ),
              canUpload: canUpload,
              isLast: i == types.length - 1,
              onRefresh: onRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Individual doc row ───────────────────────────────────────────────────────

class _DocRow extends StatefulWidget {
  final String type;
  final ComplianceDoc doc;
  final bool canUpload;
  final bool isLast;
  final VoidCallback? onRefresh;

  const _DocRow({
    required this.type,
    required this.doc,
    required this.canUpload,
    required this.isLast,
    this.onRefresh,
  });

  @override
  State<_DocRow> createState() => _DocRowState();
}

class _DocRowState extends State<_DocRow> {
  bool _uploading = false;

  bool get hasDoc => widget.doc.id.isNotEmpty;

  Future<void> _open() async {
    try {
      if (widget.doc.isExternal) {
        final url = Uri.parse(widget.doc.filePath.replaceFirst('EXT:', ''));
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
      final response = await Supabase.instance.client.storage
          .from('compliance-docs')
          .createSignedUrl(widget.doc.filePath, 60);
      await launchUrl(Uri.parse(response), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Could not open document: $e');
      }
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final ext = file.extension ?? 'pdf';
      final path =
          '$uid/${widget.doc.tenancyId}_${widget.type}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('compliance-docs')
          .uploadBinary(path, bytes);

      // Upsert row in compliance_docs (replace if doc_type already exists)
      await Supabase.instance.client.from('compliance_docs').upsert({
        'tenancy_id':  widget.doc.tenancyId,
        'doc_type':    widget.type,
        'file_path':   path,
        'file_name':   file.name,
        'uploaded_by': uid,
      }, onConflict: 'tenancy_id,doc_type');

      widget.onRefresh?.call();

      if (mounted) {
        showAbodeToast(context, '${widget.type} uploaded');
      }
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirmReplace() async {
    final p = AbodePalette.of(context);
    final confirm = await showAbodeConfirmDialog(
      context,
      title: 'Replace document?',
      body: 'This will replace the existing ${widget.type} file.',
      confirmLabel: 'Replace',
      icon: Icons.upload_file_outlined,
    );
    if (confirm == true) await _upload();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final meta = _kDocMeta[widget.type];
    final label = meta?.label ?? widget.type;
    final subtitle = meta?.subtitle;
    final icon = meta?.icon ?? Icons.description_outlined;
    final color = meta?.color ?? p.green;

    void onTap() {
      if (_uploading) return;
      if (hasDoc) {
        if (widget.canUpload) {
          _confirmReplace();
        } else {
          _open();
        }
      } else if (widget.canUpload) {
        _upload();
      }
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasDoc
                        ? color.withValues(alpha: 0.12)
                        : p.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _uploading
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color),
                        )
                      : Icon(icon,
                          size: 20,
                          color: hasDoc ? color : p.muted),
                ),
                const SizedBox(width: 14),

                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: p.sub,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (hasDoc && widget.doc.fileName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.attach_file_rounded,
                              size: 10, color: p.muted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.doc.fileName,
                              style: TextStyle(
                                  color: p.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing badge
                if (_uploading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                else if (hasDoc && widget.canUpload)
                  // Landlord: tap to view, long-press to replace
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: _open,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 11, color: color),
                          const SizedBox(width: 4),
                          Text('View',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _confirmReplace,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: p.border, width: 0.5),
                        ),
                        child: Icon(Icons.upload_rounded,
                            size: 13, color: p.muted),
                      ),
                    ),
                  ])
                else if (hasDoc)
                  // Tenant: view only
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 11, color: color),
                      const SizedBox(width: 4),
                      Text('View',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  )
                else if (widget.canUpload)
                  // Landlord: upload prompt
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          width: 0.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.upload_rounded,
                          size: 11, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      const Text('Upload',
                          style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  )
                else
                  // Tenant: pending
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.border, width: 0.5),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                          color: p.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isLast)
            Divider(
              height: 1,
              indent: 72,
              endIndent: 0,
              color: p.border,
              thickness: 0.5,
            ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: p.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

// ─── List widget (used in landlord panel via ComplianceDocsPanel) ─────────────

class _DocList extends StatelessWidget {
  final List<ComplianceDoc> docs;
  final String tenancyId;
  final bool canUpload;
  final VoidCallback onRefresh;

  const _DocList({
    required this.docs,
    required this.tenancyId,
    required this.canUpload,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<String>>{};
    for (final type in kComplianceDocTypes) {
      final meta = _kDocMeta[type];
      if (meta == null) continue;
      sections.putIfAbsent(meta.section, () => []).add(type);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sections.entries) ...[
          _SectionHeader(title: entry.key),
          const SizedBox(height: 8),
          _DocSection(
            types: entry.value,
            docs: docs,
            tenancyId: tenancyId,
            canUpload: canUpload,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
