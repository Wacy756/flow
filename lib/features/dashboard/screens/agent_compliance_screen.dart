import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/compliance_doc.dart';
import '../providers/agent_providers.dart';

class AgentComplianceScreen extends ConsumerWidget {
  const AgentComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(agentComplianceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: docsAsync.maybeWhen(
          data: (d) => Text('Compliance (${d.length})'),
          orElse: () => const Text('Compliance'),
        ),
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: TextStyle(color: AppTheme.error),
              textAlign: TextAlign.center),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined,
                      size: 48, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'No compliance documents yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          // ── Stats header ────────────────────────────────────────────
          final total = docs.length;
          final external = docs.where((d) => d.isExternal).length;
          final uploaded = total - external;

          return RefreshIndicator(
            color: AppTheme.agentColor,
            onRefresh: () async => ref.invalidate(agentComplianceProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        _StatPill(
                          label: 'Total',
                          value: '$total',
                          color: AppTheme.agentColor,
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Uploaded',
                          value: '$uploaded',
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'External',
                          value: '$external',
                          color: AppTheme.info,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // ── Grouped by doc_type ──────────────────────────────
                ..._buildGroupedSections(context, docs),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedSections(
      BuildContext context, List<ComplianceDoc> docs) {
    final Map<String, List<ComplianceDoc>> grouped = {};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.docType, () => []).add(doc);
    }

    return grouped.entries.map((entry) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(docType: entry.key, count: entry.value.length),
              const SizedBox(height: 8),
              ...entry.value.map((doc) => _ComplianceDocTile(doc: doc)),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String docType;
  final int count;

  const _SectionHeader({required this.docType, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_docIcon(docType), size: 16, color: AppTheme.agentColor),
        const SizedBox(width: 8),
        Text(
          docType.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.agentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.agentColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  IconData _docIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('gas')) return Icons.local_fire_department_outlined;
    if (t.contains('epc') || t.contains('energy')) return Icons.bolt_outlined;
    if (t.contains('eicr') || t.contains('electrical')) return Icons.electrical_services_outlined;
    if (t.contains('right')) return Icons.badge_outlined;
    if (t.contains('tenancy') || t.contains('agreement')) return Icons.description_outlined;
    return Icons.article_outlined;
  }
}

class _ComplianceDocTile extends StatelessWidget {
  final ComplianceDoc doc;

  const _ComplianceDocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isExternal = doc.isExternal;
    final displayPath = isExternal
        ? doc.filePath.replaceFirst('EXT:', '')
        : doc.fileName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            isExternal ? Icons.link : Icons.attach_file,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  displayPath,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isExternal)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              color: AppTheme.info,
              tooltip: 'Open link',
              onPressed: () async {
                final url = Uri.tryParse(displayPath);
                if (url != null) await launchUrl(url);
              },
            ),
        ],
      ),
    );
  }
}
