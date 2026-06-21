import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/widgets/adaptive_sheet.dart';

import '../../../core/services/pdf_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/tenancy.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Entry ────────────────────────────────────────────────────────────────────
void showCheckInReportSheet(BuildContext context, {required Tenancy tenancy}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CheckInModeSheet(tenancy: tenancy, rootContext: context),
  );
}

// ─── Check-in method enums ────────────────────────────────────────────────────
enum _CIMethod { self, aiic, noLettingGo, ownPerson }
enum _AccessMethod { landlordPresent, lockbox, agentKeys, smartLock }

// ─── Models ───────────────────────────────────────────────────────────────────
enum _ReportType { checkIn, checkOut }
enum _Section { rooms, safety, meters, keys, notes }

class _RoomItem {
  final String name;
  int condition    = 0;    // 0 Excellent · 1 Good · 2 Fair · 3 Poor
  String cleanliness = 'clean'; // clean | needs_attention | dirty
  String notes     = '';
  List<String> photoUrls = [];
  bool included    = true;
  List<_ApplianceItem> appliances = [];
  _RoomItem(this.name, {this.included = true});
}

class _ApplianceItem {
  final String name;
  bool working = true;
  String notes = '';
  _ApplianceItem(this.name);
}

const _conditionLabels = ['Excellent', 'Good', 'Fair', 'Poor'];
const _conditionColors = [
  Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFFBBF24), Color(0xFFEF4444),
];
const _conditionIcons = [
  Icons.star_rounded, Icons.thumb_up_outlined,
  Icons.remove_circle_outline, Icons.warning_amber_rounded,
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class _InspectionScreen extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _InspectionScreen({required this.tenancy});
  @override
  ConsumerState<_InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends ConsumerState<_InspectionScreen> {
  _ReportType _type  = _ReportType.checkIn;
  bool _summaryMode  = false;
  bool _saving       = false;
  _Section _activeSection = _Section.rooms;

  final List<_RoomItem> _rooms = [
    _RoomItem('Entrance / Hallway')..appliances = [
      _ApplianceItem('Front door lock'), _ApplianceItem('Doorbell'),
    ],
    _RoomItem('Living Room')..appliances = [
      _ApplianceItem('Windows/blinds'), _ApplianceItem('Light fittings'),
    ],
    _RoomItem('Kitchen')..appliances = [
      _ApplianceItem('Oven / Hob'), _ApplianceItem('Extractor fan'),
      _ApplianceItem('Fridge / Freezer'), _ApplianceItem('Washing machine'),
      _ApplianceItem('Dishwasher'),
    ],
    _RoomItem('Bedroom 1')..appliances = [
      _ApplianceItem('Windows/blinds'), _ApplianceItem('Built-in wardrobes'),
    ],
    _RoomItem('Bedroom 2')..appliances = [
      _ApplianceItem('Windows/blinds'), _ApplianceItem('Built-in wardrobes'),
    ],
    _RoomItem('Bathroom')..appliances = [
      _ApplianceItem('Shower'), _ApplianceItem('Toilet'), _ApplianceItem('Taps/basin'),
      _ApplianceItem('Extractor fan'),
    ],
    _RoomItem('WC / Cloakroom', included: false)..appliances = [
      _ApplianceItem('Toilet'), _ApplianceItem('Taps'),
    ],
    _RoomItem('Garden / Outdoor', included: false),
  ];

  final _gasCtrl   = TextEditingController();
  final _elecCtrl  = TextEditingController();
  final _waterCtrl = TextEditingController();

  int _keySets    = 2;
  int _keyFobs    = 0;
  int _keyParking = 0;

  bool _smokeAlarms = false;
  bool _coAlarms    = false;
  final _alarmNotesCtrl = TextEditingController();

  String _cleanlinessOverall = 'clean';
  final _notesCtrl = TextEditingController();

  final Map<int, bool> _uploading = {};

  @override
  void dispose() {
    _gasCtrl.dispose(); _elecCtrl.dispose(); _waterCtrl.dispose();
    _alarmNotesCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  List<_RoomItem> get _included => _rooms.where((r) => r.included).toList();

  // ─── Photo upload ──────────────────────────────────────────────────────────
  Future<void> _pickPhoto(int roomIdx) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading[roomIdx] = true);
    try {
      final room = _included[roomIdx];
      for (final file in result.files) {
        if (file.bytes == null) continue;
        final ext  = file.extension ?? 'jpg';
        final path = '${widget.tenancy.id}/${DateTime.now().millisecondsSinceEpoch}_${room.name.replaceAll(' ', '_')}.$ext';
        await supabase.storage.from('inspection-photos').uploadBinary(
          path, file.bytes!,
          fileOptions: FileOptions(upsert: false,
              contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'));
        final url = supabase.storage.from('inspection-photos').getPublicUrl(path);
        setState(() => room.photoUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Photo upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading[roomIdx] = false);
    }
  }

  // ─── Save to DB ────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // The `inspections` table stores everything in a single `items` jsonb
      // list, plus a few flat columns. Pack rooms first, then synthetic entries
      // for meters / keys / safety so nothing is lost and they render in the
      // inspection viewers (which treat `items` as a list of {name, notes}).
      final roomsJson = _included.map((r) => {
        'name':         r.name,
        'condition':    r.condition,
        'cleanliness':  r.cleanliness,
        'notes':        r.notes,
        'photo_urls':   r.photoUrls,
        'appliances':   r.appliances.map((a) => {
          'name': a.name, 'working': a.working, 'notes': a.notes,
        }).toList(),
      }).toList();

      final meters = [
        if (_gasCtrl.text.trim().isNotEmpty)   'Gas ${_gasCtrl.text.trim()}',
        if (_elecCtrl.text.trim().isNotEmpty)  'Electricity ${_elecCtrl.text.trim()}',
        if (_waterCtrl.text.trim().isNotEmpty) 'Water ${_waterCtrl.text.trim()}',
      ].join(' · ');

      final items = [
        ...roomsJson,
        if (meters.isNotEmpty)
          {'name': 'Meter readings', 'notes': meters},
        {'name': 'Keys handed over', 'notes': '$_keySets sets · $_keyFobs fobs · $_keyParking parking'},
        {
          'name': 'Safety checks',
          'notes': 'Smoke alarms ${_smokeAlarms ? "tested" : "not tested"} · '
              'CO detector ${_coAlarms ? "tested" : "not tested"}'
              '${_alarmNotesCtrl.text.trim().isEmpty ? "" : " · ${_alarmNotesCtrl.text.trim()}"}',
        },
      ];

      // Map the UI values onto the `inspections` CHECK-constrained columns.
      const cleanToCondition = {'clean': 'good', 'needs_attention': 'fair', 'dirty': 'poor'};
      const cleanLabels = {'clean': 'Clean', 'needs_attention': 'Needs attention', 'dirty': 'Dirty'};
      final keysSummary = '$_keySets sets · $_keyFobs fobs · $_keyParking parking';
      final safetySummary = 'Smoke alarms ${_smokeAlarms ? "tested" : "not tested"} · '
          'CO detector ${_coAlarms ? "tested" : "not tested"}'
          '${_alarmNotesCtrl.text.trim().isEmpty ? "" : " · ${_alarmNotesCtrl.text.trim()}"}';

      await supabase.from('inspections').insert({
        'tenancy_id':             widget.tenancy.id,
        'inspection_type':        _type == _ReportType.checkIn ? 'checkin' : 'checkout',
        'inspection_date':        DateTime.now().toIso8601String().split('T')[0],
        'items':                  items,
        'overall_condition':      cleanToCondition[_cleanlinessOverall] ?? 'fair',
        'deposit_recommendation': 'full_return',
        'deduction_amount':       0,
        'notes':                  _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      // Generate a PDF copy of the full report. The save above already
      // succeeded, so a PDF failure must not surface as a save failure.
      try {
        final pdfRooms = _included.map((r) => {
          'name':        r.name,
          'condition':   _conditionLabels[r.condition],
          'cleanliness': cleanLabels[r.cleanliness] ?? r.cleanliness,
          'notes':       r.notes,
          'appliances':  r.appliances
              .map((a) => {'name': a.name, 'working': a.working, 'notes': a.notes})
              .toList(),
          'photoCount':  r.photoUrls.length,
        }).toList();

        final bytes = await PdfService.inspectionReport(
          propertyAddress:    widget.tenancy.shortAddress,
          tenantName:         widget.tenancy.tenant?.fullName ?? 'Tenant',
          inspectionType:     _type == _ReportType.checkIn ? 'Check-in' : 'Check-out',
          date:               DateTime.now(),
          overallCleanliness: cleanLabels[_cleanlinessOverall] ?? _cleanlinessOverall,
          rooms:              pdfRooms,
          meters:             meters,
          keys:               keysSummary,
          safety:             safetySummary,
          notes:              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await PdfService.shareOrPrint(
          bytes,
          'inspection_${_type == _ReportType.checkIn ? "checkin" : "checkout"}_${widget.tenancy.id}.pdf',
        );
      } catch (_) {
        // Non-fatal: the report is saved; the PDF is a convenience copy.
      }

      if (mounted) {
        Navigator.pop(context);
        showAbodeToast(context, '${_type == _ReportType.checkIn ? 'Check-in' : 'Check-out'} report saved');
      }
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Failed to save: $e', isError: true);
        setState(() => _saving = false);
      }
    }
  }

  // ─── Section status helpers ────────────────────────────────────────────────
  String get _roomsStatus {
    final n = _included.length;
    return '$n room${n == 1 ? '' : 's'}';
  }

  String get _safetyStatus {
    if (_smokeAlarms && _coAlarms) return 'All checked';
    if (!_smokeAlarms && !_coAlarms) return 'Not checked';
    return 'Partially done';
  }

  String get _metersStatus {
    final filled = [_gasCtrl, _elecCtrl, _waterCtrl]
        .where((c) => c.text.isNotEmpty).length;
    if (filled == 0) return 'No readings';
    return '$filled reading${filled == 1 ? '' : 's'}';
  }

  String get _keysStatus => '$_keySets set${_keySets == 1 ? '' : 's'}';

  String get _notesStatus =>
      _notesCtrl.text.trim().isNotEmpty ? 'Added' : 'Optional';

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    return Material(
      color: p.bg,
      child: SafeArea(
        child: _summaryMode
            ? _buildSummary(p, isDesktop)
            : isDesktop
                ? _buildDesktopForm(p)
                : _buildMobileForm(p),
      ),
    );
  }

  // ─── DESKTOP FORM ──────────────────────────────────────────────────────────

  Widget _buildDesktopForm(AbodePalette p) {
    return Column(children: [
      _buildDesktopHeader(p),
      Expanded(
        child: Row(children: [
          SizedBox(width: 220, child: _buildDesktopSidebar(p)),
          Container(width: 1, color: p.border),
          Expanded(child: _buildDesktopSectionContent(_activeSection, p)),
        ]),
      ),
      _buildDesktopActionBar(p),
    ]);
  }

  Widget _buildDesktopHeader(AbodePalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: p.sub),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Property Inspection Report',
            style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(widget.tenancy.shortAddress,
            style: TextStyle(color: p.sub, fontSize: 12), overflow: TextOverflow.ellipsis),
        ])),
        _TypeToggleBar(type: _type, onChanged: (t) => setState(() => _type = t), p: p),
        const SizedBox(width: 16),
        Text(
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _buildDesktopSidebar(AbodePalette p) {
    final sections = [
      (_Section.rooms,  Icons.door_front_door_outlined, 'Rooms',          _roomsStatus),
      (_Section.safety, Icons.security_outlined,        'Safety Checks',  _safetyStatus),
      (_Section.meters, Icons.speed_outlined,           'Meter Readings', _metersStatus),
      (_Section.keys,   Icons.vpn_key_outlined,         'Keys & Access',  _keysStatus),
      (_Section.notes,  Icons.note_outlined,            'Additional Notes', _notesStatus),
    ];
    return Container(
      color: p.surface,
      child: Column(children: [
        // Legal notice
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.blue.withValues(alpha: 0.18)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_outlined, size: 13, color: p.blue),
            const SizedBox(width: 7),
            Expanded(child: Text(
              'This report is a legal record of property condition.',
              style: TextStyle(color: p.sub, fontSize: 11, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            children: sections.map((s) => _SidebarSectionItem(
              icon: s.$2,
              label: s.$3,
              status: s.$4,
              active: _activeSection == s.$1,
              p: p,
              onTap: () => setState(() => _activeSection = s.$1),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildDesktopSectionContent(_Section section, AbodePalette p) {
    return switch (section) {
      _Section.rooms  => _buildDesktopRooms(p),
      _Section.safety => _buildDesktopSafety(p),
      _Section.meters => _buildDesktopMeters(p),
      _Section.keys   => _buildDesktopKeys(p),
      _Section.notes  => _buildDesktopNotes(p),
    };
  }

  Widget _buildGuidanceCard(AbodePalette p, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.blue.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.blue.withValues(alpha: 0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 15, color: p.blue),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
        style: TextStyle(color: p.sub, fontSize: 12, height: 1.55))),
    ]),
  );

  Widget _buildDesktopRooms(AbodePalette p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      _SectionHeader(p: p, icon: Icons.door_front_door_outlined, label: 'Rooms & Condition'),
      const SizedBox(height: 12),
      _buildGuidanceCard(p,
        'Document the condition of each room carefully. Photos are your strongest evidence if a deposit dispute arises. Rate each area and note any existing damage — even minor scuffs — to protect both landlord and tenant. This information forms part of a legally binding inventory.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _rooms.map((r) => GestureDetector(
          onTap: () => setState(() => r.included = !r.included),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: r.included ? p.blue.withValues(alpha: 0.12) : p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: r.included ? p.blue.withValues(alpha: 0.4) : p.border)),
            child: Text(r.name, style: TextStyle(
              color: r.included ? p.blue : p.sub,
              fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        )).toList(),
      ),
      const SizedBox(height: 16),
      ...List.generate(_included.length, (i) => _RoomCard(
        room: _included[i],
        index: i,
        uploading: _uploading[i] ?? false,
        onPickPhoto: () => _pickPhoto(i),
        onChanged: () => setState(() {}),
        p: p,
      )),
      const SizedBox(height: 20),
      _SectionHeader(p: p, icon: Icons.cleaning_services_outlined, label: 'Overall Cleanliness'),
      const SizedBox(height: 10),
      _InfoCard(p: p, children: [
        _CleanlinessSelector(
          value: _cleanlinessOverall,
          onChanged: (v) => setState(() => _cleanlinessOverall = v),
          p: p,
        ),
      ]),
    ],
  );

  Widget _buildDesktopSafety(AbodePalette p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      _SectionHeader(p: p, icon: Icons.security_outlined, label: 'Safety Checks'),
      const SizedBox(height: 12),
      _buildGuidanceCard(p,
        'Under the Smoke and Carbon Monoxide Alarm (Amendment) Regulations 2022, landlords must ensure a working smoke alarm is fitted on every floor and a CO alarm is installed in rooms with solid fuel appliances. Both must be tested at the start of each new tenancy and confirmed working. Failure to comply may result in a remedial notice and civil penalties.'),
      const SizedBox(height: 16),
      _InfoCard(p: p, children: [
        _CheckRow(
          label: 'Smoke alarms tested',
          sub: 'Confirmed working on all floors',
          value: _smokeAlarms,
          color: p.green,
          onChanged: (v) => setState(() => _smokeAlarms = v),
          p: p,
        ),
        Divider(height: 20, color: p.border),
        _CheckRow(
          label: 'CO detector tested',
          sub: 'Carbon monoxide alarm confirmed working',
          value: _coAlarms,
          color: p.green,
          onChanged: (v) => setState(() => _coAlarms = v),
          p: p,
        ),
        Divider(height: 20, color: p.border),
        TextField(
          controller: _alarmNotesCtrl,
          style: TextStyle(color: p.text, fontSize: 13),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Safety notes — battery replacements, alarm locations, any issues observed…',
            hintStyle: TextStyle(color: p.muted, fontSize: 13),
            border: InputBorder.none,
            isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.amber.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.amber.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: p.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'If smoke or CO alarms are not fitted, you must install them before the tenancy begins. Keep a record of the make, model, and test date for your files.',
            style: TextStyle(color: p.sub, fontSize: 12, height: 1.55),
          )),
        ]),
      ),
    ],
  );

  Widget _buildDesktopMeters(AbodePalette p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      _SectionHeader(p: p, icon: Icons.speed_outlined, label: 'Meter Readings'),
      const SizedBox(height: 12),
      _buildGuidanceCard(p,
        'Record meter readings on the exact day the tenancy begins. This protects tenants from being billed for previous usage and provides a clear baseline for final bills at check-out. Take photos of each meter display alongside this form. Provide readings to all utility suppliers within 48 hours.'),
      const SizedBox(height: 16),
      _InfoCard(p: p, children: [
        _MeterRow(label: 'Gas (m³)', ctrl: _gasCtrl,
            icon: Icons.local_fire_department_outlined, color: p.amber, p: p),
        Divider(height: 20, color: p.border),
        _MeterRow(label: 'Electricity (kWh)', ctrl: _elecCtrl,
            icon: Icons.bolt_outlined, color: p.blue, p: p),
        Divider(height: 20, color: p.border),
        _MeterRow(label: 'Water (m³)', ctrl: _waterCtrl,
            icon: Icons.water_drop_outlined, color: const Color(0xFF38BDF8), p: p),
      ]),
      const SizedBox(height: 12),
      Text(
        'Tip: photograph the meter display alongside the reading. MPAN/MPRN numbers are usually on bills or the meter itself.',
        style: TextStyle(color: p.muted, fontSize: 11, height: 1.5),
      ),
    ],
  );

  Widget _buildDesktopKeys(AbodePalette p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      _SectionHeader(p: p, icon: Icons.vpn_key_outlined, label: 'Keys & Access'),
      const SizedBox(height: 12),
      _buildGuidanceCard(p,
        "Record every key, fob, and access item handed to the tenant. Both parties should verbally confirm the count before signing this report. Lost or unreturned keys at the end of the tenancy may result in replacement costs being deducted from the deposit — this record is your evidence."),
      const SizedBox(height: 16),
      _InfoCard(p: p, children: [
        _CounterRow(label: 'Key sets', value: _keySets, p: p,
          onDec: () => setState(() => _keySets = (_keySets - 1).clamp(0, 20)),
          onInc: () => setState(() => _keySets++)),
        Divider(height: 20, color: p.border),
        _CounterRow(label: 'Key fobs / entry cards', value: _keyFobs, p: p,
          onDec: () => setState(() => _keyFobs = (_keyFobs - 1).clamp(0, 20)),
          onInc: () => setState(() => _keyFobs++)),
        Divider(height: 20, color: p.border),
        _CounterRow(label: 'Parking permits', value: _keyParking, p: p,
          onDec: () => setState(() => _keyParking = (_keyParking - 1).clamp(0, 10)),
          onInc: () => setState(() => _keyParking++)),
      ]),
    ],
  );

  Widget _buildDesktopNotes(AbodePalette p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      _SectionHeader(p: p, icon: Icons.note_outlined, label: 'Additional Notes'),
      const SizedBox(height: 12),
      _buildGuidanceCard(p,
        'Use this section for any verbal agreements reached during the handover, known pre-existing issues (e.g. scuffs, marks, garden state), items remaining at the property, or anything both parties have acknowledged. This section forms part of the legal record and may be referenced in any tenancy dispute.'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border)),
        child: TextField(
          controller: _notesCtrl,
          style: TextStyle(color: p.text, fontSize: 13),
          maxLines: 8,
          decoration: InputDecoration(
            hintText: 'e.g. "Tenant confirmed existing scuff on hallway wall. Garden shed contents to be removed by landlord by 20 June 2026. Tenant requested spare key to be cut — agreed within 7 days."',
            hintStyle: TextStyle(color: p.muted, fontSize: 12),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ),
    ],
  );

  Widget _buildDesktopActionBar(AbodePalette p) {
    final filledMeterCount = [_gasCtrl, _elecCtrl, _waterCtrl]
        .where((c) => c.text.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        Text(
          '${_included.length} room${_included.length == 1 ? '' : 's'} · $filledMeterCount meter reading${filledMeterCount == 1 ? '' : 's'} · $_keySets key set${_keySets == 1 ? '' : 's'}',
          style: TextStyle(color: p.muted, fontSize: 12)),
        const Spacer(),
        GestureDetector(
          onTap: () { HapticFeedback.mediumImpact(); setState(() => _summaryMode = true); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              color: p.blue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: p.blue.withValues(alpha: 0.3),
                blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Row(children: [
              Icon(Icons.summarize_outlined, color: Colors.white, size: 17),
              SizedBox(width: 8),
              Text('Review & Save Report',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── MOBILE FORM ───────────────────────────────────────────────────────────
  Widget _buildMobileForm(AbodePalette p) {
    return Column(children: [
      _Header(
        p: p,
        title: 'Property Inspection',
        sub: widget.tenancy.shortAddress,
        onBack: () => Navigator.pop(context),
        trailing: _TypeToggleBar(
          type: _type,
          onChanged: (t) => setState(() => _type = t),
          p: p,
        ),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [

          // Date + type
          _InfoCard(p: p, children: [
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 15, color: p.blue),
              const SizedBox(width: 10),
              Text(_type == _ReportType.checkIn ? 'Check-In Report' : 'Check-Out Report',
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: TextStyle(color: p.sub, fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 20),

          // ── Rooms ──────────────────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.door_front_door_outlined, label: 'Rooms & Condition'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _rooms.map((r) => GestureDetector(
              onTap: () => setState(() => r.included = !r.included),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: r.included ? p.blue.withValues(alpha: 0.12) : p.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: r.included ? p.blue.withValues(alpha: 0.4) : p.border)),
                child: Text(r.name, style: TextStyle(
                  color: r.included ? p.blue : p.sub,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          ...List.generate(_included.length, (i) => _RoomCard(
            room: _included[i],
            index: i,
            uploading: _uploading[i] ?? false,
            onPickPhoto: () => _pickPhoto(i),
            onChanged: () => setState(() {}),
            p: p,
          )),
          const SizedBox(height: 20),

          // ── Overall cleanliness ────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.cleaning_services_outlined, label: 'Overall Cleanliness'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            _CleanlinessSelector(
              value: _cleanlinessOverall,
              onChanged: (v) => setState(() => _cleanlinessOverall = v),
              p: p,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Safety checks ──────────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.security_outlined, label: 'Safety Checks'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            _CheckRow(
              label: 'Smoke alarms tested',
              sub: 'All alarms functional',
              value: _smokeAlarms,
              color: p.green,
              onChanged: (v) => setState(() => _smokeAlarms = v),
              p: p,
            ),
            Divider(height: 20, color: p.border),
            _CheckRow(
              label: 'CO detector tested',
              sub: 'Carbon monoxide alarm working',
              value: _coAlarms,
              color: p.green,
              onChanged: (v) => setState(() => _coAlarms = v),
              p: p,
            ),
            Divider(height: 20, color: p.border),
            TextField(
              controller: _alarmNotesCtrl,
              style: TextStyle(color: p.text, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Safety notes (battery replacements, locations…)',
                hintStyle: TextStyle(color: p.muted, fontSize: 13),
                border: InputBorder.none,
                isDense: true, contentPadding: EdgeInsets.zero),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Meter readings ─────────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.speed_outlined, label: 'Meter Readings'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            _MeterRow(label: 'Gas (m³)', ctrl: _gasCtrl,
                icon: Icons.local_fire_department_outlined, color: p.amber, p: p),
            Divider(height: 20, color: p.border),
            _MeterRow(label: 'Electricity (kWh)', ctrl: _elecCtrl,
                icon: Icons.bolt_outlined, color: p.blue, p: p),
            Divider(height: 20, color: p.border),
            _MeterRow(label: 'Water (m³)', ctrl: _waterCtrl,
                icon: Icons.water_drop_outlined, color: const Color(0xFF38BDF8), p: p),
          ]),
          const SizedBox(height: 20),

          // ── Keys & access ──────────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.vpn_key_outlined, label: 'Keys & Access'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            _CounterRow(label: 'Key sets', value: _keySets, p: p,
              onDec: () => setState(() => _keySets = (_keySets - 1).clamp(0, 20)),
              onInc: () => setState(() => _keySets++)),
            Divider(height: 20, color: p.border),
            _CounterRow(label: 'Key fobs / cards', value: _keyFobs, p: p,
              onDec: () => setState(() => _keyFobs = (_keyFobs - 1).clamp(0, 20)),
              onInc: () => setState(() => _keyFobs++)),
            Divider(height: 20, color: p.border),
            _CounterRow(label: 'Parking permits', value: _keyParking, p: p,
              onDec: () => setState(() => _keyParking = (_keyParking - 1).clamp(0, 10)),
              onInc: () => setState(() => _keyParking++)),
          ]),
          const SizedBox(height: 20),

          // ── Additional notes ───────────────────────────────────────────────
          _SectionHeader(p: p, icon: Icons.note_outlined, label: 'Additional Notes'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border)),
            child: TextField(
              controller: _notesCtrl,
              style: TextStyle(color: p.text, fontSize: 13),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Any additional observations, agreements, or notes…',
                hintStyle: TextStyle(color: p.muted, fontSize: 13),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 28),

          GestureDetector(
            onTap: () { HapticFeedback.mediumImpact(); setState(() => _summaryMode = true); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: p.blue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: p.blue.withValues(alpha: 0.3),
                    blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.summarize_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Review & Save Report',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      )),
    ]);
  }

  // ─── SUMMARY ───────────────────────────────────────────────────────────────
  Widget _buildSummary(AbodePalette p, bool isDesktop) {
    final typeLabel = _type == _ReportType.checkIn ? 'Check-In' : 'Check-Out';
    final issues    = _included.where((r) => r.condition >= 2).toList();
    final photoCount = _included.fold(0, (sum, r) => sum + r.photoUrls.length);

    final summaryList = ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Type + date badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_type == _ReportType.checkIn ? p.green : p.amber).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: (_type == _ReportType.checkIn ? p.green : p.amber).withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_type == _ReportType.checkIn ? Icons.login_outlined : Icons.logout_outlined,
                  color: _type == _ReportType.checkIn ? p.green : p.amber, size: 14),
              const SizedBox(width: 6),
              Text(typeLabel.toUpperCase(),
                  style: TextStyle(
                      color: _type == _ReportType.checkIn ? p.green : p.amber,
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ]),
          ),
          const Spacer(),
          Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(color: p.sub, fontSize: 13)),
        ]),
        const SizedBox(height: 16),

        // Overall score card
        _InfoCard(p: p, children: [
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: (issues.isEmpty ? p.green : p.amber).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(issues.isEmpty ? Icons.check_circle_outline : Icons.info_outline,
                  color: issues.isEmpty ? p.green : p.amber, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  issues.isEmpty ? 'All areas in good condition' : '${issues.length} area${issues.length == 1 ? "" : "s"} to note',
                  style: TextStyle(
                      color: issues.isEmpty ? p.green : p.amber,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${_included.length} rooms · $_keySets key set${_keySets == 1 ? "" : "s"} · $photoCount photo${photoCount == 1 ? "" : "s"}',
                  style: TextStyle(color: p.sub, fontSize: 12)),
            ])),
          ]),
        ]),
        const SizedBox(height: 20),

        // Room conditions
        _SectionHeader(p: p, icon: Icons.door_front_door_outlined, label: 'Room Conditions'),
        const SizedBox(height: 10),
        ..._included.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InfoCard(p: p, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _conditionColors[r.condition].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(_conditionIcons[r.condition],
                    color: _conditionColors[r.condition], size: 16)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
                if (r.notes.isNotEmpty)
                  Text(r.notes, style: TextStyle(color: p.sub, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_conditionLabels[r.condition],
                    style: TextStyle(color: _conditionColors[r.condition],
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (r.photoUrls.isNotEmpty)
                  Text('${r.photoUrls.length} photo${r.photoUrls.length == 1 ? "" : "s"}',
                      style: TextStyle(color: p.muted, fontSize: 10)),
              ]),
            ]),
            if (r.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(r.photoUrls[i],
                        width: 60, height: 60, fit: BoxFit.cover)),
                ),
              ),
            ],
          ]),
        )),
        const SizedBox(height: 20),

        // Safety checks
        _SectionHeader(p: p, icon: Icons.security_outlined, label: 'Safety Checks'),
        const SizedBox(height: 10),
        _InfoCard(p: p, children: [
          _SummaryBool(label: 'Smoke alarms tested', value: _smokeAlarms, p: p),
          Divider(height: 16, color: p.border),
          _SummaryBool(label: 'CO detector tested', value: _coAlarms, p: p),
        ]),
        const SizedBox(height: 20),

        // Meters
        if (_gasCtrl.text.isNotEmpty || _elecCtrl.text.isNotEmpty || _waterCtrl.text.isNotEmpty) ...[
          _SectionHeader(p: p, icon: Icons.speed_outlined, label: 'Meter Readings'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            if (_gasCtrl.text.isNotEmpty)
              _SummaryRow(label: 'Gas', value: '${_gasCtrl.text} m³',
                  icon: Icons.local_fire_department_outlined, color: p.amber, p: p),
            if (_elecCtrl.text.isNotEmpty) ...[
              if (_gasCtrl.text.isNotEmpty) Divider(height: 16, color: p.border),
              _SummaryRow(label: 'Electricity', value: '${_elecCtrl.text} kWh',
                  icon: Icons.bolt_outlined, color: p.blue, p: p),
            ],
            if (_waterCtrl.text.isNotEmpty) ...[
              Divider(height: 16, color: p.border),
              _SummaryRow(label: 'Water', value: '${_waterCtrl.text} m³',
                  icon: Icons.water_drop_outlined, color: const Color(0xFF38BDF8), p: p),
            ],
          ]),
          const SizedBox(height: 20),
        ],

        // Keys
        _SectionHeader(p: p, icon: Icons.vpn_key_outlined, label: 'Keys Handed Over'),
        const SizedBox(height: 10),
        _InfoCard(p: p, children: [
          _SummaryRow(label: 'Key sets', value: '$_keySets',
              icon: Icons.vpn_key_outlined, color: p.sub, p: p),
          if (_keyFobs > 0) ...[
            Divider(height: 16, color: p.border),
            _SummaryRow(label: 'Key fobs', value: '$_keyFobs',
                icon: Icons.contactless_outlined, color: p.sub, p: p),
          ],
          if (_keyParking > 0) ...[
            Divider(height: 16, color: p.border),
            _SummaryRow(label: 'Parking permits', value: '$_keyParking',
                icon: Icons.local_parking_outlined, color: p.sub, p: p),
          ],
        ]),
        const SizedBox(height: 20),

        // Notes
        if (_notesCtrl.text.trim().isNotEmpty) ...[
          _SectionHeader(p: p, icon: Icons.note_outlined, label: 'Notes'),
          const SizedBox(height: 10),
          _InfoCard(p: p, children: [
            Text(_notesCtrl.text, style: TextStyle(color: p.text, fontSize: 13, height: 1.5)),
          ]),
          const SizedBox(height: 20),
        ],

        // Actions
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _summaryMode = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.edit_outlined, color: p.sub, size: 16),
                const SizedBox(width: 6),
                Text('Edit', style: TextStyle(color: p.sub, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: p.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: p.green.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 3))]),
              child: _saving
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.save_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Save Report', style: TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
            ),
          )),
        ]),
      ],
    );

    return Column(children: [
      _Header(
        p: p,
        title: '$typeLabel Report',
        sub: widget.tenancy.shortAddress,
        onBack: () => setState(() => _summaryMode = false),
        trailing: GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: p.green, borderRadius: BorderRadius.circular(8)),
            child: _saving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      Expanded(
        child: isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: summaryList,
                ),
              )
            : summaryList,
      ),
    ]);
  }
}

