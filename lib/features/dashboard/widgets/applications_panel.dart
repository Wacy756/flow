import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/application.dart';
import '../providers/dashboard_providers.dart';

// ============================================================
// Applications panel — shown in the landlord dashboard as a
// section that lists all incoming property applications.
// ============================================================

class ApplicationsPanel extends ConsumerWidget {
  const ApplicationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(landlordApplicationsProvider);

    return appsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(
                color: AppTheme.green, strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Failed to load applications: $e',
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      ),
      data: (apps) {
        if (apps.isEmpty) {
          return _EmptyApplications();
        }

        // Split into pending vs reviewed
        final pending =
            apps.where((a) => a.status == 'pending').toList();
        final reviewed =
            apps.where((a) => a.status != 'pending').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isNotEmpty) ...[
              _SubHeader(
                  label: 'AWAITING REVIEW',
                  count: pending.length,
                  color: Colors.orange.shade700),
              const SizedBox(height: 8),
              ...pending.map((a) => _ApplicationCard(application: a)),
              const SizedBox(height: 16),
            ],
            if (reviewed.isNotEmpty) ...[
              _SubHeader(label: 'REVIEWED', count: reviewed.length),
              const SizedBox(height: 8),
              ...reviewed.map((a) => _ApplicationCard(application: a)),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyApplications extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                size: 36, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            const Text(
              'No applications yet.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'List a property to start receiving applications.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _SubHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SubHeader({
    required this.label,
    required this.count,
    this.color = AppTheme.textMuted,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------

class _ApplicationCard extends ConsumerStatefulWidget {
  final Application application;
  const _ApplicationCard({required this.application});

  @override
  ConsumerState<_ApplicationCard> createState() =>
      _ApplicationCardState();
}

class _ApplicationCardState
    extends ConsumerState<_ApplicationCard> {
  bool _expanded = false;
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.application;
    final statusColor = _statusColor(a.status);
    final statusBg = _statusBg(a.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.status == 'pending'
              ? Colors.orange.withValues(alpha: 0.2)
              : AppTheme.border,
          width: a.status == 'pending' ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // Summary row
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.tenantBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        (a.applicantName?.isNotEmpty == true
                                ? a.applicantName![0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + address
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.applicantName ?? 'Unknown applicant',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          a.addressFormatted,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                        if (a.monthlyRent != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            '£${a.monthlyRent!.toStringAsFixed(0)}/mo',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status pill + chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(a.createdAt),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? _ExpandedDetail(
                    application: a,
                    acting: _acting,
                    onApprove: a.status == 'pending'
                        ? () => _review(a, approve: true)
                        : null,
                    onReject: a.status == 'pending'
                        ? () => _review(a, approve: false)
                        : null,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _review(Application a, {required bool approve}) async {
    setState(() => _acting = true);
    final notifier = ref.read(reviewApplicationProvider.notifier);
    final ok = approve
        ? await notifier.approve(a.id, a.listingId)
        : await notifier.reject(a.id, a.listingId);

    if (!mounted) return;
    setState(() => _acting = false);

    if (ok) {
      ref.invalidate(landlordApplicationsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action failed — please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange.shade700;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.greenBg;
      case 'rejected':
        return Colors.red.withValues(alpha: 0.08);
      default:
        return Colors.orange.withValues(alpha: 0.1);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

// ---------------------------------------------------------------------------

class _ExpandedDetail extends StatelessWidget {
  final Application application;
  final bool acting;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ExpandedDetail({
    required this.application,
    required this.acting,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final a = application;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact
              if (a.applicantEmail != null) ...[
                _DetailRow(
                    icon: Icons.email_outlined,
                    label: a.applicantEmail!),
                const SizedBox(height: 8),
              ],

              // Household
              _DetailRow(
                icon: Icons.group_outlined,
                label:
                    '${a.numAdults} adult${a.numAdults == 1 ? '' : 's'}${a.numChildren > 0 ? ', ${a.numChildren} child${a.numChildren == 1 ? '' : 'ren'}' : ''}',
              ),
              const SizedBox(height: 8),

              // Employment
              if (a.employmentStatus != null) ...[
                _DetailRow(
                  icon: Icons.work_outline,
                  label: a.employmentStatusFormatted +
                      (a.employerName != null
                          ? ' — ${a.employerName}'
                          : '') +
                      (a.monthlyIncome != null
                          ? ' (£${a.monthlyIncome!.toStringAsFixed(0)}/mo)'
                          : ''),
                ),
                const SizedBox(height: 8),
              ],

              // Move-in
              _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Move-in: ${a.moveInFormatted}'),
              const SizedBox(height: 8),

              // Flags
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (a.hasPets)
                    _FlagChip(
                        label: 'Pets',
                        icon: Icons.pets_outlined,
                        warning: true),
                  if (a.isSmoker)
                    _FlagChip(
                        label: 'Smoker',
                        icon: Icons.smoking_rooms_outlined,
                        warning: true),
                  if (a.hasCcj)
                    _FlagChip(
                        label: 'CCJ',
                        icon: Icons.gavel_outlined,
                        warning: true),
                  if (!a.hasPets && !a.isSmoker && !a.hasCcj)
                    _FlagChip(
                        label: 'No flags',
                        icon: Icons.check_circle_outline,
                        warning: false),
                ],
              ),

              if (a.notes != null && a.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPage,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Text(
                    a.notes!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4),
                  ),
                ),
              ],

              if (a.rejectionReason != null &&
                  a.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Rejection reason: ${a.rejectionReason}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons
              if (onApprove != null || onReject != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (onReject != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: acting ? null : onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                                color: Colors.red, width: 1.0),
                            minimumSize:
                                const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                          child: acting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.red))
                              : const Text('Reject'),
                        ),
                      ),
                    if (onApprove != null && onReject != null)
                      const SizedBox(width: 8),
                    if (onApprove != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: acting ? null : onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            minimumSize:
                                const Size(double.infinity, 40),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                          child: acting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text(
                                  'Approve',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4),
            ),
          ),
        ],
      );
}

class _FlagChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool warning;

  const _FlagChip(
      {required this.label,
      required this.icon,
      required this.warning});

  @override
  Widget build(BuildContext context) {
    final color =
        warning ? Colors.orange.shade700 : AppTheme.green;
    final bg = warning
        ? Colors.orange.withValues(alpha: 0.08)
        : AppTheme.greenBg;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}
