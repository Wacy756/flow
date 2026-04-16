import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/property_listing.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';

Future<void> showListPropertySheet(
  BuildContext context, {
  required Tenancy tenancy,
  required UserProfile landlordProfile,
  PropertyListing? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ListPropertySheet(
      tenancy: tenancy,
      landlordProfile: landlordProfile,
      existing: existing,
    ),
  );
}

class _ListPropertySheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final UserProfile landlordProfile;
  final PropertyListing? existing;

  const _ListPropertySheet({
    required this.tenancy,
    required this.landlordProfile,
    this.existing,
  });

  @override
  ConsumerState<_ListPropertySheet> createState() => _ListPropertySheetState();
}

class _ListPropertySheetState extends ConsumerState<_ListPropertySheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _rentCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _minMonthsCtrl;
  late final TextEditingController _descCtrl;

  String? _availableFrom; // 'yyyy-MM-dd' or null = immediately
  bool _submitted = false;
  PropertyListing? _published;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _rentCtrl = TextEditingController(
        text: e?.askingRent?.toStringAsFixed(0) ?? '');
    _depositCtrl = TextEditingController(
        text: e?.depositAmount?.toStringAsFixed(0) ?? '');
    _minMonthsCtrl = TextEditingController(
        text: e?.minTenancyMonths?.toString() ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _availableFrom = e?.availableFrom;
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _minMonthsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgPage,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _submitted ? 'Listing Published' : (widget.existing != null ? 'Edit Listing' : 'Create Listing'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _submitted
                    ? _PublishedView(listing: _published ?? widget.existing!)
                    : _FormView(
                        key: const ValueKey('form'),
                        formKey: _formKey,
                        rentCtrl: _rentCtrl,
                        depositCtrl: _depositCtrl,
                        minMonthsCtrl: _minMonthsCtrl,
                        descCtrl: _descCtrl,
                        availableFrom: _availableFrom,
                        tenancy: widget.tenancy,
                        scrollController: controller,
                        bottomInset: bottom,
                        onAvailableFromChanged: (v) =>
                            setState(() => _availableFrom = v),
                        onPublish: _publish,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;

    final listing = await ref.read(manageListingProvider.notifier).save(
          propertyId: widget.tenancy.tenancyId,
          landlordId: widget.landlordProfile.id,
          askingRent: double.tryParse(_rentCtrl.text.trim()),
          availableFrom: _availableFrom,
          depositAmount: double.tryParse(_depositCtrl.text.trim()),
          minTenancyMonths: int.tryParse(_minMonthsCtrl.text.trim()),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );

    if (listing != null && mounted) {
      setState(() {
        _published = listing;
        _submitted = true;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to publish listing. Please try again.'),
          backgroundColor: AppTheme.darkBg,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController rentCtrl;
  final TextEditingController depositCtrl;
  final TextEditingController minMonthsCtrl;
  final TextEditingController descCtrl;
  final String? availableFrom;
  final Tenancy tenancy;
  final ScrollController scrollController;
  final double bottomInset;
  final void Function(String?) onAvailableFromChanged;
  final VoidCallback onPublish;

  const _FormView({
    super.key,
    required this.formKey,
    required this.rentCtrl,
    required this.depositCtrl,
    required this.minMonthsCtrl,
    required this.descCtrl,
    required this.availableFrom,
    required this.tenancy,
    required this.scrollController,
    required this.bottomInset,
    required this.onAvailableFromChanged,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAvail = availableFrom == null
        ? 'Immediately'
        : _formatDate(availableFrom!);

    return Form(
      key: formKey,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
        children: [
          // Property header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_outlined,
                    color: AppTheme.textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tenancy.shortAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _FieldLabel('Asking Rent (monthly)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: rentCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: _inputDecoration('£ e.g. 1200'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
          const SizedBox(height: 16),

          _FieldLabel('Deposit Amount'),
          const SizedBox(height: 8),
          TextFormField(
            controller: depositCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: _inputDecoration('£ e.g. 1800'),
          ),
          const SizedBox(height: 16),

          _FieldLabel('Minimum Tenancy Length'),
          const SizedBox(height: 8),
          TextFormField(
            controller: minMonthsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration('Months, e.g. 12'),
          ),
          const SizedBox(height: 16),

          _FieldLabel('Available From'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickDate(context),
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
                    formattedAvail,
                    style: TextStyle(
                      fontSize: 14,
                      color: availableFrom == null
                          ? AppTheme.textMuted
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (availableFrom != null)
                    GestureDetector(
                      onTap: () => onAvailableFromChanged(null),
                      child: const Icon(Icons.close,
                          size: 16, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _FieldLabel('Description (optional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: descCtrl,
            maxLines: 4,
            decoration: _inputDecoration(
                'e.g. Spacious flat with great transport links…'),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: onPublish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Publish Listing',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: availableFrom != null
          ? DateTime.tryParse(availableFrom!) ?? now
          : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
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
    if (picked != null) {
      onAvailableFromChanged(
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  static String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppTheme.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      );
}

Widget _FieldLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );

// ---------------------------------------------------------------------------

class _PublishedView extends StatelessWidget {
  final PropertyListing listing;
  const _PublishedView({required this.listing});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // Success icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.greenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppTheme.green, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Your listing is live',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Share the link below with prospective tenants.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // Link box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'APPLICATION LINK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                listing.shareUrl,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: listing.shareUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        backgroundColor: AppTheme.darkBg,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                  label: const Text(
                    'Copy Link',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Summary chips
        if (listing.askingRent != null || listing.availableFrom != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (listing.askingRent != null)
                _Chip(
                    icon: Icons.currency_pound,
                    label:
                        '£${listing.askingRent!.toStringAsFixed(0)}/mo'),
              if (listing.depositAmount != null)
                _Chip(
                    icon: Icons.savings_outlined,
                    label:
                        '£${listing.depositAmount!.toStringAsFixed(0)} deposit'),
              _Chip(
                  icon: Icons.calendar_today_outlined,
                  label: listing.availableFromFormatted),
              if (listing.minTenancyMonths != null)
                _Chip(
                    icon: Icons.timelapse_outlined,
                    label: '${listing.minTenancyMonths} months min'),
            ],
          ),
          const SizedBox(height: 20),
        ],

        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.border),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}
