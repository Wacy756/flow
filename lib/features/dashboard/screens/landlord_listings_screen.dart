import 'package:flow_app/core/widgets/abode_date_picker.dart';
import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/property_listing.dart';
import '../models/viewing.dart';
import '../providers/dashboard_providers.dart';
import '../providers/messaging_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────
class LandlordListingsScreen extends ConsumerWidget {
  const LandlordListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final listingsAsync = ref.watch(landlordListingsProvider);

    return RefreshIndicator(
      color: p.blue,
      onRefresh: () async => ref.invalidate(landlordListingsProvider),
      child: listingsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: p.blue, strokeWidth: 2)),
        error: (_, __) => Center(child: Text('Could not load listings.', style: TextStyle(color: p.sub))),
        data: (listings) {
          if (listings.isEmpty) {
            return _EmptyListings(
              onAdd: () => _showCreateListingSheet(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Property Listings',
                        style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text('${listings.length} ${listings.length == 1 ? 'listing' : 'listings'}',
                        style: TextStyle(color: p.sub, fontSize: 13)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showCreateListingSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Add Listing', style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ...listings.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ListingCard(item: l),
              )),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  void _showCreateListingSheet(BuildContext context, WidgetRef ref) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateListingSheet(ref: ref),
    );
  }
}

// ─── Listing card ─────────────────────────────────────────────────────────────
class _ListingCard extends ConsumerStatefulWidget {
  final ListingWithAddress item;
  const _ListingCard({required this.item});

  @override
  ConsumerState<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends ConsumerState<_ListingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final l = widget.item.listing;
    final viewingsAsync = ref.watch(listingViewingsProvider(l.id));
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: l.isActive ? p.blue.withValues(alpha: 0.3) : p.border),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: l.isActive ? p.blue.withValues(alpha: 0.15) : p.muted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: l.isActive ? p.blue.withValues(alpha: 0.35) : p.muted.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: l.isActive ? p.green : p.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(l.isActive ? 'ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              color: l.isActive ? p.blue : p.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Share button
                    if (l.isActive)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: l.shareUrl));
                          showAbodeToast(context, 'Share link copied to clipboard');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.share_outlined, size: 14, color: p.blue),
                            const SizedBox(width: 5),
                            Text('Share', style: TextStyle(
                              color: p.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.item.address,
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (l.askingRent != null)
                  Text(
                    '${fmt.format(l.askingRent!)}/mo',
                    style: TextStyle(color: p.sub, fontSize: 12),
                  ),
                const SizedBox(height: 12),
                viewingsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (viewings) => viewings.isEmpty
                      ? Text('No viewings scheduled',
                          style: TextStyle(color: p.muted, fontSize: 12))
                      : Text(
                          '${viewings.length} viewing${viewings.length == 1 ? '' : 's'} scheduled',
                          style: TextStyle(
                            color: p.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _openScheduleSheet(context, l.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: p.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.blue.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text('+ Schedule Viewing',
                        style: TextStyle(
                          color: p.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openScheduleSheet(BuildContext context, String listingId) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleViewingSheet(listingId: listingId),
    );
  }
}

// ─── Schedule Viewing Sheet ───────────────────────────────────────────────────
class _ScheduleViewingSheet extends StatefulWidget {
  final String listingId;
  const _ScheduleViewingSheet({required this.listingId});

  @override
  State<_ScheduleViewingSheet> createState() => _ScheduleViewingSheetState();
}

class _ScheduleViewingSheetState extends State<_ScheduleViewingSheet> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = DateFormat('EEE d MMMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Schedule a Viewing',
            style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
          const SizedBox(height: 20),

          const _FieldLabel('Applicant Name *'),
          const SizedBox(height: 6),
          _TextField(ctrl: _nameCtrl, hint: 'Full name'),
          const SizedBox(height: 14),

          const _FieldLabel('Email'),
          const SizedBox(height: 6),
          _TextField(ctrl: _emailCtrl, hint: 'Email address',
            keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),

          const _FieldLabel('Phone'),
          const SizedBox(height: 6),
          _TextField(ctrl: _phoneCtrl, hint: 'Phone number',
            keyboardType: TextInputType.phone),
          const SizedBox(height: 14),

          const _FieldLabel('Date & Time *'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showAbodeDatePicker(
                      context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: p.blue),
                        const SizedBox(width: 8),
                        Text(fmt.format(_selectedDate),
                          style: TextStyle(color: p.text, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final t = await showAbodeTimePicker(
                    context,
                    initialTime: _selectedTime,
                  );
                  if (t != null) setState(() => _selectedTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_outlined, size: 16, color: p.blue),
                      const SizedBox(width: 8),
                      Text(_selectedTime.format(context),
                        style: TextStyle(color: p.text, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Schedule Viewing',
                      style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAbodeToast(context, 'Applicant name is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await supabase.from('viewings').insert({
        'listing_id': widget.listingId,
        'applicant_name': _nameCtrl.text.trim(),
        'applicant_email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'applicant_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'scheduled_at': DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day,
          _selectedTime.hour, _selectedTime.minute,
        ).toIso8601String(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        showAbodeToast(context, 'Viewing scheduled');
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showAbodeToast(context, 'Failed to schedule viewing', isError: true);
    }
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;
  const _TextField({required this.ctrl, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: p.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.sub),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.blue, width: 1.5)),
      ),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyListings({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Icon(Icons.storefront_outlined, size: 34, color: p.muted),
            ),
            const SizedBox(height: 16),
            Text('No listings yet',
              style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text('Create a listing to advertise your property\nand collect applications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text('Create First Listing',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.blue,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Create Listing Sheet ─────────────────────────────────────────────────────
class _CreateListingSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreateListingSheet({required this.ref});

  @override
  ConsumerState<_CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends ConsumerState<_CreateListingSheet> {
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Create Listing',
          style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Listing creation is managed from your property settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.blue,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─── Field label ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Text(text, style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600));
  }
}
