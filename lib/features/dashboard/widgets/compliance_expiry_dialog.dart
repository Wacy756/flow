import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/compliance_doc.dart';

/// Shows a bottom sheet collecting issue date, expiry date, and cert number.
/// Returns a record `(DateTime? issueDate, DateTime? expiryDate, String? certNumber)`
/// or null if the user dismissed without confirming.
Future<({DateTime? issueDate, DateTime? expiryDate, String? certNumber})?> showComplianceExpiryDialog(
  BuildContext context, {
  required String docType,
  DateTime? initialIssueDate,
  DateTime? initialExpiryDate,
  String? initialCertNumber,
}) {
  return showModalBottomSheet<
      ({DateTime? issueDate, DateTime? expiryDate, String? certNumber})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComplianceExpirySheet(
      docType: docType,
      initialIssueDate: initialIssueDate,
      initialExpiryDate: initialExpiryDate,
      initialCertNumber: initialCertNumber,
    ),
  );
}

class _ComplianceExpirySheet extends StatefulWidget {
  final String docType;
  final DateTime? initialIssueDate;
  final DateTime? initialExpiryDate;
  final String? initialCertNumber;

  const _ComplianceExpirySheet({
    required this.docType,
    this.initialIssueDate,
    this.initialExpiryDate,
    this.initialCertNumber,
  });

  @override
  State<_ComplianceExpirySheet> createState() => _ComplianceExpirySheetState();
}

class _ComplianceExpirySheetState extends State<_ComplianceExpirySheet> {
  final _certCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _issueDate = widget.initialIssueDate;
    _expiryDate = widget.initialExpiryDate;
    _certCtrl.text = widget.initialCertNumber ?? '';
  }

  @override
  void dispose() {
    _certCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final expiryHint = kComplianceDocExpiry[widget.docType];
    final (name, _) = _docLabel(widget.docType);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Optionally add certificate details before uploading.',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          if (expiryHint != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: Color(0xFFE65100)),
                  const SizedBox(width: 5),
                  Text(
                    'Required renewal: $expiryHint',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Issue date
          _FieldLabel('Issue Date (optional)'),
          const SizedBox(height: 8),
          _DateRow(
            value: _issueDate,
            hint: 'Select date certificate was issued',
            onChanged: (d) => setState(() => _issueDate = d),
            maxDate: DateTime.now(),
          ),
          const SizedBox(height: 14),

          // Expiry date
          _FieldLabel('Expiry Date (optional)'),
          const SizedBox(height: 8),
          _DateRow(
            value: _expiryDate,
            hint: 'Select expiry date',
            onChanged: (d) => setState(() => _expiryDate = d),
            minDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
          ),
          const SizedBox(height: 14),

          // Cert number
          _FieldLabel('Certificate Number (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _certCtrl,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. GS-2024-00123',
              hintStyle: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppTheme.bgSurface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    (
                      issueDate: _issueDate,
                      expiryDate: _expiryDate,
                      certNumber: _certCtrl.text.trim().isEmpty
                          ? null
                          : _certCtrl.text.trim(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Continue to Upload',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, String?) _docLabel(String type) {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(type);
    if (match != null) {
      return (match.group(1)!.trim(), match.group(2)!.trim());
    }
    return (type, null);
  }
}

Widget _FieldLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );

class _DateRow extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final void Function(DateTime?) onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  const _DateRow({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.minDate,
    this.maxDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null ? _fmt(value!) : hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close,
                    size: 16, color: AppTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: minDate ?? DateTime(2000),
      lastDate: maxDate ?? now.add(const Duration(days: 365 * 20)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.green,
            surface: AppTheme.bgSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  static String _fmt(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
