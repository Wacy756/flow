import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/compliance_doc.dart';
import '../providers/dashboard_providers.dart';
import 'compliance_expiry_dialog.dart';

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
    final docsAsync = ref.watch(complianceDocsProvider(tenancyId));

    return docsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.green)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading docs: $e',
            style: const TextStyle(color: Colors.red)),
      ),
      data: (docs) => _DocGrid(
        docs: docs,
        tenancyId: tenancyId,
        canUpload: canUpload,
        onRefresh: () => ref.invalidate(complianceDocsProvider(tenancyId)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DocGrid extends StatelessWidget {
  final List<ComplianceDoc> docs;
  final String tenancyId;
  final bool canUpload;
  final VoidCallback onRefresh;

  const _DocGrid({
    required this.docs,
    required this.tenancyId,
    required this.canUpload,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Count docs with alert status for a summary row
    final alerts = docs.where((d) =>
        d.complianceStatus == ComplianceStatus.expired ||
        d.complianceStatus == ComplianceStatus.expiringSoon).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alert summary if any docs need attention
        if (alerts.isNotEmpty) ...[
          _AlertSummaryRow(alerts: alerts),
          const SizedBox(height: 12),
        ],

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: kComplianceDocTypes.map((type) {
            final doc = docs.firstWhere(
              (d) => d.docType == type,
              orElse: () => ComplianceDoc(
                id: '',
                tenancyId: tenancyId,
                docType: type,
                filePath: '',
                fileName: '',
              ),
            );
            final hasDoc = doc.id.isNotEmpty;

            return _DocTile(
              type: type,
              doc: hasDoc ? doc : null,
              tenancyId: tenancyId,
              canUpload: canUpload,
              onRefresh: onRefresh,
              onDownload: hasDoc ? () => _openDoc(context, doc) : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _openDoc(BuildContext context, ComplianceDoc doc) async {
    try {
      if (doc.isExternal) {
        final url = Uri.parse(doc.filePath.replaceFirst('EXT:', ''));
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
      final response = await Supabase.instance.client.storage
          .from('compliance-docs')
          .createSignedUrl(doc.filePath, 60);
      await launchUrl(Uri.parse(response),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open document: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------

class _AlertSummaryRow extends StatelessWidget {
  final List<ComplianceDoc> alerts;
  const _AlertSummaryRow({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final expired = alerts.where(
        (d) => d.complianceStatus == ComplianceStatus.expired).length;
    final expiring = alerts.where(
        (d) => d.complianceStatus == ComplianceStatus.expiringSoon).length;

    String text;
    Color color;
    Color bg;

    if (expired > 0) {
      text = expired == 1
          ? '1 document has expired'
          : '$expired documents have expired';
      color = Colors.red;
      bg = const Color(0xFFFFEBEE);
    } else {
      text = expiring == 1
          ? '1 document expiring within 60 days'
          : '$expiring documents expiring within 60 days';
      color = const Color(0xFFE65100);
      bg = const Color(0xFFFFF3E0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DocTile extends StatefulWidget {
  final String type;
  final ComplianceDoc? doc;
  final String tenancyId;
  final bool canUpload;
  final VoidCallback onRefresh;
  final VoidCallback? onDownload;

  const _DocTile({
    required this.type,
    this.doc,
    required this.tenancyId,
    required this.canUpload,
    required this.onRefresh,
    this.onDownload,
  });

  @override
  State<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends State<_DocTile> {
  bool _uploading = false;

  (String, String?) get _parts {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(widget.type);
    if (match != null) {
      return (match.group(1)!.trim(), match.group(2)!.trim());
    }
    return (widget.type, null);
  }

  Future<void> _upload() async {
    // 1. Show expiry dialog first
    if (!mounted) return;
    final meta = await showComplianceExpiryDialog(
      context,
      docType: widget.type,
      initialIssueDate: widget.doc?.issueDate,
      initialExpiryDate: widget.doc?.expiryDate,
      initialCertNumber: widget.doc?.certNumber,
    );
    // null = user dismissed the sheet entirely (tapped outside)
    // We allow upload even if meta == null (they tapped Skip → returns record with nulls)
    // But showModalBottomSheet returns null on dismiss, vs the record on either button.
    // If null (dismissed without action), abort.
    if (meta == null && mounted) return;

    // 2. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;

    setState(() => _uploading = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final safeName = widget.type
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final ext = file.extension ?? 'pdf';
      final path = '${widget.tenancyId}/$safeName.$ext';

      await client.storage.from('compliance-docs').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeType(ext),
              upsert: true,
            ),
          );

      await client.from('compliance_docs').upsert(
        {
          'tenancy_id': widget.tenancyId,
          'doc_type': widget.type,
          'file_path': path,
          'file_name': file.name,
          'uploaded_by': user.id,
          if (meta != null) ...{
            if (meta.issueDate != null)
              'issue_date': meta.issueDate!.toIso8601String().split('T').first,
            if (meta.expiryDate != null)
              'expiry_date':
                  meta.expiryDate!.toIso8601String().split('T').first,
            if (meta.certNumber != null) 'cert_number': meta.certNumber,
          },
        },
        onConflict: 'tenancy_id,doc_type',
      );

      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully.'),
            backgroundColor: AppTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (name, acronym) = _parts;
    final hasDoc = widget.doc != null;
    final status =
        hasDoc ? widget.doc!.complianceStatus : ComplianceStatus.unknown;
    final showStatus = hasDoc && status != ComplianceStatus.unknown;

    // Border colour: red if expired, amber if expiring, green if valid, default otherwise
    final borderColor = hasDoc
        ? (status == ComplianceStatus.expired
            ? Colors.red.withValues(alpha: 0.4)
            : status == ComplianceStatus.expiringSoon
                ? const Color(0xFFE65100).withValues(alpha: 0.3)
                : status == ComplianceStatus.valid
                    ? AppTheme.green.withValues(alpha: 0.3)
                    : AppTheme.border)
        : AppTheme.border;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: hasDoc ? 1.0 : 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasDoc ? status.bgColor : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: hasDoc ? status.color : AppTheme.textMuted,
                ),
              ),
              // RAG dot badge
              if (showStatus)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.bgPage, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (acronym != null) ...[
            const SizedBox(height: 2),
            Text(
              acronym,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],

          // Expiry info
          if (hasDoc && widget.doc!.expiryFormatted != null) ...[
            const SizedBox(height: 4),
            Text(
              'Exp: ${widget.doc!.expiryFormatted}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: status.color,
              ),
            ),
          ],

          const SizedBox(height: 8),

          if (hasDoc)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onDownload,
                icon: const Icon(Icons.open_in_new, size: 12),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          else if (widget.canUpload)
            SizedBox(
              width: double.infinity,
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.green),
                      ),
                    )
                  : GestureDetector(
                      onTap: _upload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.greenBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'UPLOAD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.green,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.bgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: const Text(
                'NOT UPLOADED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
