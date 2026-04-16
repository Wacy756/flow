import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/rent_payment.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';

Future<void> showLogPaymentSheet(
  BuildContext context, {
  required Tenancy tenancy,
  RentPayment? existing, // if set, we're updating rather than inserting
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LogPaymentSheet(
      tenancy: tenancy,
      existing: existing,
    ),
  );
}

// ---------------------------------------------------------------------------

class _LogPaymentSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final RentPayment? existing;

  const _LogPaymentSheet({
    required this.tenancy,
    this.existing,
  });

  @override
  ConsumerState<_LogPaymentSheet> createState() => _LogPaymentSheetState();
}

class _LogPaymentSheetState extends ConsumerState<_LogPaymentSheet> {
  late final TextEditingController _amountDueCtrl;
  late final TextEditingController _amountPaidCtrl;
  late final TextEditingController _notesCtrl;
  String? _dueDate;
  String _status = 'pending';

  bool get _isUpdate => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final defaultRent = widget.tenancy.monthlyRent;

    _amountDueCtrl = TextEditingController(
      text: e != null
          ? e.amountDue.toStringAsFixed(2)
          : defaultRent != null
              ? defaultRent.toStringAsFixed(2)
              : '',
    );
    _amountPaidCtrl = TextEditingController(
      text: e != null ? e.amountPaid.toStringAsFixed(2) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _dueDate = e?.dueDate;
    _status = e?.status ?? 'pending';
  }

  @override
  void dispose() {
    _amountDueCtrl.dispose();
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Auto-derive status from amounts
  void _recalcStatus() {
    final due = double.tryParse(_amountDueCtrl.text.trim()) ?? 0;
    final paid = double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
    if (due <= 0) return;
    setState(() {
      if (paid <= 0) {
        _status = 'pending';
      } else if (paid >= due) {
        _status = 'paid';
      } else {
        _status = 'partial';
      }
    });
  }

  bool get _canSubmit =>
      _dueDate != null && _amountDueCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final logNotifier = ref.watch(logRentPaymentProvider);
    final updateNotifier = ref.watch(updateRentPaymentProvider);
    final isLoading = logNotifier is AsyncLoading ||
        updateNotifier is AsyncLoading;
    final hasError = logNotifier is AsyncError || updateNotifier is AsyncError;
    final errorMsg = logNotifier is AsyncError
        ? logNotifier.error.toString()
        : updateNotifier is AsyncError
            ? updateNotifier.error.toString()
            : null;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
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

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isUpdate ? 'Update Payment' : 'Log Payment',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.tenancy.shortAddress,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Due date (hidden when updating — can't change the billing period)
            if (!_isUpdate) ...[
              const _FieldLabel('Due Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 10),
                      Text(
                        _dueDate != null
                            ? _fmt(_dueDate!)
                            : 'Select due date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _dueDate != null
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Amounts row
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    controller: _amountDueCtrl,
                    label: 'Amount Due (£)',
                    hintText: '0.00',
                    onChanged: (_) => _recalcStatus(),
                    readOnly: _isUpdate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AmountField(
                    controller: _amountPaidCtrl,
                    label: 'Amount Paid (£)',
                    hintText: '0.00',
                    onChanged: (_) => _recalcStatus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Status selector
            const _FieldLabel('Status'),
            const SizedBox(height: 8),
            _StatusSelector(
              current: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 14),

            // Notes
            const _FieldLabel('Notes (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Paid via bank transfer',
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

            if (hasError && errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  errorMsg,
                  style:
                      const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !isLoading) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  disabledBackgroundColor:
                      AppTheme.green.withValues(alpha: 0.4),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isUpdate ? 'Update Payment' : 'Save Payment',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate != null
          ? (DateTime.tryParse(_dueDate!) ?? now)
          : DateTime(now.year, now.month, 1),
      firstDate: DateTime(now.year - 2),
      lastDate: now.add(const Duration(days: 365)),
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
    if (picked != null && mounted) {
      setState(() => _dueDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _submit() async {
    final amountDue =
        double.tryParse(_amountDueCtrl.text.trim()) ?? 0;
    final amountPaid =
        double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
    final notes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    bool ok;

    if (_isUpdate) {
      ok = await ref.read(updateRentPaymentProvider.notifier).update(
            paymentId: widget.existing!.id,
            tenancyId: widget.tenancy.tenancyId,
            amountPaid: amountPaid,
            status: _status,
            notes: notes,
          );
    } else {
      ok = await ref.read(logRentPaymentProvider.notifier).log(
            tenancyId: widget.tenancy.tenancyId,
            landlordId: user.id,
            amountDue: amountDue,
            amountPaid: amountPaid,
            dueDate: _dueDate!,
            status: _status,
            notes: notes,
          );
    }

    if (ok && mounted) Navigator.pop(context);
  }

  static String _fmt(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// Status selector

class _StatusSelector extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _StatusSelector({
    required this.current,
    required this.onChanged,
  });

  static const _options = [
    ('pending', 'Pending'),
    ('paid', 'Paid'),
    ('partial', 'Partial'),
    ('late', 'Late'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = current == opt.$1;
        final color = _colorFor(opt.$1);
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Text(
                opt.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorFor(String status) {
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
}

// ---------------------------------------------------------------------------
// Small helpers

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      );
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final void Function(String)? onChanged;
  final bool readOnly;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onChanged: onChanged,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: '£',
            prefixStyle: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14),
            hintStyle: const TextStyle(
                color: AppTheme.textMuted, fontSize: 14),
            filled: true,
            fillColor: readOnly
                ? AppTheme.bgPage
                : AppTheme.bgSurface,
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
      ],
    );
  }
}