// ─── Desktop sidebar nav item ─────────────────────────────────────────────────
class _SidebarSectionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool active;
  final AbodePalette p;
  final VoidCallback onTap;
  const _SidebarSectionItem({
    required this.icon,
    required this.label,
    required this.status,
    required this.active,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: active ? p.blue.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: p.blue.withValues(alpha: 0.22)) : null,
      ),
      child: Row(children: [
        Icon(icon, size: 17, color: active ? p.blue : p.muted),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
            color: active ? p.blue : p.text,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          )),
          Text(status, style: TextStyle(color: p.muted, fontSize: 11)),
        ])),
        if (active)
          Icon(Icons.chevron_right_rounded, color: p.blue, size: 16),
      ]),
    ),
  );
}

// ─── Room card ────────────────────────────────────────────────────────────────
class _RoomCard extends StatefulWidget {
  final _RoomItem room;
  final int index;
  final bool uploading;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;
  final AbodePalette p;
  const _RoomCard({
    required this.room, required this.index, required this.uploading,
    required this.onPickPhoto, required this.onChanged, required this.p,
  });
  @override State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _expanded = false;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.room.notes);
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final r = widget.room;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Text(r.name,
                    style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600))),
                Row(children: List.generate(4, (i) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => r.condition = i);
                    widget.onChanged();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(left: 5),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: r.condition == i
                          ? _conditionColors[i].withValues(alpha: 0.2)
                          : p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: r.condition == i
                              ? _conditionColors[i].withValues(alpha: 0.5)
                              : p.border)),
                    child: Icon(_conditionIcons[i], size: 14,
                        color: r.condition == i ? _conditionColors[i] : p.muted),
                  ),
                ))),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: p.muted, size: 18),
              ]),
            ),
          ),

          if (_expanded) Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(children: [
                Text('Cleanliness:', style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _CleanlinessSelector(value: r.cleanliness,
                    onChanged: (v) { setState(() => r.cleanliness = v); widget.onChanged(); },
                    p: p, compact: true),
              ]),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border)),
                child: TextField(
                  controller: _notesCtrl,
                  onChanged: (v) { r.notes = v; widget.onChanged(); },
                  style: TextStyle(color: p.text, fontSize: 13),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Notes for this room…',
                    hintStyle: TextStyle(color: p.muted, fontSize: 12),
                    contentPadding: const EdgeInsets.all(10),
                    border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 10),

              if (r.appliances.isNotEmpty) ...[
                Text('Appliances & fixtures',
                    style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...r.appliances.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => setState(() => a.working = !a.working),
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: a.working ? p.green.withValues(alpha: 0.15) : p.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: a.working ? p.green.withValues(alpha: 0.4) : p.red.withValues(alpha: 0.4))),
                        child: Icon(a.working ? Icons.check : Icons.close,
                            size: 12, color: a.working ? p.green : p.red)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.name,
                        style: TextStyle(color: a.working ? p.text : p.muted, fontSize: 12))),
                    if (!a.working)
                      Text('Not working', style: TextStyle(color: p.red, fontSize: 11)),
                  ]),
                )),
                const SizedBox(height: 6),
              ],

              Row(children: [
                Text('${r.photoUrls.length} photo${r.photoUrls.length == 1 ? "" : "s"}',
                    style: TextStyle(color: p.sub, fontSize: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.uploading ? null : widget.onPickPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.blue.withValues(alpha: 0.25))),
                    child: widget.uploading
                        ? SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(color: p.blue, strokeWidth: 1.5))
                        : Row(children: [
                            Icon(Icons.add_a_photo_outlined, size: 13, color: p.blue),
                            const SizedBox(width: 5),
                            Text('Add photos', style: TextStyle(color: p.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                  ),
                ),
              ]),

              if (r.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: r.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(r.photoUrls[i],
                            width: 72, height: 72, fit: BoxFit.cover)),
                      Positioned(top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => r.photoUrls.removeAt(i)),
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 11)),
                        )),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AbodePalette p;
  final String title, sub;
  final VoidCallback onBack;
  final Widget? trailing;
  const _Header({required this.p, required this.title, required this.sub,
      required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: p.surface,
      border: Border(bottom: BorderSide(color: p.border))),
    child: Row(children: [
      GestureDetector(
        onTap: onBack,
        child: Icon(Icons.arrow_back_ios_new_rounded, color: p.sub, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
        Text(sub, style: TextStyle(color: p.sub, fontSize: 12), overflow: TextOverflow.ellipsis),
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class _TypeToggleBar extends StatelessWidget {
  final _ReportType type;
  final ValueChanged<_ReportType> onChanged;
  final AbodePalette p;
  const _TypeToggleBar({required this.type, required this.onChanged, required this.p});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: p.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _Tab(label: 'Check-In',  active: type == _ReportType.checkIn,
          onTap: () => onChanged(_ReportType.checkIn), p: p),
      _Tab(label: 'Check-Out', active: type == _ReportType.checkOut,
          onTap: () => onChanged(_ReportType.checkOut), p: p),
    ]),
  );
}

class _Tab extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap; final AbodePalette p;
  const _Tab({required this.label, required this.active, required this.onTap, required this.p});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? p.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(
          color: active ? Colors.white : p.sub,
          fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final AbodePalette p; final IconData icon; final String label;
  const _SectionHeader({required this.p, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: p.blue), const SizedBox(width: 8),
    Text(label, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
  ]);
}

class _InfoCard extends StatelessWidget {
  final AbodePalette p; final List<Widget> children;
  const _InfoCard({required this.p, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _MeterRow extends StatelessWidget {
  final String label; final TextEditingController ctrl;
  final IconData icon; final Color color; final AbodePalette p;
  const _MeterRow({required this.label, required this.ctrl,
      required this.icon, required this.color, required this.p});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color), const SizedBox(width: 10),
    Expanded(child: Text(label, style: TextStyle(color: p.sub, fontSize: 13))),
    SizedBox(width: 110, child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '—', hintStyle: TextStyle(color: p.muted),
        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
    )),
  ]);
}

class _CounterRow extends StatelessWidget {
  final String label; final int value; final AbodePalette p;
  final VoidCallback onDec, onInc;
  const _CounterRow({required this.label, required this.value, required this.p,
      required this.onDec, required this.onInc});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(color: p.sub, fontSize: 13))),
    GestureDetector(onTap: onDec,
      child: Container(width: 30, height: 30,
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border)),
        child: Icon(Icons.remove, color: p.sub, size: 14))),
    SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center,
        style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700))),
    GestureDetector(onTap: onInc,
      child: Container(width: 30, height: 30,
        decoration: BoxDecoration(
            color: p.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.blue.withValues(alpha: 0.3))),
        child: Icon(Icons.add, color: p.blue, size: 14))),
  ]);
}

