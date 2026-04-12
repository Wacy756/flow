import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/compliance_doc.dart';
import '../providers/dashboard_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplianceDocsPanel extends ConsumerWidget {
  final String tenancyId;
  final bool canUpload; // landlords can upload, tenants can only view

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
        child: Center(child: CircularProgressIndicator()),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: kComplianceDocTypes
          .map((type) {
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
              canUpload: canUpload,
              onDownload: hasDoc ? () => _openDoc(context, doc) : null,
            );
          })
          .toList(),
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

      final url = Uri.parse(response);
      await launchUrl(url, mode: LaunchMode.externalApplication);
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

class _DocTile extends StatelessWidget {
  final String type;
  final ComplianceDoc? doc;
  final bool canUpload;
  final VoidCallback? onDownload;

  const _DocTile({
    required this.type,
    this.doc,
    required this.canUpload,
    this.onDownload,
  });

  // Split "EPC (Energy Performance Certificate)" into name + acronym
  (String, String?) get _parts {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(type);
    if (match != null) {
      return (match.group(1)!.trim(), match.group(2)!.trim());
    }
    return (type, null);
  }

  @override
  Widget build(BuildContext context) {
    final (name, acronym) = _parts;
    final hasDoc = doc != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasDoc
                  ? AppTheme.primaryLight
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 22,
              color: hasDoc ? AppTheme.primaryDark : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (acronym != null) ...[
            const SizedBox(height: 2),
            Text(
              acronym,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          if (hasDoc)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.open_in_new, size: 12),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else if (canUpload)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'UPLOAD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                  letterSpacing: 0.8,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
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
