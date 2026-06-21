import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Landlord: request holding deposit ───────────────────────────────────────
void showRequestHoldingDepositSheet(
  BuildContext context, {
  required Tenancy tenancy,
}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RequestDepositSheet(tenancy: tenancy),
  );
}

class _RequestDepositSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _RequestDepositSheet({required this.tenancy});

  @override
  ConsumerState<_RequestDepositSheet> createState() =>
      _RequestDepositSheetState();
}

class _RequestDepositSheetState extends ConsumerState<_RequestDepositSheet> {
  AbodePalette get p => AbodePalette.of(context);
  static const _accent = Color(0xFF3B82F6);

  final _nameCtrl   = TextEditingController();
  final _sortCtrl   = TextEditingController();
  final _accountCtrl = TextEditingController();

  late double _amount;
  late String _reference;

  @override
  void initState() {
    super.initState();
    // 1 week's rent = monthly × 12 ÷ 52 (correct legal formula)
    final monthly = widget.tenancy.monthlyRent ?? 0;
    _amount = double.parse((monthly * 12 / 52).toStringAsFixed(2));

    // Generate reference
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    _reference = 'HD-$code';

    // Pre-fill from profile if available
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) {
      _nameCtrl.text    = profile.bankAccountName ?? '';
      _sortCtrl.text    = profile.bankSortCode ?? '';
      _accountCtrl.text = profile.bankAccountNumber ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _nameCtrl.text.trim().isNotEmpty &&
      _sortCtrl.text.trim().isNotEmpty &&
      _accountCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final saving = ref.watch(holdingDepositProvider).isLoading;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: _accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request Holding Deposit',
                            style: TextStyle(
                                color: p.text, fontSize: 18,
                                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        Text(widget.tenancy.shortAddress,
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
                const SizedBox(height: 20),

                // Amount + reference summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount',
                              style: TextStyle(color: p.muted, fontSize: 11)),
                          Text('£${_amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: p.text, fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                          Text('1 week\'s rent · capped by Tenant Fees Act',
                              style: TextStyle(color: p.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Reference',
                            style: TextStyle(color: p.muted, fontSize: 11)),
                        Text(_reference,
                            style: TextStyle(
                                color: _accent, fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        Text('15 days to pay',
                            style: TextStyle(color: p.muted, fontSize: 11)),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Bank details
                _Label('YOUR BANK DETAILS', p),
                const SizedBox(height: 4),
                Text('The tenant will use these to send the payment.',
                    style: TextStyle(color: p.muted, fontSize: 12)),
                const SizedBox(height: 10),

                _Field(ctrl: _nameCtrl, hint: 'Account name',
                    p: p, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _Field(
                      ctrl: _sortCtrl,
                      hint: 'Sort code (00-00-00)',
                      p: p,
                      type: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      ctrl: _accountCtrl,
                      hint: 'Account number',
                      p: p,
                      type: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Abode doesn\'t process payments. The tenant will transfer directly to your account using the reference above.',
                          style: TextStyle(
                              color: p.muted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: (_canSend && !saving) ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: _canSend ? _accent : p.border,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _canSend ? [BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 16, offset: const Offset(0, 4),
                        )] : null,
                      ),
                      alignment: Alignment.center,
                      child: saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Send deposit request',
                              style: TextStyle(
                                  color: _canSend ? Colors.white : p.muted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final ok = await ref.read(holdingDepositProvider.notifier).request(
      tenancyId:       widget.tenancy.id,
      amount:          _amount,
      reference:       _reference,
      bankAccountName: _nameCtrl.text.trim(),
      sortCode:        _sortCtrl.text.trim(),
      accountNumber:   _accountCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
      showAbodeToast(context, 'Holding deposit request sent');
    }
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final AbodePalette p;
  const _Label(this.text, this.p);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: AbodePalette.of(context).sub,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final AbodePalette p;
  final TextInputType? type;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.ctrl,
    required this.hint,
    required this.p,
    this.type,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: onChanged,
      style: TextStyle(color: pal.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.muted, fontSize: 14),
        filled: true,
        fillColor: pal.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF3B82F6), width: 2)),
      ),
    );
  }
}

// ─── Tenant: holding deposit card ─────────────────────────────────────────────
class HoldingDepositCard extends ConsumerWidget {
  final Tenancy tenancy;
  final String? landlordBankName;
  final String? landlordSortCode;
  final String? landlordAccountNumber;