class _CheckRow extends StatelessWidget {
  final String label, sub; final bool value; final Color color;
  final ValueChanged<bool> onChanged; final AbodePalette p;
  const _CheckRow({required this.label, required this.sub, required this.value,
      required this.color, required this.onChanged, required this.p});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w500)),
      Text(sub, style: TextStyle(color: p.muted, fontSize: 11)),
    ])),
    GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44, height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? color : p.border,
          borderRadius: BorderRadius.circular(13)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 22, height: 22,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
      ),
    ),
  ]);
}

class _CleanlinessSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final AbodePalette p;
  final bool compact;
  const _CleanlinessSelector({required this.value, required this.onChanged,
      required this.p, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const options = [
      ('clean',            'Clean',     Color(0xFF22C55E)),
      ('needs_attention',  'Attention', Color(0xFFFBBF24)),
      ('dirty',            'Dirty',     Color(0xFFEF4444)),
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: options.map((o) {
      final selected = value == o.$1;
      return GestureDetector(
        onTap: () => onChanged(o.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(right: 6),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
          decoration: BoxDecoration(
            color: selected ? o.$3.withValues(alpha: 0.15) : p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? o.$3.withValues(alpha: 0.4) : p.border,
                width: selected ? 1.5 : 1)),
          child: Text(o.$2, style: TextStyle(
              color: selected ? o.$3 : p.muted,
              fontSize: compact ? 11 : 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList());
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final AbodePalette p;
  const _SummaryRow({required this.label, required this.value,
      required this.icon, required this.color, required this.p});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color), const SizedBox(width: 8),
    Text(label, style: TextStyle(color: p.sub, fontSize: 13)),
    const Spacer(),
    Text(value, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}

class _SummaryBool extends StatelessWidget {
  final String label; final bool value; final AbodePalette p;
  const _SummaryBool({required this.label, required this.value, required this.p});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(value ? Icons.check_circle_outline : Icons.cancel_outlined,
        size: 16, color: value ? p.green : p.red),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(color: p.text, fontSize: 13))),
    Text(value ? 'Tested ✓' : 'Not tested',
        style: TextStyle(color: value ? p.green : p.red,
            fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

// ─── Check-In Mode Selector ───────────────────────────────────────────────────
class _CheckInModeSheet extends StatefulWidget {
  final Tenancy tenancy;
  final BuildContext rootContext;
  const _CheckInModeSheet({required this.tenancy, required this.rootContext});
  @override
  State<_CheckInModeSheet> createState() => _CheckInModeSheetState();
}

class _CheckInModeSheetState extends State<_CheckInModeSheet> {
  int _step = 0;
  _CIMethod? _method;
  _AccessMethod? _access;
  final _lockboxCtrl = TextEditingController();

  @override
  void dispose() { _lockboxCtrl.dispose(); super.dispose(); }

  AbodePalette get p => AbodePalette.of(context);

  bool get _step0Valid => _method != null;
  bool get _step1Valid =>
      _access != null &&
      (_access != _AccessMethod.lockbox || _lockboxCtrl.text.trim().isNotEmpty);

  String get _ctaLabel {
    if (_step == 0) return 'Continue';
    return switch (_method!) {
      _CIMethod.self       => 'Start Check-In',
      _CIMethod.ownPerson  => 'Generate Link',
      _CIMethod.aiic       => 'Request a Clerk',
      _CIMethod.noLettingGo => 'Request a Clerk',
    };
  }

  void _proceed() {
    if (_step == 0) { setState(() => _step = 1); return; }
    final nav = Navigator.of(widget.rootContext);
    Navigator.of(context).pop();
    switch (_method!) {
      case _CIMethod.self:
        nav.push(MaterialPageRoute(
          builder: (_) => _InspectionScreen(tenancy: widget.tenancy),
          fullscreenDialog: true,
        ));
      case _CIMethod.aiic:
      case _CIMethod.noLettingGo:
        nav.push(MaterialPageRoute(
          builder: (_) => _PartnerBookingScreen(
            tenancy: widget.tenancy,
            partner: _method == _CIMethod.aiic ? 'aiic' : 'no_letting_go',
            accessMethod: _access!,
            lockboxCode: _access == _AccessMethod.lockbox
                ? _lockboxCtrl.text.trim()
                : null,
          ),
          fullscreenDialog: true,
        ));
      case _CIMethod.ownPerson:
        showAdaptiveSheet(
          context: widget.rootContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ShareLinkSheet(tenancy: widget.tenancy),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == 0 ? 0.85 : 0.68,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: p.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              if (_step == 1)
                GestureDetector(
                  onTap: () => setState(() => _step = 0),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.card, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border)),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: p.sub),
                  ),
                ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _step == 0
                      ? 'How would you like to check in?'
                      : 'How does the clerk access the property?',
                  style: TextStyle(
                    color: p.text, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                if (_step == 0)
                  Text('This helps us create a legally robust record',
                    style: TextStyle(color: p.sub, fontSize: 12)),
              ])),
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
          Expanded(child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: _step == 0 ? _buildMethodStep() : _buildAccessStep(),
          )),
          // CTA
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: (_step == 0 ? _step0Valid : _step1Valid) ? _proceed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  disabledBackgroundColor:
                      const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: Text(_ctaLabel),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildMethodStep() => [
    _MethodCard(
      icon: Icons.person_outline_rounded,
      iconColor: const Color(0xFF3B82F6),
      title: 'Do it yourself',
      subtitle: 'You complete the Abode report directly on your device — guided step by step.',
      tags: const ['Free', 'Instant'],
      selected: _method == _CIMethod.self,
      onTap: () => setState(() => _method = _CIMethod.self),
      p: p,
    ),
    const SizedBox(height: 10),
    _MethodCard(
      icon: Icons.business_center_outlined,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Book a professional clerk',
      subtitle: 'An AIIC-accredited clerk attends and produces a legally robust signed inventory — the strongest evidence in a deposit dispute.',
      tags: const ['Recommended', 'Most defensible'],
      tagColors: const [Color(0xFF8B5CF6), Color(0xFF22C55E)],
      selected: _method == _CIMethod.aiic || _method == _CIMethod.noLettingGo,
      onTap: () => setState(() {
        if (_method != _CIMethod.aiic && _method != _CIMethod.noLettingGo) {
          _method = _CIMethod.aiic;
        }
      }),
      p: p,
      child: (_method == _CIMethod.aiic || _method == _CIMethod.noLettingGo)
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                _PartnerChip(
                  label: 'AIIC Clerk',
                  sub: 'Accredited & independent',
                  selected: _method == _CIMethod.aiic,
                  onTap: () => setState(() => _method = _CIMethod.aiic),
                  color: const Color(0xFF8B5CF6),
                  p: p,
                ),
                const SizedBox(width: 8),
                _PartnerChip(
                  label: 'No Letting Go',
                  sub: 'National clerk network',
                  selected: _method == _CIMethod.noLettingGo,
                  onTap: () => setState(() => _method = _CIMethod.noLettingGo),
                  color: const Color(0xFF3B82F6),
                  p: p,
                ),
              ]),
            )
          : null,
    ),
    const SizedBox(height: 10),
    _MethodCard(
      icon: Icons.share_outlined,
      iconColor: const Color(0xFF22C55E),
      title: 'Send your own person',
      subtitle: 'Generate a secure link for your estate agent, letting agent, or any trusted contact — no Abode account needed.',
      tags: const ['Free', 'Link expires in 7 days'],
      selected: _method == _CIMethod.ownPerson,
      onTap: () => setState(() => _method = _CIMethod.ownPerson),
      p: p,
    ),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.amber.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 13, color: p.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Self-conducted inventories are legally valid but carry more risk in deposit disputes. A professional clerk provides an independent, timestamped record that deposit scheme adjudicators weigh more heavily.',
          style: TextStyle(color: p.sub, fontSize: 11, height: 1.5),
        )),
      ]),
    ),
    const SizedBox(height: 8),
  ];

  List<Widget> _buildAccessStep() => [
    _AccessCard(
      icon: Icons.person_pin_outlined,
      title: "I'll be there in person",
      subtitle: 'Keys handed over face to face',
      selected: _access == _AccessMethod.landlordPresent,
      onTap: () => setState(() => _access = _AccessMethod.landlordPresent),
      p: p,
    ),
    const SizedBox(height: 8),
    _AccessCard(
      icon: Icons.lock_outline_rounded,
      title: 'Lockbox / key safe',
      subtitle: 'Code stored securely and shared via Abode',
      selected: _access == _AccessMethod.lockbox,
      onTap: () => setState(() => _access = _AccessMethod.lockbox),
      p: p,
      child: _access == _AccessMethod.lockbox
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _lockboxCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: p.text, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 3),
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  hintStyle: TextStyle(
                    color: p.muted, fontSize: 13,
                    letterSpacing: 0, fontWeight: FontWeight.w400),
                  filled: true, fillColor: p.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: p.border)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF3B82F6), width: 1.5)),
                ),
              ),
            )
          : null,
    ),
    const SizedBox(height: 8),
    _AccessCard(
      icon: Icons.business_outlined,
      title: 'Keys via letting agent',
      subtitle: 'Agent holds and releases the keys',
      selected: _access == _AccessMethod.agentKeys,
      onTap: () => setState(() => _access = _AccessMethod.agentKeys),
      p: p,
    ),
    const SizedBox(height: 8),
  ];
}

