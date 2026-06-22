import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_sheet.dart';
import '../../../core/widgets/abode_toast.dart';
import '../models/rent_payment.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';

const _accent = Color(0xFF14B8A6);

// ─── Entry point ──────────────────────────────────────────────────────────────

void showTenantRentSheet(
  BuildContext context, {
  required Tenancy tenancy,
  required DateTime dueDate,
}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TenantRentSheet(tenancy: tenancy, dueDate: dueDate),
  );
}

// ─── Sheet ─────────────────────────────────────────────────────────────────────

class _TenantRentSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final DateTime dueDate;
  const _TenantRentSheet({required this.tenancy, required this.dueDate});

  @override
  ConsumerState<_TenantRentSheet> createState() => _TenantRentSheetState();
}

class _TenantRentSheetState extends ConsumerState<_TenantRentSheet> {
  bool _marking = false;

  Tenancy get t => widget.tenancy;

  RentPayment? _findCurrentPayment(List<RentPayment> payments) {
    final due = widget.dueDate;
    for (final p in payments) {
      if (p.dueDate.year == due.year && p.dueDate.month == due.month) {
        return p;
      }
    }
    return null;
  }

  Future<void> _markPaid(RentPayment payment) async {
    setState(() => _marking = true);
    final ok = await ref.read(markRentPaidProvider.notifier).mark(
      paymentId: payment.id,
      tenancyId: t.tenancyId,
      amount: payment.amountDue,
    );
    if (mounted) {
      setState(() => _marking = false);
      if (ok) {
        showAbodeToast(context, 'Payment recorded — your landlord will confirm receipt');
        ref.invalidate(rentPaymentsProvider(t.tenancyId));
      } else {
        showAbodeToast(context, 'Failed to record payment — try again', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final paymentsAsync = ref.watch(rentPaymentsProvider(t.tenancyId));
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: p.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: _accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rent Payment',
                    style: TextStyle(color: p.text, fontSize: 18,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text(t.shortAddress,
                    style: TextStyle(color: p.sub, fontSize: 12)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: p.card, shape: BoxShape.circle,
                    border: Border.all(color: p.border)),
                  child: Icon(Icons.close_rounded, size: 16, color: p.sub),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
              error: (_, __) => Center(child: Text('Could not load', style: TextStyle(color: p.sub))),
              data: (payments) {
                final current = _findCurrentPayment(payments);
                return ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    // ── Current period ──────────────────────────────────────
                    _CurrentPeriodCard(
                      tenancy: t,
                      dueDate: widget.dueDate,
                      payment: current,
                      fmt: fmt,
                      marking: _marking,
                      onMarkPaid: current != null && !current.isPaid ? () => _markPaid(current) : null,
                      p: p,
                    ),
                    const SizedBox(height: 16),

                    // ── Bank transfer details ───────────────────────────────
                    _BankDetailsCard(tenancy: t, dueDate: widget.dueDate, p: p),
                    const SizedBox(height: 24),

                    // ── History ─────────────────────────────────────────────
                    if (payments.isNotEmpty) ...[
                      Text('PAYMENT HISTORY',
                          style: TextStyle(color: p.muted, fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border, width: 0.5),
                        ),
                        child: Column(
                          children: payments.take(6).toList().asMap().entries.map((e) {
                            final idx = e.key;
                            final payment = e.value;
                            final isLast = idx == (payments.take(6).length - 1);
                            return _HistoryRow(
                              payment: payment,
                              fmt: fmt,
                              isLast: isLast,
                              p: p,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Current period card ───────────────────────────────────────────────────────

class _CurrentPeriodCard extends StatelessWidget {
  final Tenancy tenancy;
  final DateTime dueDate;
  final RentPayment? payment;
  final NumberFormat fmt;
  final bool marking;
  final VoidCallback? onMarkPaid;
  final AbodePalette p;

  const _CurrentPeriodCard({
    required this.tenancy,
    required this.dueDate,
    required this.payment,
    required this.fmt,
    required this.marking,
    required this.onMarkPaid,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    final periodLabel = '${months[dueDate.month - 1]} ${dueDate.year}';
    final rent = tenancy.monthlyRent ?? 0;
    final isPaid = payment?.isPaid ?? false;
    final statusColor = isPaid ? p.green : _accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(periodLabel,
                style: TextStyle(color: p.sub, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(fmt.format(rent),
                style: TextStyle(color: p.text, fontSize: 28,
                    fontWeight: FontWeight.w800, letterSpacing: -1)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPaid ? 'Paid' : 'Due ${dueDate.day}/${dueDate.month}',
              style: TextStyle(color: statusColor, fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ]),

        if (payment == null) ...[
          const SizedBox(height: 12),
          Text(
            'No payment scheduled for this period. Transfer manually and your landlord will log it.',
            style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
          ),
        ] else if (isPaid) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.check_circle_rounded, size: 14, color: p.green),
            const SizedBox(width: 6),
            Text('Payment recorded — awaiting landlord confirmation',
                style: TextStyle(color: p.green, fontSize: 12)),
          ]),
        ] else ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: marking ? null : onMarkPaid,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: onMarkPaid != null ? _accent : p.border,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: onMarkPaid != null
                      ? [BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                alignment: Alignment.center,
                child: marking
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 7),
                        Text("I've transferred — mark as paid",
                            style: TextStyle(color: Colors.white,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Bank details card ─────────────────────────────────────────────────────────

class _BankDetailsCard extends StatelessWidget {
  final Tenancy tenancy;
  final DateTime dueDate;
  final AbodePalette p;
  const _BankDetailsCard({required this.tenancy, required this.dueDate, required this.p});

  String _fmtSortCode(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 6) {
      return '${digits.substring(0,2)}-${digits.substring(2,4)}-${digits.substring(4,6)}';
    }
    return raw;
  }

  String _suggestedRef() {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN',
                    'JUL','AUG','SEP','OCT','NOV','DEC'];
    return 'RENT ${tenancy.postcode} ${months[dueDate.month - 1]} ${dueDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = tenancy.landlord?.bankAccountName != null ||
        tenancy.landlord?.bankAccountNumber != null;

    if (!hasDetails) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: p.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(
            "Your landlord hasn't added bank details yet. Contact them directly to arrange payment.",
            style: TextStyle(color: p.sub, fontSize: 12, height: 1.4),
          )),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BANK TRANSFER DETAILS',
            style: TextStyle(color: p.muted, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        const SizedBox(height: 12),

        if (tenancy.landlord?.bankAccountName != null)
          _DetailRow(label: 'Account name',
              value: tenancy.landlord!.bankAccountName!, p: p),
        if (tenancy.landlord?.bankSortCode != null)
          _DetailRow(label: 'Sort code',
              value: _fmtSortCode(tenancy.landlord!.bankSortCode), p: p),
        if (tenancy.landlord?.bankAccountNumber != null)
          _DetailRow(label: 'Account number',
              value: tenancy.landlord!.bankAccountNumber!, p: p),

        const SizedBox(height: 8),
        Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
        const SizedBox(height: 10),

        // Reference
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SUGGESTED REFERENCE',
                style: TextStyle(color: p.muted, fontSize: 10,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(_suggestedRef(),
                style: TextStyle(color: p.text, fontSize: 13,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ])),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _suggestedRef()));
              showAbodeToast(context, 'Reference copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, size: 12, color: p.sub),
                const SizedBox(width: 4),
                Text('Copy', style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final AbodePalette p;
  const _DetailRow({required this.label, required this.value, required this.p});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 120,
        child: Text(label, style: TextStyle(color: p.muted, fontSize: 12))),
      Expanded(child: Row(children: [
        Text(value, style: TextStyle(color: p.text, fontSize: 13,
            fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            showAbodeToast(context, '$label copied');
          },
          child: Icon(Icons.copy_rounded, size: 12, color: p.muted),
        ),
      ])),
    ]),
  );
}

// ─── History row ───────────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final RentPayment payment;
  final NumberFormat fmt;
  final bool isLast;
  final AbodePalette p;
  const _HistoryRow({required this.payment, required this.fmt,
      required this.isLast, required this.p});

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = '${months[payment.dueDate.month - 1]} ${payment.dueDate.year}';
    final isPaid = payment.isPaid;
    final isOverdue = payment.isOverdue;
    final statusColor = isPaid ? p.green : isOverdue ? p.red : p.amber;
    final statusLabel = isPaid ? 'Paid' : isOverdue ? 'Overdue' : 'Due';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
          if (payment.paidAt != null)
            Text(
              'Paid ${payment.paidAt!.day}/${payment.paidAt!.month}/${payment.paidAt!.year}',
              style: TextStyle(color: p.muted, fontSize: 11),
            ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(payment.amountPaid > 0 ? payment.amountPaid : payment.amountDue),
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
