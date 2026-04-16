import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

Future<void> showServeNoticeSheet(
  BuildContext context, {
  required String tenancyGroupId,
  required String address,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServeNoticeSheet(
      tenancyGroupId: tenancyGroupId,
      address: address,
    ),
  );
}

class _ServeNoticeSheet extends ConsumerStatefulWidget {
  final String tenancyGroupId;
  final String address;

  const _ServeNoticeSheet({
    required this.tenancyGroupId,
    required this.address,
  });

  @override
  ConsumerState<_ServeNoticeSheet> createState() => _ServeNoticeSheetState();
}

class _ServeNoticeSheetState extends ConsumerState<_ServeNoticeSheet> {
  String? _noticeType;
  String? _vacateDate;

  static const _types = [
    ('s21', 'Section 21', 'No-fault notice to vacate'),
    ('s8', 'Section 8', 'Notice with grounds (e.g. arrears)'),
    ('mutual', 'Mutual Agreement', 'Both parties agree to end tenancy'),
    ('surrender', 'Surrender', 'Tenant vacates early by agreement'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final notifier = ref.watch(serveNoticeProvider);
    final isLoading = notifier is AsyncLoading;

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

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Serve Notice',
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

          // Notice type
          const Text(
            'Type of Notice',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ..._types.map((type) {
            final selected = _noticeType == type.$1;
            return GestureDetector(
              onTap: () => setState(() => _noticeType = type.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.greenBg : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppTheme.green : AppTheme.border,
                    width: selected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppTheme.green
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            type.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? AppTheme.green.withValues(alpha: 0.8)
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: AppTheme.green, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Vacate date
          const Text(
            'Vacate Date',
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
                    _vacateDate != null
                        ? _fmt(_vacateDate!)
                        : 'Select vacate date',
                    style: TextStyle(
                      fontSize: 14,
                      color: _vacateDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                  const Spacer(),
                  if (_vacateDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _vacateDate = null),
                      child: const Icon(Icons.close,
                          size: 16, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (notifier is AsyncError) ...[
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
                notifier.error.toString(),
                style:
                    const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_noticeType == null ||
                      _vacateDate == null ||
                      isLoading)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                disabledBackgroundColor:
                    const Color(0xFFE65100).withValues(alpha: 0.4),
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
                      'Serve Notice',
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
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 60)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
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
      setState(() => _vacateDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _submit() async {
    final ok = await ref.read(serveNoticeProvider.notifier).serve(
          tenancyGroupId: widget.tenancyGroupId,
          noticeType: _noticeType!,
          vacateDate: _vacateDate!,
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