// ─── Method selection card ────────────────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final List<String> tags;
  final List<Color>? tagColors;
  final bool selected;
  final VoidCallback onTap;
  final AbodePalette p;
  final Widget? child;
  const _MethodCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.tags, this.tagColors,
    required this.selected, required this.onTap,
    required this.p, this.child,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? iconColor.withValues(alpha: 0.05) : p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? iconColor.withValues(alpha: 0.4) : p.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: selected ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
              color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(
              color: p.sub, fontSize: 12, height: 1.4)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: List.generate(tags.length, (i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (tagColors?[i] ?? iconColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(tags[i], style: TextStyle(
                color: tagColors?[i] ?? iconColor,
                fontSize: 10, fontWeight: FontWeight.w700)),
            ))),
          ])),
          if (selected)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
            ),
        ]),
        if (child != null) child!,
      ]),
    ),
  );
}

// ─── Partner sub-chip ─────────────────────────────────────────────────────────
class _PartnerChip extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final AbodePalette p;
  const _PartnerChip({
    required this.label, required this.sub,
    required this.selected, required this.onTap,
    required this.color, required this.p,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : p.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : p.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
            color: selected ? color : p.text,
            fontSize: 12, fontWeight: FontWeight.w700)),
          Text(sub, style: TextStyle(color: p.muted, fontSize: 10)),
        ]),
      ),
    ),
  );
}

