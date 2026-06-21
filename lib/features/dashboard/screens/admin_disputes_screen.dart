import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_providers.dart';
import '../../../core/theme/dialogs.dart';
import 'admin_theme.dart';

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(adminOpenDisputesProvider);

    return Theme(
      data: AP.appBarTheme(context),
      child: Scaffold(
        backgroundColor: AP.bg,
        appBar: AppBar(
          title: const Text('Disputes'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AP.el)),
        ),
        body: AdminConstraint(child: RefreshIndicator(
          color: AP.accent,
          backgroundColor: AP.card,
          onRefresh: () async => ref.invalidate(adminOpenDisputesProvider),
          child: disputesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AP.accent, strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text('Error: $e',
                style: const TextStyle(color: AP.sub))),
            data: (disputes) {
              if (disputes.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AP.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_outline_rounded,
                        color: AP.green, size: 32)),
                    const SizedBox(height: 16),
                    const Text('All clear',
                      style: TextStyle(color: AP.text, fontSize: 20,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('No open disputes.',
                      style: TextStyle(color: AP.sub, fontSize: 14)),
                  ]),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: disputes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DisputeCard(data: disputes[i]),
              );
            },
          ),
        )),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DisputeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final contractor = data['contractor'] as Map<String, dynamic>? ?? {};
    final tenancy    = data['tenancy']   as Map<String, dynamic>? ?? {};
    final landlord   = tenancy['landlord'] as Map<String, dynamic>? ?? {};
    final address    = [
      tenancy['address_line_1'] as String?,
      tenancy['postcode'] as String?,
    ].whereType<String>().join(', ');
    final hasResponse = (data['contractor_dispute_response'] as String?)?.isNotEmpty == true;
    final raisedAt    = data['dispute_raised_at'] as String?;
    final daysAgo     = raisedAt != null
        ? DateTime.now().difference(DateTime.tryParse(raisedAt) ?? DateTime.now()).inDays
        : null;
    final quoteAmt = double.tryParse(data['quote_amount']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () => showAdaptiveSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DisputeResolveSheet(data: data)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AP.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AP.red.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(data['title'] as String? ?? 'Dispute',
                style: const TextStyle(
                  color: AP.text, fontSize: 15, fontWeight: FontWeight.w700))),
            if (daysAgo != null)
              Text(daysAgo == 0 ? 'Today' : '${daysAgo}d ago',
                style: const TextStyle(color: AP.muted, fontSize: 11)),
          ]),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(address, style: const TextStyle(color: AP.sub, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            _MiniChip(
              icon: Icons.engineering_outlined,
              label: contractor['full_name'] as String? ?? 'Unknown'),
            const SizedBox(width: 8),
            _MiniChip(
              icon: Icons.person_outline,
              label: landlord['full_name'] as String? ?? 'Unknown'),
          ]),
          if (data['dispute_reason'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AP.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(data['dispute_reason'] as String,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AP.sub, fontSize: 12, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Badge(
              label: hasResponse ? 'Responded' : 'Awaiting response',
              color: hasResponse ? AP.green : AP.amber),
            Row(children: [
              Text('£${quoteAmt.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AP.text, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              const Text('Tap to resolve',
                style: TextStyle(
                  color: AP.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_rounded,
                color: AP.accent, size: 13),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _DisputeResolveSheet extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _DisputeResolveSheet({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolveState = ref.watch(adminResolveDisputeProvider);
    final contractor   = data['contractor'] as Map<String, dynamic>? ?? {};
    final tenancy      = data['tenancy']   as Map<String, dynamic>? ?? {};
    final landlord     = tenancy['landlord'] as Map<String, dynamic>? ?? {};
    final hasResponse  = (data['contractor_dispute_response'] as String?)?.isNotEmpty == true;
    final quoteAmt     = double.tryParse(data['quote_amount']?.toString() ?? '0') ?? 0;
    final payout       = double.tryParse(data['contractor_payout']?.toString() ?? '0') ?? quoteAmt;

    return Container(
      decoration: const BoxDecoration(
        color: AP.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.93,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AP.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.gavel_rounded, color: AP.red, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['title'] as String? ?? 'Dispute',
                    style: const TextStyle(
                      color: AP.text, fontSize: 17, fontWeight: FontWeight.w800)),
                  const Text('Admin override — final decision',
                    style: TextStyle(color: AP.amber, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ])),
            ]),
            const SizedBox(height: 20),

            _InfoRow(label: 'Contractor', value: contractor['full_name'] as String? ?? '—'),
            _InfoRow(label: 'Landlord',   value: landlord['full_name']   as String? ?? '—'),
            _InfoRow(label: 'Job value',  value: '£${quoteAmt.toStringAsFixed(2)}'),
            _InfoRow(label: 'Contractor payout', value: '£${payout.toStringAsFixed(2)}'),

            const SizedBox(height: 16),
            _SectionLabel('DISPUTE REASON'),
            const SizedBox(height: 8),
            _TextBlock(data['dispute_reason'] as String? ?? '(none provided)'),

            if (hasResponse) ...[
              const SizedBox(height: 14),
              _SectionLabel('CONTRACTOR RESPONSE'),
              const SizedBox(height: 8),
              _TextBlock(data['contractor_dispute_response'] as String),
            ] else ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AP.amber.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AP.amber.withValues(alpha: 0.18)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: AP.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Contractor has not responded yet.',
                    style: TextStyle(color: AP.amber, fontSize: 12))),
                ]),
              ),
            ],

            const SizedBox(height: 28),
            _ResolveButton(
              label: 'Favour contractor · release £${payout.toStringAsFixed(2)}',
              icon: Icons.check_circle_outline_rounded,
              color: AP.green,
              loading: resolveState.isLoading,
              onTap: () => _resolve(context, ref, 'favour_contractor'),
            ),
            const SizedBox(height: 10),
            _ResolveButton(
              label: 'Favour landlord · withhold payment',
              icon: Icons.block_outlined,
              color: AP.red,
              loading: resolveState.isLoading,
              outlined: true,
              onTap: () => _confirmWithhold(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, String resolution) async {
    final ok = await ref.read(adminResolveDisputeProvider.notifier)
        .resolve(data['id'] as String, resolution);
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmWithhold(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Withhold payment?',
      body: "This permanently withholds the contractor's payment.",
      confirmLabel: 'Withhold',
      isDestructive: true,
      icon: Icons.money_off_outlined,
    );
    if (confirmed == true && context.mounted) {
      await _resolve(context, ref, 'favour_landlord');
    }
  }
}

class _ResolveButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final bool outlined;
  final VoidCallback onTap;

  const _ResolveButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (loading)
        SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: outlined ? color : Colors.white))
      else
        Icon(icon, size: 17,
          color: outlined ? color : Colors.white),
      const SizedBox(width: 8),
      Text(label,
        style: TextStyle(
          color: outlined ? color : Colors.white,
          fontSize: 14, fontWeight: FontWeight.w700)),
    ]);

    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        ),
        child: child);
    }
    return FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14))),
      child: child);
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: AP.muted),
    const SizedBox(width: 4),
    Flexible(child: Text(label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AP.sub, fontSize: 12))),
  ]);
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
    style: const TextStyle(
      color: AP.muted, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 140,
        child: Text(label,
          style: const TextStyle(color: AP.sub, fontSize: 13))),
      Expanded(child: Text(value,
        style: const TextStyle(
          color: AP.text, fontSize: 13, fontWeight: FontWeight.w600))),
    ]));
}

class _TextBlock extends StatelessWidget {
  final String text;
  const _TextBlock(this.text);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AP.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AP.el),
    ),
    child: Text(text,
      style: const TextStyle(color: AP.text, fontSize: 13, height: 1.5)));
}
