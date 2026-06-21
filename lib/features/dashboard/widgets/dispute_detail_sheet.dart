import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../models/incident.dart';
import '../providers/contractor_providers.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

void showDisputeDetailSheet(
  BuildContext context, {
  required Incident incident,
  required String role,
}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DisputeDetailSheet(incident: incident, role: role),
  );
}

class _DisputeDetailSheet extends ConsumerStatefulWidget {
  final Incident incident;
  final String role;
  const _DisputeDetailSheet({required this.incident, required this.role});
  @override
  ConsumerState<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends ConsumerState<_DisputeDetailSheet> {
  final _responseCtrl = TextEditingController();
  bool _showResponseForm = false;

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p        = AbodePalette.of(context);
    final incident = widget.incident;
    final submitState  = ref.watch(submitDisputeResponseProvider);
    final resolveState = ref.watch(resolveDisputeProvider);

    final hasResponse = incident.contractorDisputeResponse != null &&
        incident.contractorDisputeResponse!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [

            // Handle
            const SizedBox(height: 12),

            // ── Status banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.red.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(Icons.gavel_outlined, color: p.red, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Work disputed',
                      style: TextStyle(
                        color: p.red, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (incident.disputeRaisedAt != null)
                      Text(
                        'Raised ${_formatDate(incident.disputeRaisedAt!)} — payout withheld',
                        style: TextStyle(color: p.red.withValues(alpha: 0.8), fontSize: 12)),
                  ],
                )),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Job info ───────────────────────────────────────────────────
            Text(incident.title,
              style: TextStyle(
                color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
            if (incident.propertyAddress != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 12, color: p.muted),
                const SizedBox(width: 4),
                Text(incident.propertyAddress!,
                  style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ],

            const SizedBox(height: 20),

            // ── Dispute reason ─────────────────────────────────────────────
            _SectionLabel(p: p, label: 'Landlord\'s reason for dispute'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.red.withValues(alpha: 0.2)),
              ),
              child: Text(
                incident.disputeReason ?? 'No reason provided.',
                style: TextStyle(color: p.text, fontSize: 14, height: 1.5)),
            ),

            const SizedBox(height: 20),

            // ── Contractor response ────────────────────────────────────────
            _SectionLabel(p: p, label: 'Contractor\'s response'),
            const SizedBox(height: 8),

            if (hasResponse) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(incident.contractorDisputeResponse!,
                    style: TextStyle(color: p.text, fontSize: 14, height: 1.5)),
                  if (incident.contractorDisputeResponseAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Responded ${_formatDate(incident.contractorDisputeResponseAt!)}',
                      style: TextStyle(color: p.muted, fontSize: 11)),
                  ],
                ]),
              ),
            ] else if (widget.role == 'contractor' && !_showResponseForm) ...[
              // Contractor hasn't responded yet
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('You haven\'t responded to this dispute yet.',
                    style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _showResponseForm = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.blue.withValues(alpha: 0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.reply_outlined, size: 15, color: p.blue),
                        const SizedBox(width: 6),
                        Text('Submit your response',
                          style: TextStyle(
                            color: p.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ] else if (widget.role == 'landlord') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Text('Awaiting contractor response.',
                  style: TextStyle(color: p.muted, fontSize: 13)),
              ),
            ],

            // ── Contractor response form ────────────────────────────────────
            if (_showResponseForm && !hasResponse) ...[
              const SizedBox(height: 16),
              _SectionLabel(p: p, label: 'Your response'),
              const SizedBox(height: 8),
              TextField(
                controller: _responseCtrl,
                maxLines: 5,
                autofocus: true,
                style: TextStyle(color: p.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Explain your work and why it meets the agreed standard. Be professional — this may be seen by Abode support.',
                  hintStyle: TextStyle(color: p.muted, fontSize: 13),
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.blue),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showResponseForm = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel',
                      style: TextStyle(color: p.sub, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: submitState.isLoading ? null : _submitResponse,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: submitState.isLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Text('Submit response',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 24),

            // ── Landlord resolution controls ───────────────────────────────
            if (widget.role == 'landlord' && incident.disputeResolvedAt == null) ...[
              _SectionLabel(p: p, label: 'Resolve dispute'),
              const SizedBox(height: 10),
              if (hasResponse) ...[
                FilledButton.icon(
                  onPressed: resolveState.isLoading
                      ? null
                      : () => _resolve('favour_contractor'),
                  icon: resolveState.isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Accept response — release payment',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AbodePalette.of(context).green,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: resolveState.isLoading
                    ? null
                    : () => _confirmWithhold(context, p),
                icon: Icon(Icons.block_rounded, size: 16, color: p.red),
                label: Text('Withhold payment permanently',
                  style: TextStyle(
                    color: p.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: p.red.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasResponse
                  ? "Accepting releases the contractor's payment. Withholding permanently closes the dispute in your favour."
                  : "You can withhold payment now or wait for the contractor's response before deciding.",
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],

            // ── Resolved banner ────────────────────────────────────────────
            if (incident.disputeResolvedAt != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.green.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: p.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dispute resolved',
                        style: TextStyle(color: p.green, fontSize: 14,
                            fontWeight: FontWeight.w700)),
                      Text(
                        incident.disputeResolution == 'favour_contractor'
                            ? 'Payment released to contractor'
                            : 'Payment withheld',
                        style: TextStyle(
                          color: p.green.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // ── Resolution info ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: p.muted),
                  const SizedBox(width: 6),
                  Text('What happens next',
                    style: TextStyle(
                      color: p.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Abode will review both parties\' evidence and may contact you for more information. '
                  'Payment remains withheld until the dispute is resolved. '
                  'Persistent or fraudulent disputes may affect your platform standing.',
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('mailto:support@abodeapp.co.uk'
                        '?subject=Dispute%20-%20${Uri.encodeComponent(widget.incident.title)}'
                        '&body=Job%20ID%3A%20${widget.incident.id}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text('Contact Abode support →',
                    style: TextStyle(
                      color: p.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(String resolution) async {
    await ref.read(resolveDisputeProvider.notifier)
        .resolve(widget.incident.id, resolution);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmWithhold(BuildContext context, AbodePalette p) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Withhold payment?',
      body: "This will permanently withhold the contractor's payment and close the dispute. This cannot be undone.",
      confirmLabel: 'Withhold payment',
      isDestructive: true,
      icon: Icons.money_off_outlined,
    );
    if (confirmed == true) _resolve('favour_landlord');
  }

  Future<void> _submitResponse() async {
    final response = _responseCtrl.text.trim();
    if (response.isEmpty) {
      showAbodeToast(context, 'Please enter your response.');
      return;
    }
    await ref.read(submitDisputeResponseProvider.notifier)
        .submit(widget.incident.id, response);
    if (mounted) {
      setState(() => _showResponseForm = false);
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }
}

class _SectionLabel extends StatelessWidget {
  final AbodePalette p;
  final String label;
  const _SectionLabel({required this.p, required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: p.muted, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 0.8),
  );
}