// ─── Access method card ───────────────────────────────────────────────────────
class _AccessCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final AbodePalette p;
  final Widget? child;
  final bool disabled;
  const _AccessCard({
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.onTap, required this.p,
    this.child, this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: disabled
              ? p.bg
              : selected
                  ? accent.withValues(alpha: 0.05)
                  : p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? p.border.withValues(alpha: 0.5)
                : selected
                    ? accent.withValues(alpha: 0.4)
                    : p.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18,
              color: disabled ? p.muted : selected ? accent : p.sub),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                color: disabled ? p.muted : p.text,
                fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(
                color: disabled ? p.muted : p.sub, fontSize: 11)),
            ])),
            if (disabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.border, borderRadius: BorderRadius.circular(20)),
                child: Text('Soon',
                    style: TextStyle(
                        color: p.muted, fontSize: 10, fontWeight: FontWeight.w600)),
              )
            else if (selected)
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              ),
          ]),
          if (child != null) child!,
        ]),
      ),
    );
  }
}

// ─── Partner Booking Screen ───────────────────────────────────────────────────
class _PartnerBookingScreen extends StatefulWidget {
  final Tenancy tenancy;
  final String partner;
  final _AccessMethod accessMethod;
  final String? lockboxCode;
  const _PartnerBookingScreen({
    required this.tenancy, required this.partner,
    required this.accessMethod, this.lockboxCode,
  });
  @override
  State<_PartnerBookingScreen> createState() => _PartnerBookingScreenState();
}

