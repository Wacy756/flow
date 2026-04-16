import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/application.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'compliance_docs_panel.dart';
import 'end_tenancy_checklist_sheet.dart';
import 'list_property_sheet.dart';
import 'rent_ledger_panel.dart';
import 'serve_notice_sheet.dart';

class TenancyCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final bool canUploadDocs;
  final bool canManageListing;
  final UserProfile? landlordProfile;
  final VoidCallback? onDelete;

  /// When true the card starts expanded (used for notification deep-linking).
  final bool autoExpand;

  const TenancyCard({
    super.key,
    required this.tenancy,
    this.canUploadDocs = false,
    this.canManageListing = false,
    this.landlordProfile,
    this.onDelete,
    this.autoExpand = false,
  });

  @override
  ConsumerState<TenancyCard> createState() => _TenancyCardState();
}

enum _TenancyTab { overview, docs, payments, applications }

class _TenancyCardState extends ConsumerState<TenancyCard> {
  bool _expanded = false;
  _TenancyTab _tab = _TenancyTab.overview;

  @override
  void initState() {
    super.initState();
    if (widget.autoExpand) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tenancy;
    final isActive = t.status == 'active';
    // Landlord view if they can upload docs (canUploadDocs is true for landlords)
    final isLandlordView = widget.canUploadDocs;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _expanded = !_expanded;
              if (!_expanded) _tab = _TenancyTab.overview;
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.border, width: 0.5),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      color: isActive
                          ? AppTheme.green
                          : AppTheme.textMuted,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.tenants.isEmpty
                              ? 'No tenants yet'
                              : '${t.tenants.map((x) => x.fullName ?? '').join(', ')} • ${_capitalize(t.status)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      if (t.propertyType != null)
                        Text(t.propertyType!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            )),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Status pill
                  _StatusPill(status: t.status),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                    size: 20,
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
                      _TabBar(
                        activeTab: _tab,
                        showApplications: widget.canManageListing,
                        onSwitch: (v) => setState(() => _tab = v),
                        isLandlordView: isLandlordView,
                      ),
                      const Divider(height: 1),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: switch (_tab) {
                          _TenancyTab.docs => Padding(
                              key: const ValueKey('docs'),
                              padding: const EdgeInsets.all(16),
                              child: ComplianceDocsPanel(
                                tenancyId: t.tenancyId,
                                canUpload: widget.canUploadDocs,
                              ),
                            ),
                          _TenancyTab.payments => Padding(
                              key: const ValueKey('payments'),
                              padding: const EdgeInsets.all(16),
                              child: RentLedgerPanel(
                                tenancy: t,
                                canLog: isLandlordView,
                              ),
                            ),
                          _TenancyTab.applications => Padding(
                              key: const ValueKey('apps'),
                              padding: const EdgeInsets.all(16),
                              child: _ApplicationsPanel(
                                propertyId: t.tenancyId,
                              ),
                            ),
                          _TenancyTab.overview => Padding(
                              key: const ValueKey('overview'),
                              padding: const EdgeInsets.all(16),
                              child: _OverviewPanel(
                                tenancy: t,
                                onDelete: widget.onDelete,
                                canManageListing: widget.canManageListing,
                                landlordProfile: widget.landlordProfile,
                              ),
                            ),
                        },
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

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (status) {
      case 'active':
        bg = AppTheme.greenBg;
        fg = AppTheme.green;
        label = 'ACTIVE';
      case 'notice_given':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'NOTICE';
      case 'ended':
        bg = const Color(0xFFF5F5F5);
        fg = AppTheme.textMuted;
        label = 'ENDED';
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  final _TenancyTab activeTab;
  final bool showApplications;
  final bool isLandlordView;
  final void Function(_TenancyTab) onSwitch;

  const _TabBar({
    required this.activeTab,
    required this.showApplications,
    required this.onSwitch,
    this.isLandlordView = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Tab(
            label: 'Overview',
            isActive: activeTab == _TenancyTab.overview,
            onTap: () => onSwitch(_TenancyTab.overview),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Compliance Docs',
            isActive: activeTab == _TenancyTab.docs,
            onTap: () => onSwitch(_TenancyTab.docs),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Payments',
            isActive: activeTab == _TenancyTab.payments,
            onTap: () => onSwitch(_TenancyTab.payments),
          ),
          if (showApplications) ...[
            const SizedBox(width: 8),
            _Tab(
              label: 'Applications',
              isActive: activeTab == _TenancyTab.applications,
              onTap: () => onSwitch(_TenancyTab.applications),
            ),
          ],
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
          color: isActive ? AppTheme.greenBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.green : AppTheme.border,
            width: isActive ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.green : AppTheme.textSecondary,
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
  final bool canManageListing;
  final UserProfile? landlordProfile;

  const _OverviewPanel({
    required this.tenancy,
    this.onDelete,
    this.canManageListing = false,
    this.landlordProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tenancy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            iconColor: AppTheme.green,
            label: 'Move-in Date',
            value: _formatDate(t.moveInDate!),
          ),
          const SizedBox(height: 8),
        ],
        if (t.minTenancyLength != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.greenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${t.minTenancyLength} Months Minimum',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.green,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (t.tenants.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel(Icons.people_outline, 'Tenants'),
          const SizedBox(height: 8),
          ...t.tenants.map((tenant) => _TenantRow(tenant: tenant)),
        ],

        if (canManageListing && landlordProfile != null) ...[
          const SizedBox(height: 20),
          _SectionLabel(Icons.storefront_outlined, 'Listing'),
          const SizedBox(height: 8),
          _ListingSection(
            tenancy: tenancy,
            landlordProfile: landlordProfile!,
          ),
        ],

        // Tenancy end workflow actions (landlord only)
        if (onDelete != null) ...[
          if (t.isActive) ...[
            const SizedBox(height: 20),
            _SectionLabel(Icons.gavel_outlined, 'End of Tenancy'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showServeNoticeSheet(
                  context,
                  tenancyGroupId: t.tenancyId,
                  address: t.shortAddress,
                ),
                icon: const Icon(Icons.notification_important_outlined,
                    size: 16),
                label: const Text('Serve Notice'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(
                      color: Color(0xFFE65100), width: 1.0),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          if (t.isNoticeGiven) ...[
            const SizedBox(height: 20),
            _SectionLabel(Icons.gavel_outlined, 'End of Tenancy'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
                    width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important_outlined,
                          size: 14, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        t.noticeTypeFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                  if (t.vacateDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Vacate date: ${_formatDate(t.vacateDate!)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFE65100)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showEndTenancySheet(
                  context,
                  tenancyGroupId: t.tenancyId,
                  address: t.shortAddress,
                  vacateDate: t.vacateDate,
                ),
                icon: const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.white),
                label: const Text(
                  'Finalise Tenancy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: AppTheme.textMuted),
              label: const Text('Delete Tenancy',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 13)),
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
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tenancy',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4)),
        content: const Text(
            'Are you sure? This will remove all tenants from this property. This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMuted),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
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
              letterSpacing: 0.08,
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
          color: AppTheme.bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border, width: 0.5),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
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
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      );
}

// ---------------------------------------------------------------------------

class _ListingSection extends ConsumerWidget {
  final Tenancy tenancy;
  final UserProfile landlordProfile;

  const _ListingSection({
    required this.tenancy,
    required this.landlordProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync =
        ref.watch(propertyListingProvider(tenancy.tenancyId));

    return listingAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.green),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (listing) {
        if (listing == null) {
          return OutlinedButton.icon(
            onPressed: () => showListPropertySheet(
              context,
              tenancy: tenancy,
              landlordProfile: landlordProfile,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create Listing'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.green,
              side: const BorderSide(color: AppTheme.green, width: 1.5),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: listing.isActive ? AppTheme.greenBg : AppTheme.bgPage,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: listing.isActive
                  ? AppTheme.green.withValues(alpha: 0.3)
                  : AppTheme.border,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: listing.isActive
                          ? AppTheme.green
                          : AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      listing.isActive ? 'LIVE' : 'PAUSED',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (listing.askingRent != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '£${listing.askingRent!.toStringAsFixed(0)}/mo',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: listing.shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard'),
                          backgroundColor: AppTheme.darkBg,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy,
                        size: 16, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(toggleListingProvider.notifier)
                          .toggle(
                            tenancy.tenancyId,
                            isActive: !listing.isActive,
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(
                            color: AppTheme.border, width: 0.5),
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          Text(listing.isActive ? 'Pause' : 'Resume'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showListPropertySheet(
                        context,
                        tenancy: tenancy,
                        landlordProfile: landlordProfile,
                        existing: listing,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.green,
                        side: const BorderSide(
                            color: AppTheme.green, width: 1.0),
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _ApplicationsPanel extends ConsumerWidget {
  final String propertyId;
  const _ApplicationsPanel({required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need the listing id — fetch the listing first
    final listingAsync = ref.watch(propertyListingProvider(propertyId));

    return listingAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.green),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (listing) {
        if (listing == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: const Text(
              'No listing yet — create one to start receiving applications.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          );
        }
        return _ApplicationsList(listingId: listing.id);
      },
    );
  }
}

class _ApplicationsList extends ConsumerWidget {
  final String listingId;
  const _ApplicationsList({required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(listingApplicationsProvider(listingId));

    return appsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.green),
        ),
      ),
      error: (_, __) => const Text('Failed to load applications.',
          style: TextStyle(color: AppTheme.textSecondary)),
      data: (apps) {
        if (apps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 36, color: AppTheme.textMuted),
                const SizedBox(height: 10),
                const Text(
                  'No applications yet.',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${apps.length} Application${apps.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref
                      .invalidate(listingApplicationsProvider(listingId)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.green,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Refresh',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...apps.map((app) => _ApplicationCard(
                  application: app,
                  listingId: listingId,
                )),
          ],
        );
      },
    );
  }
}

class _ApplicationCard extends ConsumerStatefulWidget {
  final Application application;
  final String listingId;
  const _ApplicationCard(
      {required this.application, required this.listingId});

  @override
  ConsumerState<_ApplicationCard> createState() =>
      _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final isPending = app.status == 'pending';
    final isApproved = app.status == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? AppTheme.green.withValues(alpha: 0.3)
              : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isApproved
                          ? AppTheme.greenBg
                          : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        (app.applicantName?.isNotEmpty == true)
                            ? app.applicantName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isApproved
                              ? AppTheme.green
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.applicantName ?? 'Applicant',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.applicantEmail ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AppStatusPill(status: app.status),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _DetailGrid(app: app),
                            if (app.notes != null &&
                                app.notes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'NOTES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                app.notes!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (isPending) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _reject(context),
                                      style:
                                          OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Colors.red,
                                        side: BorderSide(
                                            color: Colors.red
                                                .withValues(
                                                    alpha: 0.5)),
                                        minimumSize:
                                            const Size(0, 40),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                        ),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _approve(context),
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.green,
                                        minimumSize:
                                            const Size(0, 40),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Approve',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (app.status == 'rejected' &&
                                app.rejectionReason != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red
                                      .withValues(alpha: 0.06),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Reason: ${app.rejectionReason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  Future<void> _approve(BuildContext context) async {
    final ok = await ref
        .read(reviewApplicationProvider.notifier)
        .approve(widget.application.id, widget.listingId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to approve application.'),
        backgroundColor: AppTheme.darkBg,
      ));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Application',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optionally provide a reason (visible to applicant):',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Position has been filled',
                hintStyle: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.green, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final reason = reasonCtrl.text.trim().isEmpty
          ? null
          : reasonCtrl.text.trim();
      final ok = await ref
          .read(reviewApplicationProvider.notifier)
          .reject(widget.application.id, widget.listingId,
              reason: reason);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to reject application.'),
          backgroundColor: AppTheme.darkBg,
        ));
      }
    }
  }
}

class _DetailGrid extends StatelessWidget {
  final Application app;
  const _DetailGrid({required this.app});

  @override
  Widget build(BuildContext context) {
    final occupants = app.numChildren > 0
        ? '${app.numAdults} adult${app.numAdults != 1 ? 's' : ''}, ${app.numChildren} child${app.numChildren != 1 ? 'ren' : ''}'
        : '${app.numAdults} adult${app.numAdults != 1 ? 's' : ''}';

    final items = <(String, String)>[
      ('Occupants', occupants),
      ('Employment', app.employmentStatusFormatted),
      if (app.employerName != null) ('Employer', app.employerName!),
      if (app.monthlyIncome != null)
        ('Monthly Income', '£${app.monthlyIncome!.toStringAsFixed(0)}'),
      ('Move-in', app.moveInFormatted),
      ('Pets', app.hasPets ? (app.petDetails ?? 'Yes') : 'No'),
      ('Smoker', app.isSmoker ? 'Yes' : 'No'),
      ('CCJ / Bankruptcy', app.hasCcj ? (app.ccjDetails ?? 'Yes — see notes') : 'None declared'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.$1.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.$2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AppStatusPill extends StatelessWidget {
  final String status;
  const _AppStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'approved':
        bg = AppTheme.greenBg;
        fg = AppTheme.green;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant.fullName ?? '—',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
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
              color: isActive ? AppTheme.greenBg : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'Accepted' : 'Pending',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isActive ? AppTheme.green : const Color(0xFFE65100),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