  const HoldingDepositCard({
    super.key,
    required this.tenancy,
    this.landlordBankName,
    this.landlordSortCode,
    this.landlordAccountNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    const accent = Color(0xFF14B8A6);
    final status = tenancy.holdingDepositStatus;
    final confirmed = status == 'tenant_confirmed';
    final received  = status == 'received';

    final deadline = tenancy.holdingDepositRequestedAt
        ?.add(const Duration(days: 15));
    final daysLeft = deadline != null
        ? deadline.difference(DateTime.now()).inDays
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: received
              ? p.green.withValues(alpha: 0.4)
              : confirmed
                  ? p.amber.withValues(alpha: 0.4)
                  : accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: (received ? p.green : confirmed ? p.amber : accent)
                  .withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(
                received
                    ? Icons.check_circle_outline
                    : confirmed
                        ? Icons.hourglass_top_rounded
                        : Icons.account_balance_outlined,
                color: received ? p.green : confirmed ? p.amber : accent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  received
                      ? 'Holding Deposit Received'
                      : confirmed
                          ? 'Payment Sent — Awaiting Confirmation'
                          : 'Holding Deposit Required',
                  style: TextStyle(
                      color: received
                          ? p.green
                          : confirmed ? p.amber : accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (daysLeft != null && !received)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (daysLeft <= 3 ? p.red : p.amber)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$daysLeft days left',
                    style: TextStyle(
                        color: daysLeft <= 3 ? p.red : p.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount + property
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenancy.shortAddress,
                            style: TextStyle(
                                color: p.text, fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '£${tenancy.holdingDepositAmount?.toStringAsFixed(0) ?? '—'}  ·  Ref: ${tenancy.holdingDepositReference ?? '—'}',
                          style: TextStyle(color: p.sub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ]),

                if (!received && !confirmed && landlordBankName != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 12),

                  // Bank details
                  Text('Pay to',
                      style: TextStyle(
                          color: p.muted, fontSize: 11,
                          fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  const SizedBox(height: 8),
                  _BankDetail(label: 'Account name',
                      value: landlordBankName!, p: p),
                  const SizedBox(height: 4),
                  _BankDetail(label: 'Sort code',
                      value: landlordSortCode ?? '—', p: p, copyable: true),
                  const SizedBox(height: 4),
                  _BankDetail(label: 'Account number',
                      value: landlordAccountNumber ?? '—',
                      p: p, copyable: true),
                  const SizedBox(height: 4),
                  _BankDetail(label: 'Reference',
                      value: tenancy.holdingDepositReference ?? '—',
                      p: p, copyable: true, highlight: true),
                  const SizedBox(height: 16),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => ref
                          .read(holdingDepositProvider.notifier)
                          .tenantConfirm(tenancy.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 10, offset: const Offset(0, 3),
                          )],
                        ),
                        alignment: Alignment.center,
                        child: const Text('I\'ve sent the payment',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],

                if (confirmed && !received) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 13, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Waiting for your landlord to confirm receipt.',
                          style: TextStyle(
                              color: p.muted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],

                if (received) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.green.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: p.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          size: 13, color: p.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your landlord confirmed receipt on ${_fmt(tenancy.holdingDepositReceivedAt)}. The property is now secured.',
                          style: TextStyle(
                              color: p.green, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _BankDetail extends StatelessWidget {
  final String label;
  final String value;
  final AbodePalette p;
  final bool copyable;
  final bool highlight;

  const _BankDetail({
    required this.label,
    required this.value,
    required this.p,
    this.copyable = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style: TextStyle(color: pal.muted, fontSize: 12)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(
                color: highlight ? const Color(0xFF3B82F6) : pal.text,
                fontSize: 12,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.w500)),
      ),
      if (copyable)
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            showAbodeToast(context, '$label copied');
          },
          child: Icon(Icons.copy_rounded, size: 14, color: pal.muted),
        ),
    ]);
  }
}

// ─── Landlord: pending deposit card strip ─────────────────────────────────────
class LandlordDepositStrip extends ConsumerWidget {
  final Tenancy tenancy;
  const LandlordDepositStrip({super.key, required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final status = tenancy.holdingDepositStatus;
    final confirmed = status == 'tenant_confirmed';
    final received  = status == 'received';

    if (received) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? p.green.withValues(alpha: 0.3)
              : p.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Icon(
          confirmed ? Icons.payments_outlined : Icons.hourglass_top_rounded,
          size: 16,
          color: confirmed ? p.green : p.amber,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            confirmed
                ? 'Tenant says they\'ve sent £${tenancy.holdingDepositAmount?.toStringAsFixed(0) ?? '—'} — tap to confirm receipt'
                : 'Holding deposit requested · Ref: ${tenancy.holdingDepositReference ?? '—'}',
            style: TextStyle(
                color: confirmed ? p.text : p.sub, fontSize: 12),
          ),
        ),
        if (confirmed)
          GestureDetector(
            onTap: () => ref
                .read(holdingDepositProvider.notifier)
                .markReceived(tenancy.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: p.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: p.green.withValues(alpha: 0.3)),
              ),
              child: Text('Mark received',
                  style: TextStyle(
                      color: p.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}
