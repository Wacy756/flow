import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../models/rent_payment.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void showRentLedgerSheet(BuildContext context, {required Tenancy tenancy}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RentLedgerSheet(tenancy: tenancy),
  );
}

// ─── Landlord ledger sheet ────────────────────────────────────────────────────

class _RentLedgerSheet extends ConsumerWidget {
  final Tenancy tenancy;
  const _RentLedgerSheet({required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final paymentsAsync = ref.watch(rentPaymentsProvider(tenancy.tenancyId));
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_outlined,
                      color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rent Ledger',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          )),
                      Text(tenancy.shortAddress,
                          style: TextStyle(color: p.sub, fontSize: 12)),
                    ],
                  ),
                ),
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
            const SizedBox(height: 20),

            Expanded(
              child: paymentsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                      color: const Color(0xFF3B82F6)),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: TextStyle(color: p.sub)),
                ),
                data: (payments) {
                  if (payments.isEmpty) {
                    return _EmptyLedger(tenancy: tenancy);
                  }

                  // Summary stats
                  final totalDue = payments.fold(
                      0.0, (s, p) => s + p.amountDue);
                  final totalPaid = payments.fold(
                      0.0, (s, p) => s + p.amountPaid);
                  final arrears = payments
                      .where((p) => p.isOverdue)
                      .fold(0.0, (s, p) => s + p.balance);

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      // Direct Debit mandate card
                      _DdMandateCard(tenancy: tenancy, payments: payments, fmt: fmt),
                      const SizedBox(height: 16),

                      // Summary strip
                      _SummaryStrip(
                        totalPaid: totalPaid,
                        arrears: arrears,
                        fmt: fmt,
                      ),
                      const SizedBox(height: 24),

                      // Payments list
                      Text('PAYMENT HISTORY',
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          )),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < payments.length; i++)
                              _PaymentRow(
                                payment: payments[i],
                                tenancyId: tenancy.tenancyId,
                                fmt: fmt,
                                isLast: i == payments.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty ledger — no schedule yet ──────────────────────────────────────────

class _EmptyLedger extends ConsumerWidget {
  final Tenancy tenancy;
  const _EmptyLedger({required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final genState = ref.watch(generateRentScheduleProvider);
    final isLoading = genState.isLoading;

    ref.listen(generateRentScheduleProvider, (prev, next) {
      if (prev?.isLoading == true && next.hasValue) {
        showAbodeToast(context, 'Rent schedule generated');
      }
    });

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.calendar_month_outlined,
                size: 32, color: p.muted),
          ),
          const SizedBox(height: 20),
          Text('No rent schedule yet',
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text(
            tenancy.monthlyRent != null && tenancy.startDate != null
                ? 'Generate a 12-month schedule based on £${tenancy.monthlyRent!.toStringAsFixed(0)}/mo starting ${DateFormat('dd/MM/yyyy').format(tenancy.startDate!)}.'
                : 'Rent amount or start date not set on this tenancy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.sub, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (tenancy.monthlyRent != null && tenancy.startDate != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(isLoading
                    ? 'Generating…'
                    : 'Generate Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        await ref
                            .read(generateRentScheduleProvider.notifier)
                            .generate(
                              tenancyId: tenancy.tenancyId,
                              startDate: tenancy.startDate!,
                              monthlyRent: tenancy.monthlyRent!,
                              endDate: tenancy.endDate,
                            );
                      },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Direct Debit mandate card ────────────────────────────────────────────────

class _DdMandateCard extends ConsumerWidget {
  final Tenancy tenancy;
  final List<RentPayment> payments;
  final NumberFormat fmt;

  const _DdMandateCard({
    required this.tenancy,
    required this.payments,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final mandateStatus = tenancy.gcMandateStatus;
    final isActive = mandateStatus == 'active';
    final isPending = mandateStatus == 'pending_customer_approval' || mandateStatus == 'submitted';

    final setupState = ref.watch(setupDirectDebitProvider);
    final collectState = ref.watch(collectDirectDebitProvider);
    final isSettingUp = setupState.isLoading;
    final isCollecting = collectState.isLoading;
    final gcEnabled = ref.watch(platformSettingsProvider).valueOrNull?.gcEnabled ?? false;

    // Next unpaid, non-collecting payment
    final nextDue = payments
        .where((pay) => !pay.isPaid && !pay.isCollecting)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final next = nextDue.isEmpty ? null : nextDue.first;

    // Already collecting
    final collecting = payments.where((pay) => pay.isCollecting).toList();

    final Color accentColor = isActive
        ? const Color(0xFF22C55E)
        : isPending
            ? const Color(0xFFF59E0B)
            : const Color(0xFF64748B);

    final IconData accentIcon = isActive
        ? Icons.account_balance_rounded
        : isPending
            ? Icons.hourglass_empty_rounded
            : Icons.account_balance_outlined;

    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(accentIcon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Direct Debit',
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                isActive ? 'Mandate active'
                    : isPending ? 'Awaiting tenant authorisation'
                    : 'Not set up',
                style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Active' : isPending ? 'Pending' : 'Setup',
                style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          // Collecting row
          if (collecting.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Collecting ${fmt.format(collecting.fold(0.0, (s, pay) => s + pay.amountDue))} via Direct Debit…',
                  style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],

          // Action button
          if (!isActive && !isPending && gcEnabled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                icon: isSettingUp
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_rounded, size: 16),
                label: Text(isSettingUp ? 'Setting up…' : 'Set up Direct Debit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: isSettingUp ? null : () async {
                  final url = await ref
                      .read(setupDirectDebitProvider.notifier)
                      .setup(tenancy.tenancyId);
                  if (url != null) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ] else if (!isActive && !isPending && !gcEnabled) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Direct Debit collection coming soon — mark payments manually for now.',
                style: TextStyle(color: const Color(0xFF64748B), fontSize: 11, height: 1.4),
              )),
            ]),
          ] else if (isActive && next != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                icon: isCollecting
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: Text(isCollecting ? 'Collecting…' : 'Collect ${fmt.format(next.amountDue)} via DD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: isCollecting ? null : () async {
                  final confirmed = await showAbodeConfirmDialog(
                    context,
                    title: 'Collect via Direct Debit',
                    body: 'This will collect ${fmt.format(next.amountDue)} from the tenant\'s bank account now. This cannot be undone.',
                    confirmLabel: 'Collect',
                    icon: Icons.account_balance_outlined,
                  );
                  if (confirmed != true) return;
                  await ref.read(collectDirectDebitProvider.notifier).collect(
                    rentPaymentId: next.id,
                    tenancyId: tenancy.tenancyId,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final double totalPaid;
  final double arrears;
  final NumberFormat fmt;

  const _SummaryStrip({
    required this.totalPaid,
    required this.arrears,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Row(children: [
      Expanded(
        child: _StatBox(
          label: 'Total Received',
          value: fmt.format(totalPaid),
          color: const Color(0xFF22C55E),
          icon: Icons.check_circle_outline,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatBox(
          label: 'Arrears',
          value: arrears > 0 ? fmt.format(arrears) : '£0',
          color: arrears > 0
              ? const Color(0xFFEF4444)
              : const Color(0xFF22C55E),
          icon: arrears > 0
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
        ),
      ),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
              color: p.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              color: p.sub,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }
}

// ─── Individual payment row ───────────────────────────────────────────────────

class _PaymentRow extends ConsumerWidget {
  final RentPayment payment;
  final String tenancyId;
  final NumberFormat fmt;
  final bool isLast;

  const _PaymentRow({
    required this.payment,
    required this.tenancyId,
    required this.fmt,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final markState = ref.watch(markRentPaidProvider);
    final isMarking = markState.isLoading;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (payment.isPaid) {
      statusColor = const Color(0xFF22C55E);
      statusLabel = 'Paid';
      statusIcon = Icons.check_circle_rounded;
    } else if (payment.isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Overdue';
      statusIcon = Icons.error_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Due';
      statusIcon = Icons.schedule_rounded;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            // Month + amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment.monthLabel,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    'Due ${DateFormat('dd/MM/yyyy').format(payment.dueDate)}',
                    style: TextStyle(color: p.sub, fontSize: 11),
                  ),
                  if (payment.isPaid && payment.paidAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Paid ${DateFormat('dd/MM/yyyy').format(payment.paidAt!)}',
                      style: TextStyle(
                          color: const Color(0xFF22C55E), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            // Amount
            Text(fmt.format(payment.amountDue),
                style: TextStyle(
                  color: p.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(width: 12),

            // Status / action
            if (payment.isPaid)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              )
            else
              GestureDetector(
                onTap: isMarking
                    ? null
                    : () async {
                        await ref
                            .read(markRentPaidProvider.notifier)
                            .mark(
                              paymentId: payment.id,
                              tenancyId: tenancyId,
                              amount: payment.amountDue,
                            );
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: isMarking
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3B82F6)))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(statusIcon,
                              size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          const Text('· Mark paid',
                              style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                ),
              ),
          ]),
        ),
        if (payment.hasDiscrepancy) _DiscrepancyBar(payment: payment, tenancyId: tenancyId, p: p),
        if (!isLast)
          Divider(
              height: 1,
              indent: 16,
              color: p.border,
              thickness: 0.5),
      ],
    );
  }
}

// ─── Discrepancy flag + resolve bar (landlord view) ──────────────────────────
class _DiscrepancyBar extends ConsumerWidget {
  final RentPayment payment;
  final String tenancyId;
  final AbodePalette p;
  const _DiscrepancyBar({required this.payment, required this.tenancyId, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolveState = ref.watch(resolveRentDiscrepancyProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25))),
      child: Row(children: [
        Icon(Icons.flag_rounded, size: 14, color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          payment.discrepancyNote ?? 'Tenant flagged a discrepancy',
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: resolveState.isLoading ? null : () => _showResolveDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border)),
            child: resolveState.isLoading
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Resolve', style: TextStyle(color: p.text, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Future<void> _showResolveDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final pd = AbodePalette.of(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: pd.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pd.border),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Resolve Discrepancy',
                  style: TextStyle(
                    color: pd.text, fontSize: 17,
                    fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  style: TextStyle(color: pd.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Confirmed payment received, bank delay',
                    hintStyle: TextStyle(color: pd.sub, fontSize: 13),
                    filled: true,
                    fillColor: pd.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: pd.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: pd.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: pd.green)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: pd.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      child: Text('Cancel',
                        style: TextStyle(
                          color: pd.sub, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: pd.green,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      child: const Text('Mark resolved',
                        style: TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await ref.read(resolveRentDiscrepancyProvider.notifier).resolve(
        paymentId: payment.id,
        tenancyId: tenancyId,
        resolutionNote: ctrl.text.trim(),
      );
    }
  }
}

// ─── Tenant-facing rent card (shown on overview tab) ─────────────────────────

class TenantRentCard extends ConsumerWidget {
  final Tenancy tenancy;
  const TenantRentCard({super.key, required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final paymentsAsync = ref.watch(rentPaymentsProvider(tenancy.tenancyId));
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return paymentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (payments) {
        if (payments.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        // Next unpaid payment
        final upcoming = payments
            .where((p) => !p.isPaid)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

        // Most recent payment history (last 3 paid)
        final history = payments.where((p) => p.isPaid).toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

        final next = upcoming.isEmpty ? null : upcoming.first;
        final daysLeft = next == null
            ? 0
            : next.dueDate.difference(now).inDays;

        final Color urgencyColor = next == null
            ? const Color(0xFF22C55E)
            : next.isOverdue
                ? const Color(0xFFEF4444)
                : daysLeft <= 3
                    ? const Color(0xFFEF4444)
                    : daysLeft <= 7
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF14B8A6);

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: urgencyColor.withValues(alpha: 0.25), width: 1),
            boxShadow: p.cardShadow,
          ),
          child: Column(children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.payments_outlined,
                      color: urgencyColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? 'All payments up to date'
                            : next.isOverdue
                                ? 'Payment overdue'
                                : 'Next rent payment',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (next != null)
                        Text(
                          next.isOverdue
                              ? 'Was due ${DateFormat('dd/MM/yyyy').format(next.dueDate)}'
                              : daysLeft == 0
                                  ? 'Due today'
                                  : daysLeft == 1
                                      ? 'Due tomorrow'
                                      : 'Due in $daysLeft days · ${DateFormat('dd/MM/yyyy').format(next.dueDate)}',
                          style: TextStyle(
                              color: urgencyColor, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (next != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fmt.format(next.amountDue),
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ]),
            ),

            // Direct Debit status strip
            _TenantDdStrip(tenancy: tenancy, p: p),

            // Payment history strip
            if (history.isNotEmpty) ...[
              Divider(height: 1, color: p.border, thickness: 0.5),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RECENT PAYMENTS',
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        )),
                    const SizedBox(height: 10),
                    for (final payment in history.take(3)) ...[
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(payment.monthLabel,
                              style: TextStyle(
                                  color: p.sub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(fmt.format(payment.amountDue),
                            style: TextStyle(
                                color: p.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: Color(0xFF22C55E)),
                      ]),
                      if (payment != history.take(3).last)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}

// ─── Tenant DD status strip ───────────────────────────────────────────────────
class _TenantDdStrip extends StatelessWidget {
  final Tenancy tenancy;
  final AbodePalette p;
  const _TenantDdStrip({required this.tenancy, required this.p});

  @override
  Widget build(BuildContext context) {
    final status = tenancy.gcMandateStatus;
    final isActive  = status == 'active';
    final isPending = status == 'pending_customer_approval' ||
                      status == 'submitted';

    if (status == null && tenancy.gcMandateId == null) {
      // No mandate — subtle grey note; landlord must initiate it
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          Icon(Icons.account_balance_outlined, size: 13, color: p.muted),
          const SizedBox(width: 6),
          Text('No direct debit set up',
              style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
      );
    }

    final color = isActive
        ? const Color(0xFF22C55E)
        : isPending
            ? const Color(0xFFF59E0B)
            : const Color(0xFF64748B);

    final label = isActive
        ? 'Direct Debit active'
        : isPending
            ? 'Direct Debit pending — check your email to authorise'
            : 'Direct Debit: ${status ?? 'unknown'}';

    final icon = isActive
        ? Icons.check_circle_rounded
        : isPending
            ? Icons.hourglass_top_rounded
            : Icons.warning_amber_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
