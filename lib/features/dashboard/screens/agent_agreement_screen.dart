import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../providers/agent_providers.dart';

class AgentAgreementScreen extends ConsumerWidget {
  const AgentAgreementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final agreementsAsync = ref.watch(agentAgreementsProvider);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Text('Management Agreements',
          style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: p.border)),
      ),
      body: RefreshIndicator(
        color: p.blue,
        backgroundColor: p.card,
        onRefresh: () async => ref.invalidate(agentAgreementsProvider),
        child: agreementsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              color: p.blue, strokeWidth: 2)),
          error: (e, _) => Center(
            child: Text('Error: $e',
              style: TextStyle(color: p.red, fontSize: 14))),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined,
                      color: p.muted, size: 48),
                    const SizedBox(height: 16),
                    Text('No agreements',
                      style: TextStyle(
                        color: p.text, fontSize: 18,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Management agreements will appear here.',
                      style: TextStyle(
                        color: p.muted, fontSize: 13)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                _AgreementCard(data: rows[i], palette: p),
            );
          },
        ),
      ),
    );
  }
}

class _AgreementCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  final AbodePalette palette;
  const _AgreementCard({required this.data, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final tenancy = data['tenancy'] as Map<String, dynamic>? ?? {};
    final address = '${tenancy['address_line_1'] ?? 'Unknown property'}'
        '${tenancy['postcode'] != null ? ', ${tenancy['postcode']}' : ''}';
    final status   = data['status'] as String? ?? 'draft';
    final feePct   = data['management_fee_pct']?.toString() ?? '10';
    final signedAt = data['signed_at'] as String?;
    final createdAt = data['created_at'] as String?;
    final statusColor = _statusColor(status, p);
    final terms = data['terms_text'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showDetail(context, ref, p, status, terms, address),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.handshake_outlined,
              color: statusColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('$feePct% management fee',
                  style: TextStyle(color: p.sub, fontSize: 12)),
                if (signedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Signed ${_fmt(DateTime.tryParse(signedAt))}',
                    style: TextStyle(color: p.green, fontSize: 11)),
                ] else if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Created ${_fmt(DateTime.tryParse(createdAt))}',
                    style: TextStyle(color: p.muted, fontSize: 11)),
                ],
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(status),
                style: TextStyle(
                  color: statusColor, fontSize: 10,
                  fontWeight: FontWeight.w700))),
            const SizedBox(height: 6),
            Icon(Icons.chevron_right_rounded,
              color: p.muted, size: 18),
          ]),
        ]),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    AbodePalette p,
    String status,
    String terms,
    String address,
  ) {
    final agreementId = data['id'] as String?;
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, ctrl) => Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(address,
                style: TextStyle(
                  color: p.text, fontSize: 15,
                  fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(status, p).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(status),
                style: TextStyle(
                  color: _statusColor(status, p),
                  fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  if (terms.isNotEmpty) ...[
                    Text('Terms',
                      style: TextStyle(
                        color: p.sub, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border)),
                      child: Text(terms,
                        style: TextStyle(
                          color: p.text, fontSize: 13,
                          height: 1.5))),
                    const SizedBox(height: 20),
                  ],

                  // Action button for non-signed agreements
                  if (status == 'draft' ||
                      status == 'pending_signature') ...[
                    _SignButton(
                      agreementId: agreementId,
                      palette: p,
                      currentStatus: status,
                      onDone: () {
                        ref.invalidate(agentAgreementsProvider);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s, AbodePalette p) => switch (s) {
    'signed'             => p.green,
    'pending_signature'  => p.amber,
    'void'               => p.red,
    _                    => p.muted,
  };

  String _statusLabel(String s) => switch (s) {
    'draft'              => 'Draft',
    'pending_signature'  => 'Awaiting Signature',
    'signed'             => 'Signed',
    'void'               => 'Void',
    _                    => s,
  };

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('d MMM y').format(d);
  }
}

class _SignButton extends ConsumerStatefulWidget {
  final String? agreementId;
  final AbodePalette palette;
  final String currentStatus;
  final VoidCallback onDone;
  const _SignButton({
    required this.agreementId,
    required this.palette,
    required this.currentStatus,
    required this.onDone,
  });

  @override
  ConsumerState<_SignButton> createState() => _SignButtonState();
}

class _SignButtonState extends ConsumerState<_SignButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    return FilledButton.icon(
      onPressed: _loading ? null : _confirm,
      icon: _loading
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.draw_outlined, size: 18, color: Colors.white),
      label: Text(
        _loading ? 'Updating...' : 'Mark as Signed',
        style: const TextStyle(
          color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: p.green,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14))),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Mark as signed?',
      body: 'This confirms both parties have signed the agreement.',
      confirmLabel: 'Confirm',
      icon: Icons.draw_outlined,
    );

    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);

    try {
      if (widget.agreementId != null) {
        await supabase.from('management_agreements').update({
          'status': 'signed',
          'signed_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.agreementId!);
      }
      if (mounted) widget.onDone();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
