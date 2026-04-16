import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/rent_payment.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'log_payment_sheet.dart';

// ignore_for_file: use_build_context_synchronously

class RentLedgerPanel extends ConsumerWidget {
  final Tenancy tenancy;
  final bool canLog; // true for landlord

  const RentLedgerPanel({
    super.key,
    required this.tenancy,
    required this.canLog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(rentPaymentsProvider(tenancy.tenancyId));

    return paymentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.green, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading payments: $e',
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      ),
      data: (payments) => _LedgerContent(
        payments: payments,
        tenancy: tenancy,
        canLog: canLog,
        onRefresh: () => ref.invalidate(
            rentPaymentsProvider(tenancy.tenancyId)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LedgerContent extends StatelessWidget {
  final List<RentPayment> payments;
  final Tenancy tenancy;
  final bool canLog;
  final VoidCallback onRefresh;

  const _LedgerContent({
    required this.payments,
    required this.tenancy,
    required this.canLog,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalArrears = payments.totalArrears;

    // Find next upcoming payment (pending/late, most imminent due date first)
    final upcoming = payments
        .where((p) => !p.isPaid)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextDue = upcoming.isNotEmpty ? upcoming.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tenant summary card — replaces the raw arrears banner for tenants
        if (!canLog) ...[
          _TenantRentSummary(
            nextDue: nextDue,
            totalArrears: totalArrears,
          ),
          const SizedBox(height: 14),
        ] else if (totalArrears > 0) ...[
          // Landlord keeps the compact arrears banner
          _ArrearsBanner(totalArrears: totalArrears),
          const SizedBox(height: 14),
        ],

        // Header row
        Row(
          children: [
            Text(
              payments.isEmpty
                  ? 'No payments logged yet'
                  : '${payments.length} Payment${payments.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (canLog)
              GestureDetector(
                onTap: () => showLogPaymentSheet(
                  context,
                  tenancy: tenancy,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.greenBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.green.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: AppTheme.green),
                      SizedBox(width: 4),
                      Text(
                        'Log Payment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        if (payments.isEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgPage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 32, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                const Text(
                  'No payments logged yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (canLog) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Log Payment" to record the first payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Your landlord will log payments here as they are received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          ...payments.map((p) => _PaymentRow(
                payment: p,
                tenancy: tenancy,
                canLog: canLog,
                landlordId: tenancy.landlordId ?? '',
              )),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ArrearsBanner extends StatelessWidget {
  final double totalArrears;
  const _ArrearsBanner({required this.totalArrears});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.red.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rent Arrears',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '£${totalArrears.toStringAsFixed(2)} outstanding',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PaymentRow extends ConsumerStatefulWidget {
  final RentPayment payment;
  final Tenancy tenancy;
  final bool canLog;
  final String landlordId;

  const _PaymentRow({
    required this.payment,
    required this.tenancy,
    required this.canLog,
    required this.landlordId,
  });

  @override
  ConsumerState<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends ConsumerState<_PaymentRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final statusColor = _statusColor(p.status);
    final statusBg = _statusBg(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isInArrears
              ? Colors.red.withValues(alpha: 0.2)
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Due date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due ${p.dueDateFormatted}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.paidAtFormatted != null
                              ? 'Paid ${p.paidAtFormatted}'
                              : 'Not yet paid',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Amount summary
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '£${p.amountPaid.toStringAsFixed(0)} / £${p.amountDue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (p.isInArrears)
                        Text(
                          '£${p.arrears.toStringAsFixed(0)} owed',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.statusFormatted.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Detail chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Chip(
                                    label: 'Due',
                                    value:
                                        '£${p.amountDue.toStringAsFixed(2)}'),
                                _Chip(
                                    label: 'Paid',
                                    value:
                                        '£${p.amountPaid.toStringAsFixed(2)}'),
                                if (p.isInArrears)
                                  _Chip(
                                    label: 'Arrears',
                                    value:
                                        '£${p.arrears.toStringAsFixed(2)}',
                                    valueColor: Colors.red,
                                  ),
                              ],
                            ),
                            if (p.notes != null &&
                                p.notes!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                p.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            // Edit button (landlord only, pending/partial/late)
                            if (widget.canLog && !p.isPaid) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      showLogPaymentSheet(
                                    context,
                                    tenancy: widget.tenancy,
                                    existing: p,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.green,
                                    side: const BorderSide(
                                        color: AppTheme.green,
                                        width: 1.0),
                                    minimumSize:
                                        const Size(double.infinity, 38),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(9)),
                                  ),
                                  child: const Text('Update Payment'),
                                ),
                              ),
                            ],
                            // Flag discrepancy (tenant only, non-paid rows, landlordId known)
                            if (!widget.canLog && !p.isPaid && widget.landlordId.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _flagDiscrepancy(
                                      context, p),
                                  icon: const Icon(Icons.flag_outlined,
                                      size: 14),
                                  label: const Text(
                                      'Flag a discrepancy'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Colors.orange.shade700,
                                    side: BorderSide(
                                        color: Colors.orange.shade700,
                                        width: 1.0),
                                    minimumSize:
                                        const Size(double.infinity, 38),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(9)),
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

  Future<void> _flagDiscrepancy(
      BuildContext context, RentPayment p) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Flag a discrepancy',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell your landlord what you believe is incorrect for the payment due ${p.dueDateFormatted}.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 250,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'e.g. I paid £850 on 1 Jan but it shows as unpaid…',
                hintStyle: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Flag',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final note = noteController.text.trim();
    final ok = await ref
        .read(flagRentDiscrepancyProvider.notifier)
        .flag(
          paymentId: p.id,
          tenancyId: widget.tenancy.tenancyId,
          landlordId: widget.landlordId,
          note: note,
          dueDateFormatted: p.dueDateFormatted,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Your landlord has been notified.'
            : 'Failed to send — please try again.'),
        backgroundColor: ok ? AppTheme.darkBg : Colors.red,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.green;
      case 'partial':
        return const Color(0xFFE65100);
      case 'late':
        return Colors.red;
      default:
        return AppTheme.textMuted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.greenBg;
      case 'partial':
        return const Color(0xFFFFF3E0);
      case 'late':
        return Colors.red.withValues(alpha: 0.08);
      default:
        return const Color(0xFFF5F5F5);
    }
  }
}

// ---------------------------------------------------------------------------
// Tenant rent summary — shown at top of ledger for tenants
// ---------------------------------------------------------------------------

class _TenantRentSummary extends StatelessWidget {
  final RentPayment? nextDue;
  final double totalArrears;
  const _TenantRentSummary({
    required this.nextDue,
    required this.totalArrears,
  });

  @override
  Widget build(BuildContext context) {
    final hasArrears = totalArrears > 0;
    final accentColor = hasArrears ? Colors.red : AppTheme.green;
    final accentBg = hasArrears
        ? Colors.red.withValues(alpha: 0.06)
        : AppTheme.greenBg;
    final borderColor = hasArrears
        ? Colors.red.withValues(alpha: 0.25)
        : AppTheme.green.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasArrears
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: 20,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasArrears ? 'You have outstanding rent' : 'Rent up to date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasArrears)
                  Text(
                    '£${totalArrears.toStringAsFixed(2)} outstanding. Contact your landlord if you have questions.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.withValues(alpha: 0.85),
                        height: 1.4),
                  )
                else if (nextDue != null)
                  Text(
                    'Next payment of £${nextDue!.amountDue.toStringAsFixed(0)} due ${nextDue!.dueDateFormatted}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.green.withValues(alpha: 0.9),
                        height: 1.4),
                  )
                else
                  const Text(
                    'No upcoming payments scheduled.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Chip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
