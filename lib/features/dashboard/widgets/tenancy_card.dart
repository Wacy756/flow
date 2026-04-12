import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/tenancy.dart';
import 'compliance_docs_panel.dart';

class TenancyCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final bool canUploadDocs;
  final VoidCallback? onDelete;

  const TenancyCard({
    super.key,
    required this.tenancy,
    this.canUploadDocs = false,
    this.onDelete,
  });

  @override
  ConsumerState<TenancyCard> createState() => _TenancyCardState();
}

class _TenancyCardState extends ConsumerState<TenancyCard> {
  bool _expanded = false;
  bool _showingDocs = false; // false = overview, true = compliance docs

  @override
  Widget build(BuildContext context) {
    final t = widget.tenancy;
    final isActive = t.status == 'active';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _expanded = !_expanded;
              if (!_expanded) _showingDocs = false;
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryLight
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      color: isActive
                          ? AppTheme.primaryDark
                          : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.shortAddress,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.tenants.isEmpty
                              ? 'No tenants yet'
                              : '${t.tenants.map((x) => x.fullName ?? '').join(', ')} • ${_capitalize(t.status)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (t.monthlyRent != null)
                        Text(
                          '£${t.monthlyRent!.toStringAsFixed(0)}/mo',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      if (t.propertyType != null)
                        Text(t.propertyType!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail section
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const Divider(height: 1),
                      // Tab bar: Overview | Compliance Docs
                      _TabBar(
                        showingDocs: _showingDocs,
                        onSwitch: (v) => setState(() => _showingDocs = v),
                      ),
                      const Divider(height: 1),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _showingDocs
                            ? Padding(
                                key: const ValueKey('docs'),
                                padding: const EdgeInsets.all(16),
                                child: ComplianceDocsPanel(
                                  tenancyId: t.tenancyId,
                                  canUpload: widget.canUploadDocs,
                                ),
                              )
                            : Padding(
                                key: const ValueKey('overview'),
                                padding: const EdgeInsets.all(16),
                                child: _OverviewPanel(
                                  tenancy: t,
                                  onDelete: widget.onDelete,
                                ),
                              ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  final bool showingDocs;
  final void Function(bool) onSwitch;

  const _TabBar({required this.showingDocs, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Tab(
            label: 'Overview',
            isActive: !showingDocs,
            onTap: () => onSwitch(false),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Compliance Docs',
            isActive: showingDocs,
            onTap: () => onSwitch(true),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.primary : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.primaryDark : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OverviewPanel extends ConsumerWidget {
  final Tenancy tenancy;
  final VoidCallback? onDelete;

  const _OverviewPanel({required this.tenancy, this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tenancy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Three columns: Property | Financials | Tenancy
        _SectionLabel(Icons.location_on_outlined, 'Property'),
        const SizedBox(height: 8),
        Text(
          [
            t.addressLine1,
            if (t.addressLine2 != null && t.addressLine2!.isNotEmpty)
              t.addressLine2!,
            if (t.addressLine3 != null && t.addressLine3!.isNotEmpty)
              t.addressLine3!,
            '${t.town ?? ''}, ${t.postcode}',
          ].join('\n'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (t.numBedrooms != null) ...[
              const Icon(Icons.bed_outlined, size: 16,
                  color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${t.numBedrooms}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
            ],
            if (t.numBathrooms != null) ...[
              const Icon(Icons.bathtub_outlined, size: 16,
                  color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${t.numBathrooms}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
            ],
            if (t.maxTenants != null) ...[
              const Icon(Icons.people_outline, size: 16,
                  color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Max ${t.maxTenants}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
        if (t.propertyType != null || t.furnishing != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (t.propertyType != null) _capitalize(t.propertyType!),
              if (t.furnishing != null) _capitalize(t.furnishing!),
            ].join(' • '),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],

        const SizedBox(height: 20),
        _SectionLabel(Icons.currency_pound, 'Financials'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _FinanceBox(label: 'Monthly', value: t.monthlyRent)),
            const SizedBox(width: 8),
            Expanded(child: _FinanceBox(label: 'Weekly', value: t.weeklyRent)),
            const SizedBox(width: 8),
            Expanded(
                child: _FinanceBox(label: 'Deposit', value: t.depositAmount)),
          ],
        ),

        const SizedBox(height: 20),
        _SectionLabel(Icons.calendar_today_outlined, 'Tenancy'),
        const SizedBox(height: 8),
        if (t.moveInDate != null) ...[
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            iconColor: const Color(0xFF2563EB),
            label: 'Move-in Date',
            value: _formatDate(t.moveInDate!),
          ),
          const SizedBox(height: 8),
        ],
        if (t.minTenancyLength != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${t.minTenancyLength} Months Minimum',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Tenants list
        if (t.tenants.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel(Icons.people_outline, 'Tenants'),
          const SizedBox(height: 8),
          ...t.tenants.map((tenant) => _TenantRow(tenant: tenant)),
        ],

        // Delete action
        if (onDelete != null) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Colors.red),
              label: const Text('Delete Tenancy',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Tenancy'),
        content: const Text(
            'Are you sure? This will remove all tenants from this property. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      );
}

class _FinanceBox extends StatelessWidget {
  final String label;
  final double? value;
  const _FinanceBox({required this.label, this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value != null ? '£${value!.toStringAsFixed(0)}' : '—',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      );
}

class _TenantRow extends StatelessWidget {
  final TenantProfile tenant;
  const _TenantRow({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final isActive = tenant.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant.fullName ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(tenant.email ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFFCD34D),
              ),
            ),
            child: Text(
              isActive ? 'Accepted' : 'Pending',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFFD97706),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
