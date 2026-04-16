import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

Future<void> showEndTenancySheet(
  BuildContext context, {
  required String tenancyGroupId,
  required String address,
  String? vacateDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EndTenancySheet(
      tenancyGroupId: tenancyGroupId,
      address: address,
      vacateDate: vacateDate,
    ),
  );
}

class _EndTenancySheet extends ConsumerStatefulWidget {
  final String tenancyGroupId;
  final String address;
  final String? vacateDate;

  const _EndTenancySheet({
    required this.tenancyGroupId,
    required this.address,
    this.vacateDate,
  });

  @override
  ConsumerState<_EndTenancySheet> createState() => _EndTenancySheetState();
}

class _EndTenancySheetState extends ConsumerState<_EndTenancySheet> {
  String? _endDate;
  bool? _depositReturnedFull; // null = not chosen, true = yes, false = no
  final _deductionAmountCtrl = TextEditingController();
  final _deductionReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill end date from vacate date if available
    if (widget.vacateDate != null) {
      _endDate = widget.vacateDate;
    }
  }

  @override
  void dispose() {
    _deductionAmountCtrl.dispose();
    _deductionReasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _endDate != null && _depositReturnedFull != null;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final notifier = ref.watch(endTenancyProvider);
    final isLoading = notifier is AsyncLoading;

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
                      const Text(
                        'Finalise Tenancy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.address,
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

            // End of tenancy date
            const Text(
              'End of Tenancy Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
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
                    Text(
                      _endDate != null
                          ? _fmt(_endDate!)
                          : 'Select end date',
                      style: TextStyle(
                        fontSize: 14,
                        color: _endDate != null
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (_endDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _endDate = null),
                        child: const Icon(Icons.close,
                            size: 16, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Deposit returned
            const Text(
              'Deposit Returned in Full?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _YesNoButton(
                    label: 'Yes — full return',
                    selected: _depositReturnedFull == true,
                    positive: true,
                    onTap: () =>
                        setState(() => _depositReturnedFull = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _YesNoButton(
                    label: 'No — deductions',
                    selected: _depositReturnedFull == false,
                    positive: false,
                    onTap: () =>
                        setState(() => _depositReturnedFull = false),
                  ),
                ),
              ],
            ),

            // Deduction fields (shown when deposit NOT returned in full)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _depositReturnedFull == false
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Deduction Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _deductionAmountCtrl,
                          label: 'Deduction Amount (£)',
                          hintText: 'e.g. 350',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          prefixText: '£',
                        ),
                        const SizedBox(height: 10),
                        _InputField(
                          controller: _deductionReasonCtrl,
                          label: 'Reason for Deduction',
                          hintText:
                              'e.g. Damage to carpet in bedroom, professional clean required',
                          maxLines: 3,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            if (notifier is AsyncError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  notifier.error.toString(),
                  style: const TextStyle(color: Colors.red, fontSize: 13),
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
                    : const Text(
                        'Mark Tenancy as Ended',
                        style: TextStyle(
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _endDate != null
        ? (DateTime.tryParse(_endDate!) ?? now)
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
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
      setState(() => _endDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _submit() async {
    double? deductionAmount;
    String? deductionReason;

    if (_depositReturnedFull == false) {
      final raw = _deductionAmountCtrl.text.trim();
      deductionAmount = raw.isNotEmpty ? double.tryParse(raw) : null;
      final reason = _deductionReasonCtrl.text.trim();
      deductionReason = reason.isNotEmpty ? reason : null;
    }

    final ok = await ref.read(endTenancyProvider.notifier).end(
          tenancyGroupId: widget.tenancyGroupId,
          endOfTenancyDate: _endDate!,
          depositReturned: _depositReturnedFull!,
          depositDeductionAmount: deductionAmount,
          depositDeductionReason: deductionReason,
        );

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

class _YesNoButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool positive;
  final VoidCallback onTap;

  const _YesNoButton({
    required this.label,
    required this.selected,
    required this.positive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = positive ? AppTheme.green : const Color(0xFFE65100);
    final activeBg = positive ? AppTheme.greenBg : const Color(0xFFFFF3E0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? activeBg : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : AppTheme.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check_circle,
                    size: 16, color: activeColor),
              ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? activeColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            hintStyle: const TextStyle(
                color: AppTheme.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppTheme.bgSurface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.green, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