class _PartnerBookingScreenState extends State<_PartnerBookingScreen> {
  AbodePalette get p => AbodePalette.of(context);

  DateTime? _preferredDate;
  final _notesCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  String get _partnerLabel =>
      widget.partner == 'aiic' ? 'AIIC Accredited Clerk' : 'No Letting Go';
  String get _partnerSub => widget.partner == 'aiic'
      ? 'Association of Independent Inventory Clerks'
      : 'National inventory clerk franchise';
  Color get _partnerColor => widget.partner == 'aiic'
      ? const Color(0xFF8B5CF6)
      : const Color(0xFF3B82F6);

  String get _accessLabel => switch (widget.accessMethod) {
    _AccessMethod.landlordPresent => 'Landlord present',
    _AccessMethod.lockbox =>
        'Lockbox${widget.lockboxCode != null ? " — code provided" : ""}',
    _AccessMethod.agentKeys => 'Keys via letting agent',
    _AccessMethod.smartLock => 'Smart lock',
  };

  Future<void> _send() async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) setState(() { _sending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: p.bg,
      child: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.card, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border)),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: p.sub),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Book a Clerk',
                    style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(widget.tenancy.shortAddress,
                    style: TextStyle(color: p.sub, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          Expanded(
            child: _sent
                ? _buildSuccess()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildForm(),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildForm() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    children: [
      // Partner badge
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _partnerColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _partnerColor.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _partnerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.verified_outlined, color: _partnerColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_partnerLabel,
                style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(_partnerSub, style: TextStyle(color: p.sub, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
            child: const Text('AIIC Accredited',
                style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 24),

      // Property + access summary
      _CIBookingRow(
        icon: Icons.home_work_outlined,
        label: 'Property',
        value: widget.tenancy.shortAddress,
        p: p),
      const SizedBox(height: 12),
      _CIBookingRow(
        icon: Icons.vpn_key_outlined,
        label: 'Access',
        value: _accessLabel,
        p: p),
      if (widget.accessMethod == _AccessMethod.lockbox &&
          widget.lockboxCode != null) ...[
        const SizedBox(height: 12),
        _CIBookingRow(
          icon: Icons.lock_outlined,
          label: 'Lockbox code',
          value: widget.lockboxCode!,
          p: p,
          highlight: true),
      ],
      const SizedBox(height: 24),

      // Date picker
      Text('Preferred date',
          style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 2)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 90)),
          );
          if (date != null) setState(() => _preferredDate = date);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: p.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _preferredDate != null
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                  : p.border)),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 16,
              color: _preferredDate != null
                  ? const Color(0xFF3B82F6)
                  : p.muted),
            const SizedBox(width: 10),
            Text(
              _preferredDate != null
                  ? '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}'
                  : 'Select a date',
              style: TextStyle(
                color: _preferredDate != null ? p.text : p.muted,
                fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      // Notes
      Text('Notes for the clerk (optional)',
          style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border)),
        child: TextField(
          controller: _notesCtrl,
          style: TextStyle(color: p.text, fontSize: 13),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'e.g. "Please check the boiler room. Tenant moves in at 2pm."',
            hintStyle: TextStyle(color: p.muted, fontSize: 12),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ),
      const SizedBox(height: 24),

      // What happens next
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.blue.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What happens next',
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _CINextStep(num: '1', text: 'We send your request to $_partnerLabel', p: p),
          _CINextStep(num: '2', text: 'They contact you within 2 business hours to confirm', p: p),
          _CINextStep(num: '3', text: 'The clerk attends and produces a signed inventory', p: p),
          _CINextStep(num: '4', text: 'The completed report is attached to this tenancy in Abode', p: p),
        ]),
      ),
      const SizedBox(height: 28),

      SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: _preferredDate == null || _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: _partnerColor,
            disabledBackgroundColor: _partnerColor.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: _sending
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Request a Clerk from $_partnerLabel'),
        ),
      ),
    ],
  );

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF22C55E), size: 36),
        ),
        const SizedBox(height: 20),
        Text('Request sent!', style: TextStyle(
          color: p.text, fontSize: 22,
          fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const SizedBox(height: 8),
        Text(
          '$_partnerLabel will contact you within 2 business hours to confirm your booking at ${widget.tenancy.shortAddress}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );
}

// ─── Shareable Link Sheet ─────────────────────────────────────────────────────
class _ShareLinkSheet extends StatefulWidget {
  final Tenancy tenancy;
  const _ShareLinkSheet({required this.tenancy});
  @override
  State<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends State<_ShareLinkSheet> {
  AbodePalette get p => AbodePalette.of(context);
  bool _copied = false;
  late final String _link;

  @override
  void initState() {
    super.initState();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final token = List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
    _link = 'https://app.useabode.co.uk/inspect/$token';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75,
    maxChildSize: 0.92,
    minChildSize: 0.4,
    builder: (_, sc) => Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: p.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.share_outlined,
                  color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shareable check-in link',
                style: TextStyle(
                  color: p.text, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text(widget.tenancy.shortAddress,
                  style: TextStyle(color: p.sub, fontSize: 12)),
            ])),
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
        Expanded(child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Link card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Secure link',
                    style: TextStyle(
                        color: p.sub, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(
                    _link,
                    style: TextStyle(color: p.blue, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  )),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _copy,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _copied
                            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 13,
                          color: _copied
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(_copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            color: _copied
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF3B82F6),
                            fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            _ShareInfoRow(
              icon: Icons.timer_outlined, color: p.amber,
              title: 'Expires in 7 days',
              sub: 'The link stops working after 7 days or once the report is submitted.',
              p: p),
            const SizedBox(height: 8),
            _ShareInfoRow(
              icon: Icons.no_accounts_outlined, color: p.blue,
              title: 'No account needed',
              sub: 'Your contact opens the link on any device and fills in the Abode report — no sign-up required.',
              p: p),
            const SizedBox(height: 8),
            _ShareInfoRow(
              icon: Icons.lock_outline_rounded, color: const Color(0xFF22C55E),
              title: 'Secure & single-use',
              sub: 'The link can only be submitted once and is tied to this property only.',
              p: p),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.blue.withValues(alpha: 0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How to share',
                    style: TextStyle(
                        color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _CINextStep(num: '1', text: 'Copy the link above', p: p),
                _CINextStep(num: '2',
                    text: 'Send it to your person via WhatsApp, email, or text', p: p),
                _CINextStep(num: '3',
                    text: 'They open it on their phone at the property', p: p),
                _CINextStep(num: '4',
                    text: 'The completed report appears in your Abode dashboard automatically',
                    p: p),
              ]),
            ),
          ],
        )),
      ]),
    ),
  );
}

// ─── Shared helper widgets ────────────────────────────────────────────────────
class _CIBookingRow extends StatelessWidget {
  final IconData icon; final String label, value;
  final AbodePalette p; final bool highlight;
  const _CIBookingRow({
    required this.icon, required this.label,
    required this.value, required this.p, this.highlight = false,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: p.muted),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(color: p.sub, fontSize: 13)),
    const Spacer(),
    Text(value, style: TextStyle(
      color: highlight ? const Color(0xFF3B82F6) : p.text,
      fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}

class _CINextStep extends StatelessWidget {
  final String num, text; final AbodePalette p;
  const _CINextStep({required this.num, required this.text, required this.p});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          color: p.blue.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Center(child: Text(num,
            style: TextStyle(
                color: p.blue, fontSize: 10, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(color: p.sub, fontSize: 12, height: 1.4))),
    ]),
  );
}

class _ShareInfoRow extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, sub; final AbodePalette p;
  const _ShareInfoRow({
    required this.icon, required this.color,
    required this.title, required this.sub, required this.p,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: p.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: p.text, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: p.sub, fontSize: 11, height: 1.4)),
      ])),
    ]),
  );
}
