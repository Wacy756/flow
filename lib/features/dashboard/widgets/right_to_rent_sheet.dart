import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void showRightToRentSheet(BuildContext context, {required Tenancy tenancy}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RightToRentSheet(tenancy: tenancy),
  );
}

// ─── Document types accepted for RTR ─────────────────────────────────────────

const _kDocTypes = [
  'UK/EU Passport',
  'Biometric Residence Permit',
  'UK Driving Licence + Birth Certificate',
  'Certificate of Registration',
  'Immigration Status Document',
  'Other acceptable document',
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _RightToRentSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _RightToRentSheet({required this.tenancy});

  @override
  ConsumerState<_RightToRentSheet> createState() => _RightToRentSheetState();
}

class _RightToRentSheetState extends ConsumerState<_RightToRentSheet> {
  AbodePalette get p => AbodePalette.of(context);

  String? _method;      // 'online_gov' | 'physical_document'
  String? _docType;
  bool _saving = false;

  bool get _alreadyDone => widget.tenancy.rtrStatus == 'completed';
  bool get _canSave => _method != null && (_method == 'online_gov' || _docType != null);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final today = DateTime.now();
      await supabase.from('tenancies').update({
        'rtr_status': 'completed',
        'rtr_check_date':
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        'rtr_check_method': _method,
        if (_docType != null) 'rtr_document_type': _docType,
      }).eq('tenancy_id', widget.tenancy.tenancyId);

      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordAlertsProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAbodeToast(context, 'Failed to save: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final tenancy = widget.tenancy;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined,
                    color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Right to Rent',
                      style: TextStyle(
                        color: p.text, fontSize: 18,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    Text(tenancy.shortAddress,
                        style: TextStyle(color: p.sub, fontSize: 12)),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              else
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
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (_alreadyDone) ...[
                  _CompletedView(tenancy: tenancy),
                ] else ...[
                  if (tenancy.rtrDocumentUrl != null &&
                      tenancy.rtrDocumentUrl!.isNotEmpty)
                    _TenantUploadedDocBox(tenancy: tenancy, p: p),
                  const SizedBox(height: 16),
                  _SectionLabel('VERIFICATION METHOD'),
                  const SizedBox(height: 8),
                  Row(children: [
                    _MethodChip(
                      label: 'Gov.uk\nOnline Check',
                      icon: Icons.language_rounded,
                      selected: _method == 'online_gov',
                      onTap: () => setState(() {
                        _method = 'online_gov';
                        _docType = null;
                      }),
                    ),
                    const SizedBox(width: 10),
                    _MethodChip(
                      label: 'Physical\nDocument',
                      icon: Icons.badge_outlined,
                      selected: _method == 'physical_document',
                      onTap: () => setState(() => _method = 'physical_document'),
                    ),
                  ]),
                  if (_method == 'online_gov' &&
                      tenancy.rtrShareCode != null &&
                      tenancy.rtrShareCode!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ShareCodeView(shareCode: tenancy.rtrShareCode!),
                  ],
                  if (_method == 'physical_document') ...[
                    const SizedBox(height: 16),
                    _SectionLabel('DOCUMENT TYPE'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        children: List.generate(_kDocTypes.length, (i) =>
                          _DocTypeRow(
                            label: _kDocTypes[i],
                            selected: _docType == _kDocTypes[i],
                            isLast: i == _kDocTypes.length - 1,
                            onTap: () => setState(() => _docType = _kDocTypes[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canSave && !_saving ? _save : null,
                      child: Text(_saving ? 'Saving…' : 'Mark as Verified'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Share code view ──────────────────────────────────────────────────────────

class _ShareCodeView extends StatefulWidget {
  final String shareCode;
  const _ShareCodeView({required this.shareCode});

  @override
  State<_ShareCodeView> createState() => _ShareCodeViewState();
}

class _ShareCodeViewState extends State<_ShareCodeView> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    const blue = Color(0xFF3B82F6);
    const green = Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blue.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Gov.uk Share Code',
              style: TextStyle(
                color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.shareCode));
              setState(() => _copied = true);
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _copied = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _copied
                    ? green.withValues(alpha: 0.1)
                    : blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 11,
                  color: _copied ? green : blue,
                ),
                const SizedBox(width: 4),
                Text(
                  _copied ? 'Copied' : 'Copy',
                  style: TextStyle(
                    color: _copied ? green : blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(widget.shareCode,
            style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text('Enter this code at gov.uk/landlord-immigration-check',
            style: TextStyle(color: p.sub, fontSize: 11)),
      ]),
    );
  }
}

// ─── Completed view ───────────────────────────────────────────────────────────

class _CompletedView extends StatelessWidget {
  final Tenancy tenancy;
  const _CompletedView({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final date = tenancy.rtrCheckDate;
    final method = tenancy.rtrCheckMethod;
    final docType = tenancy.rtrDocumentType;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.check_circle_rounded,
                size: 16, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text('Check completed',
                style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          if (date != null)
            _InfoRow(label: 'Date checked',
                value: '${date.day}/${date.month}/${date.year}'),
          if (method != null)
            _InfoRow(
                label: 'Method',
                value: method == 'online_gov'
                    ? 'Gov.uk online check'
                    : 'Physical document'),
          if (docType != null)
            _InfoRow(label: 'Document', value: docType),
          if (tenancy.rtrShareCode != null &&
              tenancy.rtrShareCode!.isNotEmpty)
            _InfoRow(label: 'Share code', value: tenancy.rtrShareCode!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: p.sub, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: p.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Method chip ──────────────────────────────────────────────────────────────

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    const accent = Color(0xFF3B82F6);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : p.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : p.border,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: selected ? accent : p.muted),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? accent : p.sub,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─── Document type row ────────────────────────────────────────────────────────

class _DocTypeRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  const _DocTypeRow({
    required this.label,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    const accent = Color(0xFF3B82F6);
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: selected ? accent : p.text,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    )),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? accent : p.border, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
            ]),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1, indent: 16, color: p.border, thickness: 0.5),
      ],
    );
  }
}

// ─── Tenant-uploaded doc box ──────────────────────────────────────────────────
class _TenantUploadedDocBox extends StatelessWidget {
  final Tenancy tenancy;
  final AbodePalette p;
  const _TenantUploadedDocBox({required this.tenancy, required this.p});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    final docType = tenancy.rtrTenantDocType ?? 'Document';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blue.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.insert_drive_file_outlined, color: blue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(docType,
              style: const TextStyle(color: blue, fontSize: 13, fontWeight: FontWeight.w700)),
          const Text('Uploaded by tenant', style: TextStyle(color: blue, fontSize: 11)),
        ])),
        GestureDetector(
          onTap: () async {
            final url = Supabase.instance.client.storage
                .from('compliance-docs')
                .getPublicUrl(tenancy.rtrDocumentUrl!);
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('View',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Text(text,
        style: TextStyle(
          color: p.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ));
  }
}
