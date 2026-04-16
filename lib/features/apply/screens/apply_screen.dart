import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../../dashboard/models/property_listing.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class ApplyScreen extends ConsumerWidget {
  final String token;
  const ApplyScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingByTokenProvider(token));

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPage,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const FlowLogo(size: 24),
            const SizedBox(width: 8),
            const Text('Flow',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: listingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
        error: (_, __) => _NotFound(),
        data: (listing) {
          if (listing == null) return _NotFound();
          return _ApplyBody(listing: listing);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ApplyBody extends ConsumerWidget {
  final PropertyListing listing;
  const _ApplyBody({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final myAppAsync =
        user != null ? ref.watch(myApplicationProvider(listing.id)) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property card
          _PropertyCard(listing: listing),
          const SizedBox(height: 24),

          if (user == null) ...[
            _AuthPrompt(listing: listing),
          ] else ...[
            if (myAppAsync != null)
              myAppAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppTheme.green),
                  ),
                ),
                error: (_, __) => _ApplicationForm(listing: listing),
                data: (existing) {
                  if (existing != null) {
                    return _ApplicationSubmitted(application: existing);
                  }
                  return _ApplicationForm(listing: listing);
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PropertyCard extends StatelessWidget {
  final PropertyListing listing;
  const _PropertyCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.greenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_outlined,
                    color: AppTheme.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Property Application',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AVAILABLE TO LET',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (listing.askingRent != null)
                _KeyFact(
                  icon: Icons.currency_pound,
                  label: 'Monthly rent',
                  value: '£${listing.askingRent!.toStringAsFixed(0)}',
                  highlight: true,
                ),
              if (listing.depositAmount != null)
                _KeyFact(
                  icon: Icons.savings_outlined,
                  label: 'Deposit',
                  value: '£${listing.depositAmount!.toStringAsFixed(0)}',
                ),
              _KeyFact(
                icon: Icons.calendar_today_outlined,
                label: 'Available from',
                value: listing.availableFromFormatted,
              ),
              if (listing.minTenancyMonths != null)
                _KeyFact(
                  icon: Icons.timelapse_outlined,
                  label: 'Min tenancy',
                  value: '${listing.minTenancyMonths} months',
                ),
            ],
          ),
          if (listing.description != null &&
              listing.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              listing.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _KeyFact({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.greenBg : AppTheme.bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? AppTheme.green.withValues(alpha: 0.3)
                : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 12,
                    color: highlight ? AppTheme.green : AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: highlight ? AppTheme.green : AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.green : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _AuthPrompt extends StatelessWidget {
  final PropertyListing listing;
  const _AuthPrompt({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apply for this property',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a free account or sign in to submit your application.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(
                '${AppRoutes.auth}?role=tenant&mode=signup&redirect=/apply/${listing.shareToken}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.green,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Create Account & Apply',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(
                '${AppRoutes.auth}?mode=signin&redirect=/apply/${listing.shareToken}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ApplicationForm extends ConsumerStatefulWidget {
  final PropertyListing listing;
  const _ApplicationForm({required this.listing});

  @override
  ConsumerState<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<_ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _employerCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _petDetailsCtrl = TextEditingController();
  final _ccjDetailsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _employmentStatus;
  String? _moveInPreference;
  int _numAdults = 1;
  int _numChildren = 0;
  bool _hasPets = false;
  bool _isSmoker = false;
  bool _hasCcj = false;
  bool _submitted = false;

  static const _employmentOptions = [
    ('employed', 'Employed'),
    ('self_employed', 'Self-employed'),
    ('student', 'Student'),
    ('unemployed', 'Unemployed'),
    ('retired', 'Retired'),
  ];

  @override
  void dispose() {
    _employerCtrl.dispose();
    _incomeCtrl.dispose();
    _petDetailsCtrl.dispose();
    _ccjDetailsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _ThankYou();
    }

    final notifierState = ref.watch(submitApplicationProvider);

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Application',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The landlord will review your application and get back to you.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),

            // ── Occupants ──────────────────────────────────────────────
            _Label('Number of Occupants'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Counter(
                    label: 'Adults',
                    value: _numAdults,
                    min: 1,
                    onChanged: (v) => setState(() => _numAdults = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Counter(
                    label: 'Children',
                    value: _numChildren,
                    min: 0,
                    onChanged: (v) => setState(() => _numChildren = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Employment ─────────────────────────────────────────────
            _Label('Employment Status'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _employmentOptions.map((opt) {
                final selected = _employmentStatus == opt.$1;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _employmentStatus = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.greenBg : AppTheme.bgPage,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppTheme.green : AppTheme.border,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? AppTheme.green
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _Label('Employer / Institution (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _employerCtrl,
              decoration: _inputDec('e.g. Acme Ltd'),
            ),
            const SizedBox(height: 16),

            _Label('Monthly Income (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _incomeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDec('£ e.g. 3500'),
            ),
            const SizedBox(height: 20),

            // ── Move-in ────────────────────────────────────────────────
            _Label('Preferred Move-in Date (optional)'),
            const SizedBox(height: 8),
            _DatePickerField(
              value: _moveInPreference,
              onChanged: (v) => setState(() => _moveInPreference = v),
            ),
            const SizedBox(height: 20),

            // ── Pets ───────────────────────────────────────────────────
            _YesNoRow(
              label: 'Do you have pets?',
              value: _hasPets,
              onChanged: (v) => setState(() {
                _hasPets = v;
                if (!v) _petDetailsCtrl.clear();
              }),
            ),
            if (_hasPets) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _petDetailsCtrl,
                decoration: _inputDec('e.g. 1 cat, 1 small dog'),
                validator: (v) =>
                    _hasPets && (v == null || v.trim().isEmpty)
                        ? 'Please describe your pets'
                        : null,
              ),
            ],
            const SizedBox(height: 16),

            // ── Smoker ─────────────────────────────────────────────────
            _YesNoRow(
              label: 'Do you smoke?',
              value: _isSmoker,
              onChanged: (v) => setState(() => _isSmoker = v),
            ),
            const SizedBox(height: 16),

            // ── CCJ ────────────────────────────────────────────────────
            _YesNoRow(
              label: 'Do you have any CCJs, bankruptcy orders, or prior evictions?',
              value: _hasCcj,
              onChanged: (v) => setState(() {
                _hasCcj = v;
                if (!v) _ccjDetailsCtrl.clear();
              }),
            ),
            if (_hasCcj) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _ccjDetailsCtrl,
                maxLines: 2,
                decoration: _inputDec('Please provide brief details'),
                validator: (v) =>
                    _hasCcj && (v == null || v.trim().isEmpty)
                        ? 'Please provide details'
                        : null,
              ),
            ],
            const SizedBox(height: 20),

            // ── Notes ──────────────────────────────────────────────────
            _Label('Additional Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _inputDec(
                  'Anything else you\'d like the landlord to know…'),
            ),
            const SizedBox(height: 24),

            if (notifierState is AsyncError) ...[
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
                  notifierState.error.toString(),
                  style: const TextStyle(
                      color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: notifierState is AsyncLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  disabledBackgroundColor:
                      AppTheme.green.withValues(alpha: 0.5),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: notifierState is AsyncLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Application',
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

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final ok = await ref
          .read(submitApplicationProvider.notifier)
          .submit(
            listingId: widget.listing.id,
            propertyId: widget.listing.propertyId,
            landlordId: widget.listing.landlordId,
            employmentStatus: _employmentStatus,
            employerName: _employerCtrl.text.trim().isEmpty
                ? null
                : _employerCtrl.text.trim(),
            monthlyIncome: double.tryParse(_incomeCtrl.text.trim()),
            moveInPreference: _moveInPreference,
            numAdults: _numAdults,
            numChildren: _numChildren,
            hasPets: _hasPets,
            petDetails: _hasPets && _petDetailsCtrl.text.trim().isNotEmpty
                ? _petDetailsCtrl.text.trim()
                : null,
            isSmoker: _isSmoker,
            hasCcj: _hasCcj,
            ccjDetails: _hasCcj && _ccjDetailsCtrl.text.trim().isNotEmpty
                ? _ccjDetailsCtrl.text.trim()
                : null,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (ok && mounted) {
        setState(() => _submitted = true);
      }
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppTheme.bgPage,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      );
}

Widget _Label(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );

// ---------------------------------------------------------------------------

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final void Function(int) onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _CounterBtn(
                icon: Icons.remove,
                enabled: value > min,
                onTap: () => onChanged(value - 1),
              ),
              const SizedBox(width: 6),
              _CounterBtn(
                icon: Icons.add,
                enabled: true,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CounterBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.bgSurface : AppTheme.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class _YesNoRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _YesNoRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _Pill(label: 'Yes', active: value, onTap: () => onChanged(true)),
        const SizedBox(width: 6),
        _Pill(label: 'No', active: !value, onTap: () => onChanged(false)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.greenBg : AppTheme.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppTheme.green : AppTheme.border,
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppTheme.green : AppTheme.textSecondary,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class _DatePickerField extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;
  const _DatePickerField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'Flexible / No preference' : _fmt(value!);

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: value == null
                    ? AppTheme.textMuted
                    : AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
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
      initialDate:
          value != null ? DateTime.tryParse(value!) ?? now : now,
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
      onChanged(
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  static String _fmt(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

// ---------------------------------------------------------------------------

class _ThankYou extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.greenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppTheme.green, size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'Application submitted!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'The landlord will review your application and contact you.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ApplicationSubmitted extends StatelessWidget {
  final dynamic application;
  const _ApplicationSubmitted({required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application.status as String;
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    Color color;
    String label;
    IconData icon;
    if (isApproved) {
      color = AppTheme.green;
      label = 'Application Approved';
      icon = Icons.check_circle_outline;
    } else if (isRejected) {
      color = Colors.red;
      label = 'Application Not Successful';
      icon = Icons.cancel_outlined;
    } else {
      color = const Color(0xFFE65100);
      label = 'Application Under Review';
      icon = Icons.hourglass_empty_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (isRejected &&
              application.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              application.rejectionReason as String,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_outlined,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Listing not found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This link may have expired or the property may no longer be available.',
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
