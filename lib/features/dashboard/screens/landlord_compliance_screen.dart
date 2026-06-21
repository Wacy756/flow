import 'package:file_picker/file_picker.dart';
import 'package:flow_app/core/widgets/abode_date_picker.dart';
import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/compliance_certificate.dart';
import '../models/pet_request.dart';
import '../models/rent_review.dart';
import '../models/section8_ground.dart';
import '../providers/agent_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// Landlord accent — blue (matches rest of landlord dashboard)
const _accent = Color(0xFF3B82F6);
const _green  = Color(0xFF22C55E);
const _amber  = Color(0xFFFBBF24);
const _red    = Color(0xFFEF4444);
const _purple = Color(0xFFA855F7); // kept for rent review increase indicator

enum _LCompTab { certificates, rentReviews, section8, pets }

class LandlordComplianceScreen extends ConsumerStatefulWidget {
  const LandlordComplianceScreen({super.key});

  @override
  ConsumerState<LandlordComplianceScreen> createState() =>
      _LandlordComplianceScreenState();
}

class _LandlordComplianceScreenState
    extends ConsumerState<LandlordComplianceScreen> {
  AbodePalette get p => AbodePalette.of(context);

  _LCompTab _tab = _LCompTab.certificates;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabRow(),
          const SizedBox(height: 4),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Text('Compliance',
                style: TextStyle(
                    color: p.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_tab != _LCompTab.pets) GestureDetector(
              onTap: () => _onAddTap(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: _accent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      switch (_tab) {
                        _LCompTab.certificates => 'Add Cert',
                        _LCompTab.rentReviews  => 'New Review',
                        _LCompTab.section8     => 'New Notice',
                        _LCompTab.pets         => '',
                      },
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildTabRow() {
    final certs   = ref.watch(landlordComplianceCertsProvider).valueOrNull ?? [];
    final reviews = ref.watch(landlordAllRentReviewsProvider).valueOrNull ?? [];
    final grounds = ref.watch(landlordAllSection8GroundsProvider).valueOrNull ?? [];
    final pets    = ref.watch(landlordPetRequestsProvider).valueOrNull ?? [];

    final certCount   = certs.length;
    final reviewCount = reviews.length;
    final s8Count     = grounds.length;
    final petCount    = pets.where((r) => r.isPending).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (final t in _LCompTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabChip(
                label: switch (t) {
                  _LCompTab.certificates => 'Certificates',
                  _LCompTab.rentReviews  => 'Rent Reviews',
                  _LCompTab.section8     => 'Section 8',
                  _LCompTab.pets         => 'Pet Requests',
                },
                count: switch (t) {
                  _LCompTab.certificates => certCount > 0 ? certCount : null,
                  _LCompTab.rentReviews  => reviewCount > 0 ? reviewCount : null,
                  _LCompTab.section8     => s8Count > 0 ? s8Count : null,
                  _LCompTab.pets         => petCount > 0 ? petCount : null,
                },
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() => switch (_tab) {
    _LCompTab.certificates => _CertsTab(onAdd: () => _onAddTap(context)),
    _LCompTab.rentReviews  => _RentReviewsTab(onAdd: () => _onAddTap(context)),
    _LCompTab.section8     => _Section8Tab(),
    _LCompTab.pets         => _PetsTab(),
  };

  void _onAddTap(BuildContext context) {
    switch (_tab) {
      case _LCompTab.certificates:
        _showAddCertSheet(context);
      case _LCompTab.rentReviews:
        _showCreateRentReviewSheet(context);
      case _LCompTab.section8:
        _showSection8Sheet(context);
      default:
        break;
    }
  }

  void _showSection8Sheet(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _Section8GroundSheet(onSaved: () {
        ref.invalidate(landlordAllSection8GroundsProvider);
      }),
    );
  }

  void _showAddCertSheet(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddCertSheet(onSaved: () {
        ref.invalidate(landlordComplianceCertsProvider);
      }),
    );
  }

  void _showCreateRentReviewSheet(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateRentReviewSheet(onSaved: () {
        ref.invalidate(landlordAllRentReviewsProvider);
        ref.invalidate(landlordTenanciesProvider);
      }),
    );
  }
}

// ─── Certificates Tab ─────────────────────────────────────────────────────────
class _CertsTab extends ConsumerWidget {
  final VoidCallback onAdd;
  const _CertsTab({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(landlordComplianceCertsProvider);
    return certsAsync.when(
      loading: () => const SkeletonCertList(),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (certs) {
        if (certs.isEmpty) {
          return _EmptyState(
            message: 'No certificates yet',
            subtitle: 'Gas Safety (CP12), EICR, and EPC are legally required for all rented properties. Add your first to start tracking.',
            icon: Icons.verified_outlined,
            actionLabel: 'Add Certificate',
            onAction: onAdd,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: certs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _CertCard(cert: certs[i]),
        );
      },
    );
  }
}

class _CertCard extends StatelessWidget {
  final ComplianceCertificate cert;
  const _CertCard({required this.cert});

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final statusColor = switch (cert.status) {
      'expired'       => _red,
      'expiring_soon' => _amber,
      'missing'       => _red,
      _               => _green,
    };
    final hasDoc = cert.documentUrl != null && cert.documentUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: cert.isExpired
                ? _red.withValues(alpha: 0.5)
                : cert.isExpiringSoon
                    ? _amber.withValues(alpha: 0.4)
                    : pal.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_certIcon(cert.certType),
                      color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cert.displayType,
                          style: TextStyle(
                              color: pal.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        'Expires ${fmt.format(cert.expiryDate)}'
                        '${cert.daysUntilExpiry >= 0 ? ' (${cert.daysUntilExpiry}d)' : ' (EXPIRED)'}',
                        style: TextStyle(
                            color: cert.isExpired
                                ? _red
                                : cert.isExpiringSoon
                                    ? _amber
                                    : pal.sub,
                            fontSize: 12),
                      ),
                      if (cert.certRef != null) ...[
                        const SizedBox(height: 2),
                        Text('Ref: ${cert.certRef}',
                            style: TextStyle(
                                color: pal.muted, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        cert.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4),
                      ),
                    ),
                    if (!hasDoc) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 11, color: pal.muted),
                        const SizedBox(width: 3),
                        Text('No doc',
                            style: TextStyle(
                                color: pal.muted, fontSize: 10)),
                      ]),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasDoc) ...[
            Container(height: 1, color: pal.border.withValues(alpha: 0.5)),
            GestureDetector(
              onTap: () => _openDoc(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Text('View certificate document',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.open_in_new_rounded,
                      size: 13, color: _accent),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDoc(BuildContext context) async {
    try {
      final signedUrl = await supabase.storage
          .from('compliance-docs')
          .createSignedUrl(cert.documentUrl!, 300); // 5-min link
      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        showAbodeToast(context, 'Could not open document', isError: true);
      }
    }
  }

  IconData _certIcon(String type) => switch (type) {
    'gas_safety'  => Icons.local_fire_department_outlined,
    'eicr'        => Icons.electrical_services_outlined,
    'epc'         => Icons.eco_outlined,
    'pat_test'    => Icons.power_outlined,
    'fire_risk'   => Icons.fire_extinguisher_outlined,
    'legionella'  => Icons.water_drop_outlined,
    _             => Icons.description_outlined,
  };
}

// ─── Add Cert Sheet ───────────────────────────────────────────────────────────
class _AddCertSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddCertSheet({required this.onSaved});

  @override
  ConsumerState<_AddCertSheet> createState() => _AddCertSheetState();
}

class _AddCertSheetState extends ConsumerState<_AddCertSheet> {
  AbodePalette get p => AbodePalette.of(context);

  String? _tenancyId;
  String   _certType   = 'gas_safety';
  DateTime _issuedDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  final _issuedByCtrl = TextEditingController();
  final _certRefCtrl  = TextEditingController();
  PlatformFile? _pickedFile;
  String? _certRefError;
  bool _saving = false;

  static const _certTypes = [
    ('gas_safety', 'Gas Safety (CP12)'),
    ('eicr',       'EICR'),
    ('epc',        'EPC'),
    ('pat_test',   'PAT Test'),
    ('fire_risk',  'Fire Risk'),
    ('legionella', 'Legionella'),
    ('other',      'Other'),
  ];

  // Per-type ref hints and required flag
  static const _certMeta = <String, (String hint, String format, bool required)>{
    'gas_safety': ('Gas Safe reg number (6 digits)', '6-digit number e.g. 123456', true),
    'eicr':       ('Report reference (e.g. EICR-2024-001)', 'e.g. EICR-2024-001', true),
    'epc':        ('EPC reference (e.g. 0000-0000-0000-0000-0000)', 'e.g. 0000-0000-0000-0000-0000', true),
    'pat_test':   ('PAT test ref (optional)', '', false),
    'fire_risk':  ('Report reference (optional)', '', false),
    'legionella': ('Assessment reference (optional)', '', false),
    'other':      ('Reference number (optional)', '', false),
  };

  String? _validateRef(String val) {
    final meta = _certMeta[_certType]!;
    if (!meta.$3) return null; // not required
    if (val.isEmpty) return 'Certificate reference is required for ${_certLabel(_certType)}';
    if (_certType == 'gas_safety' && !RegExp(r'^\d{6}$').hasMatch(val)) {
      return 'Gas Safe number must be exactly 6 digits';
    }
    if (val.length < 4) return 'Reference too short';
    return null;
  }

  String _certLabel(String type) => _certTypes
      .firstWhere((c) => c.$1 == type, orElse: () => (type, type))
      .$2;

  @override
  void dispose() {
    _issuedByCtrl.dispose();
    _certRefCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final pad  = MediaQuery.of(context).viewInsets.bottom;
    final meta = _certMeta[_certType]!;

    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Add Certificate',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Upload the actual certificate document — not just the dates.',
                  style: TextStyle(color: p.sub, fontSize: 12)),
              const SizedBox(height: 20),

              _SectionLabel('Property'),
              const SizedBox(height: 8),
              _TenancyDropdown(
                  tenanciesAsync: tenanciesAsync,
                  value: _tenancyId,
                  onChanged: (v) => setState(() => _tenancyId = v)),
              const SizedBox(height: 16),

              _SectionLabel('Certificate type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _certTypes
                    .map((c) => GestureDetector(
                          onTap: () => setState(() {
                            _certType = c.$1;
                            _certRefError = null;
                          }),
                          child: _SelectChip(
                            label: c.$2,
                            selected: _certType == c.$1,
                            color: _green,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Certificate document upload — required
              _SectionLabel('Certificate document *'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickFile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _pickedFile != null
                        ? _green.withValues(alpha: 0.07)
                        : p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _pickedFile != null
                          ? _green.withValues(alpha: 0.5)
                          : p.border,
                      width: _pickedFile != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _pickedFile != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: _pickedFile != null ? _green : p.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFile != null
                                ? _pickedFile!.name
                                : 'Upload certificate (PDF, JPG, PNG)',
                            style: TextStyle(
                              color: _pickedFile != null ? _green : p.sub,
                              fontSize: 13,
                              fontWeight: _pickedFile != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_pickedFile == null)
                            Text(
                              'Required — tap to choose file',
                              style: TextStyle(
                                  color: p.muted, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (_pickedFile != null)
                      GestureDetector(
                        onTap: () => setState(() => _pickedFile = null),
                        child: Icon(Icons.close_rounded,
                            color: p.muted, size: 16),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Cert ref — required for gas_safety/eicr/epc
              _SectionLabel(
                  '${_certLabel(_certType)} reference${meta.$3 ? ' *' : ' (optional)'}'),
              const SizedBox(height: 8),
              _DarkTextField(
                controller: _certRefCtrl,
                hint: meta.$1,
                onChanged: (v) => setState(() =>
                    _certRefError = _validateRef(v.trim())),
              ),
              if (_certRefError != null) ...[
                const SizedBox(height: 4),
                Text(_certRefError!,
                    style: const TextStyle(
                        color: _red, fontSize: 11)),
              ],
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Issued date'),
                      const SizedBox(height: 8),
                      _DatePickerTile(
                        date: _issuedDate,
                        onTap: () => _pickDate(context, isIssued: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Expiry date'),
                      const SizedBox(height: 8),
                      _DatePickerTile(
                        date: _expiryDate,
                        onTap: () => _pickDate(context, isIssued: false),
                        color: _expiryDate.difference(DateTime.now()).inDays < 90
                            ? _amber
                            : null,
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              _SectionLabel('Issued by (optional)'),
              const SizedBox(height: 8),
              _DarkTextField(
                  controller: _issuedByCtrl,
                  hint: 'Engineer or company name'),
              const SizedBox(height: 24),

              _SaveButton(
                label: 'Add Certificate',
                saving: _saving,
                color: _green,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _pickDate(BuildContext context,
      {required bool isIssued}) async {
    final initial = isIssued ? _issuedDate : _expiryDate;
    final picked = await showAbodeDatePicker(
      context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        if (isIssued) _issuedDate = picked;
        else          _expiryDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_tenancyId == null) {
      _snack('Please select a property', _amber);
      return;
    }
    if (_pickedFile == null) {
      _snack('Please upload the certificate document', _amber);
      return;
    }
    final refVal = _certRefCtrl.text.trim();
    final refErr = _validateRef(refVal);
    if (refErr != null) {
      setState(() => _certRefError = refErr);
      return;
    }

    setState(() => _saving = true);

    // Upload document — store path for signed URL generation later
    String? documentUrl;
    try {
      final user = supabase.auth.currentUser;
      if (user != null && _pickedFile!.bytes != null) {
        final ext  = _pickedFile!.extension ?? 'pdf';
        final path = '${user.id}/${_certType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage
            .from('compliance-docs')
            .uploadBinary(path, _pickedFile!.bytes!);
        documentUrl = path;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Document upload failed — please try again', _red);
      }
      return;
    }

    final ok = await ref.read(addCertProvider.notifier).add(
          tenancyId: _tenancyId!,
          certType: _certType,
          issuedDate: _issuedDate,
          expiryDate: _expiryDate,
          issuedBy: _issuedByCtrl.text.trim().isNotEmpty
              ? _issuedByCtrl.text.trim()
              : null,
          certRef: refVal.isNotEmpty ? refVal : null,
          documentUrl: documentUrl,
        );

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        _snack('Certificate added', _green);
      } else {
        _snack('Failed — please try again', _red);
      }
    }
  }

  void _snack(String msg, Color color) =>
      showAbodeToast(context, msg);
}


// ─── Rent Reviews Tab ─────────────────────────────────────────────────────────
class _RentReviewsTab extends ConsumerWidget {
  final VoidCallback onAdd;
  const _RentReviewsTab({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(landlordAllRentReviewsProvider);
    return reviewsAsync.when(
      loading: () => const SkeletonGenericList(),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (reviews) {
        if (reviews.isEmpty) {
          return _EmptyState(
            message: 'No rent reviews in progress',
            icon: Icons.trending_up_outlined,
            actionLabel: 'Start Section 13 Review',
            onAction: onAdd,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _RentReviewCard(r: reviews[i]),
        );
      },
    );
  }
}

class _RentReviewCard extends StatelessWidget {
  final RentReview r;
  const _RentReviewCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final isTribunal = r.isTribunalInvolved;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isTribunal
                ? _red.withValues(alpha: 0.4)
                : pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '£${r.currentRent.toStringAsFixed(0)} → £${r.proposedRent.toStringAsFixed(0)}/mo',
                  style: TextStyle(
                      color: pal.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isTribunal ? _red : _accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${r.increasePercent?.toStringAsFixed(1) ?? '—'}%',
                  style: TextStyle(
                      color: isTribunal ? _red : _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _InfoChip(Icons.notification_important_outlined,
                  'Notice', r.noticeServedDate != null ? fmt.format(r.noticeServedDate!) : '—', pal.sub),
              _InfoChip(Icons.calendar_today_outlined, 'Effective',
                  r.effectiveDate != null ? fmt.format(r.effectiveDate!) : '—',
                  (r.daysUntilEffective ?? 999) < 30 &&
                          (r.daysUntilEffective ?? -1) >= 0
                      ? _amber
                      : pal.sub),
              if (isTribunal)
                _InfoChip(Icons.gavel_outlined, 'Tribunal',
                    r.tribunalRef ?? 'Referred', _red),
            ],
          ),
          const SizedBox(height: 8),
          _StatusBadge(r.status),
        ],
      ),
    );
  }
}

// ─── Create Rent Review Sheet ─────────────────────────────────────────────────
class _CreateRentReviewSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _CreateRentReviewSheet({required this.onSaved});

  @override
  ConsumerState<_CreateRentReviewSheet> createState() =>
      _CreateRentReviewSheetState();
}

class _CreateRentReviewSheetState
    extends ConsumerState<_CreateRentReviewSheet> {
  AbodePalette get p => AbodePalette.of(context);

  String? _tenancyId;
  final _currentRentCtrl  = TextEditingController();
  final _proposedRentCtrl = TextEditingController();
  final _notesCtrl        = TextEditingController();
  DateTime _noticeDate = DateTime.now();
  late DateTime _effectiveDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recalcEffective();
  }

  void _recalcEffective() {
    _effectiveDate = DateTime(
        _noticeDate.year, _noticeDate.month + 2, _noticeDate.day);
  }

  @override
  void dispose() {
    _currentRentCtrl.dispose();
    _proposedRentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _increase {
    final cur  = double.tryParse(_currentRentCtrl.text) ?? 0;
    final prop = double.tryParse(_proposedRentCtrl.text) ?? 0;
    return prop - cur;
  }

  double get _increasePercent {
    final cur = double.tryParse(_currentRentCtrl.text) ?? 0;
    if (cur == 0) return 0;
    return (_increase / cur) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final fmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Section 13 Rent Review',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Minimum 2 months notice required under the RRA',
                style: TextStyle(color: p.sub, fontSize: 12),
              ),
              const SizedBox(height: 20),

              _SectionLabel('Property'),
              const SizedBox(height: 8),
              _TenancyDropdown(
                tenanciesAsync: tenanciesAsync,
                value: _tenancyId,
                onChanged: (v) {
                  setState(() => _tenancyId = v);
                  final tenancies = tenanciesAsync.value ?? [];
                  final t = tenancies.where((t) => t.id == v).firstOrNull;
                  if (t?.monthlyRent != null) {
                    _currentRentCtrl.text =
                        t!.monthlyRent!.toStringAsFixed(0);
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Current rent (£/mo)'),
                        const SizedBox(height: 8),
                        _DarkTextField(
                            controller: _currentRentCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Proposed rent (£/mo)'),
                        const SizedBox(height: 8),
                        _DarkTextField(
                            controller: _proposedRentCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {})),
                      ],
                    ),
                  ),
                ],
              ),

              if (_proposedRentCtrl.text.isNotEmpty &&
                  _increase != 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _increase > 0
                        ? _accent.withValues(alpha: 0.08)
                        : _green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _increase > 0
                            ? _accent.withValues(alpha: 0.2)
                            : _green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _increase > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: _increase > 0 ? _accent : _green,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_increase > 0 ? '+' : ''}£${_increase.toStringAsFixed(0)}/mo'
                        '  (${_increasePercent > 0 ? '+' : ''}${_increasePercent.toStringAsFixed(1)}%)',
                        style: TextStyle(
                            color: _increase > 0 ? _accent : _green,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              _SectionLabel('Notice served date'),
              const SizedBox(height: 8),
              _DatePickerTile(
                date: _noticeDate,
                onTap: () async {
                  final picked = await showAbodeDatePicker(
                    context,
                    initialDate: _noticeDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _noticeDate = picked;
                      _recalcEffective();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_outlined,
                        color: _accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Effective date',
                              style: TextStyle(
                                  color: p.sub, fontSize: 12)),
                          Text(fmt.format(_effectiveDate),
                              style: const TextStyle(
                                  color: _accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Text('2 months notice',
                        style: TextStyle(
                            color: p.muted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _SectionLabel('Notes (optional)'),
              const SizedBox(height: 8),
              _DarkTextField(
                  controller: _notesCtrl,
                  hint: 'Any additional context…',
                  maxLines: 2),
              const SizedBox(height: 24),

              _SaveButton(
                label: 'Create Rent Review',
                saving: _saving,
                color: _accent,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_tenancyId == null) {
      _snack('Please select a property', _amber);
      return;
    }
    final cur  = double.tryParse(_currentRentCtrl.text);
    final prop = double.tryParse(_proposedRentCtrl.text);
    if (cur == null || prop == null) {
      _snack('Please enter valid rent amounts', _amber);
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(createRentReviewProvider.notifier).create(
          tenancyId: _tenancyId!,
          currentRent: cur,
          proposedRent: prop,
          noticeServedDate: _noticeDate,
          effectiveDate: _effectiveDate,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
        );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        _snack('Rent review created', _green);
      } else {
        _snack('Failed — please try again', _red);
      }
    }
  }

  void _snack(String msg, Color color) =>
      showAbodeToast(context, msg);
}

// ─── Section 8 Tab ────────────────────────────────────────────────────────────
class _Section8Tab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groundsAsync = ref.watch(landlordAllSection8GroundsProvider);
    return groundsAsync.when(
      loading: () => const SkeletonGenericList(),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (grounds) {
        if (grounds.isEmpty) {
          return const _EmptyState(
              message: 'No Section 8 notices active',
              icon: Icons.gavel_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: grounds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _Section8Card(g: grounds[i]),
        );
      },
    );
  }
}

class _Section8Card extends StatelessWidget {
  final Section8Ground g;
  const _Section8Card({required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: g.isMandatory
                ? _red.withValues(alpha: 0.4)
                : pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (g.isMandatory ? _red : _amber)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('G${g.groundNumber}',
                      style: TextStyle(
                          color: g.isMandatory ? _red : _amber,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.description,
                        style: TextStyle(
                            color: pal.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(
                      g.isMandatory
                          ? 'Mandatory'
                          : 'Discretionary',
                      style: TextStyle(
                          color: g.isMandatory ? _red : _amber,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              _StatusPill(g.displayStatus),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _InfoChip(
                  Icons.notification_important_outlined,
                  'Notice',
                  g.noticeServedDate != null ? fmt.format(g.noticeServedDate!) : '—',
                  pal.sub),
              if (g.earliestCourtDate != null)
                _InfoChip(Icons.gavel_outlined, 'Court from',
                    fmt.format(g.earliestCourtDate!), _accent),
              if (g.arrearsAmount != null)
                _InfoChip(Icons.money_off_outlined, 'Arrears',
                    '£${g.arrearsAmount!.toStringAsFixed(0)}', _red),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pet Requests Tab ─────────────────────────────────────────────────────────
class _PetsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final petsAsync = ref.watch(landlordPetRequestsProvider);
    return petsAsync.when(
      loading: () => const SkeletonGenericList(),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (pets) {
        if (pets.isEmpty) {
          return const _EmptyState(
            message: 'No pet requests',
            icon: Icons.pets_outlined,
          );
        }
        final pending   = pets.where((p) => p.isPending).toList();
        final responded = pets.where((p) => !p.isPending).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Pending',
                    style: TextStyle(
                        color: p.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              ...pending.map((pet) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PetCard(p: pet),
                  )),
            ],
            if (responded.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Text('Responded',
                    style: TextStyle(
                        color: p.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              ...responded.map((pet) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PetCard(p: pet),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _PetCard extends ConsumerWidget {
  final PetRequest p;
  const _PetCard({required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = AbodePalette.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final isOverdue = p.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: p.isPending
                ? _amber.withValues(alpha: 0.4)
                : pal.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pets_outlined,
                          color: _amber, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.petType.toUpperCase()}${p.petName != null ? ' — ${p.petName}' : ''}',
                            style: TextStyle(
                                color: pal.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          Text(
                            'Requested ${fmt.format(p.requestedAt)}',
                            style: TextStyle(
                                color: pal.sub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _PetStatusPill(p.displayStatus),
                  ],
                ),
                if (p.notes != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pal.border),
                    ),
                    child: Text(p.notes!,
                        style: TextStyle(
                            color: pal.sub, fontSize: 12)),
                  ),
                ],
                if (p.isPending && p.responseDeadline != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 13,
                          color: isOverdue ? _red : _amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isOverdue
                              ? 'Response OVERDUE (42-day limit passed)'
                              : 'Respond by ${fmt.format(p.responseDeadline!)} (${p.daysUntilDeadline}d)',
                          style: TextStyle(
                              color: isOverdue ? _red : _amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (p.isPending) ...[
            Container(height: 1, color: pal.border.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _ResponseButton(
                      label: 'Approve',
                      color: _green,
                      onTap: () => _respond(context, ref, p.id, 'approved'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResponseButton(
                      label: 'Conditional',
                      color: _accent,
                      onTap: () =>
                          _showConditionalSheet(context, ref, p),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResponseButton(
                      label: 'Refuse',
                      color: _red,
                      onTap: () => _showRefuseSheet(context, ref, p),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref,
      String id, String status,
      {String? conditions, String? reason}) async {
    final ok = await ref
        .read(petResponseProvider.notifier)
        .respond(
            petRequestId: id,
            status: status,
            conditions: conditions,
            refusalReason: reason);
    if (context.mounted) {
      ref.invalidate(landlordPetRequestsProvider);
      showAbodeToast(context, ok ? 'Response saved' : 'Failed — please try again', isError: true);
    }
  }

  void _showConditionalSheet(
      BuildContext context, WidgetRef ref, PetRequest pet) {
    final pal = AbodePalette.of(context);
    final ctrl = TextEditingController();
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: pal.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Conditional Approval',
                  style: TextStyle(
                      color: pal.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Conditions attached to this approval:',
                  style: TextStyle(color: pal.sub, fontSize: 13)),
              const SizedBox(height: 12),
              _DarkTextField(
                  controller: ctrl,
                  hint:
                      'e.g. Additional deposit required, pet insurance required…',
                  maxLines: 3),
              const SizedBox(height: 20),
              _SaveButton(
                label: 'Approve with Conditions',
                color: _accent,
                saving: false,
                onTap: () {
                  Navigator.pop(ctx);
                  _respond(context, ref, pet.id,
                      'conditionally_approved',
                      conditions: ctrl.text.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRefuseSheet(
      BuildContext context, WidgetRef ref, PetRequest pet) {
    final pal = AbodePalette.of(context);
    final ctrl = TextEditingController();
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: pal.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Refuse Pet Request',
                  style: TextStyle(
                      color: pal.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  'Under the RRA, refusals must be for a reasonable, listed reason.',
                  style: TextStyle(color: pal.sub, fontSize: 12)),
              const SizedBox(height: 12),
              _DarkTextField(
                  controller: ctrl,
                  hint:
                      'Reason for refusal (e.g. property unsuitable, lease restriction)…',
                  maxLines: 3),
              const SizedBox(height: 20),
              _SaveButton(
                label: 'Confirm Refusal',
                color: _red,
                saving: false,
                onTap: () {
                  Navigator.pop(ctx);
                  _respond(context, ref, pet.id, 'refused',
                      reason: ctrl.text.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section 8 Ground Sheet ───────────────────────────────────────────────────
class _Section8GroundSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _Section8GroundSheet({required this.onSaved});

  @override
  ConsumerState<_Section8GroundSheet> createState() =>
      _Section8GroundSheetState();
}

class _Section8GroundSheetState
    extends ConsumerState<_Section8GroundSheet> {
  AbodePalette get p => AbodePalette.of(context);

  String? _tenancyId;
  String _selectedGround = '8';
  DateTime _noticeDate = DateTime.now();
  late DateTime _courtDate;
  final _arrearsCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  bool _saving = false;

  static const _arrearsGrounds = {'8', '10', '11'};

  @override
  void initState() {
    super.initState();
    _recalcCourtDate();
  }

  void _recalcCourtDate() {
    final isImmediate = _selectedGround == '14';
    _courtDate = isImmediate
        ? _noticeDate
        : _noticeDate.add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _arrearsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final ground     = kSection8Grounds[_selectedGround]!;
    final isMandatory = ground['type'] == 'mandatory';
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final fmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_outlined,
                    color: _red, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Section 8 Notice',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text('Possession ground under the RRA',
                      style: TextStyle(color: p.sub, fontSize: 12)),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            _SectionLabel('Property'),
            const SizedBox(height: 8),
            _TenancyDropdown(
              tenanciesAsync: tenanciesAsync,
              value: _tenancyId,
              onChanged: (v) => setState(() => _tenancyId = v),
            ),
            const SizedBox(height: 16),

            _SectionLabel('Ground'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kSection8Grounds.keys.map((g) {
                final gData  = kSection8Grounds[g]!;
                final isMand = gData['type'] == 'mandatory';
                final sel    = _selectedGround == g;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedGround = g;
                    _recalcCourtDate();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? (isMand ? _red : _amber)
                              .withValues(alpha: 0.15)
                          : p.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel
                              ? (isMand ? _red : _amber)
                                  .withValues(alpha: 0.5)
                              : p.border),
                    ),
                    child: Text('G$g',
                        style: TextStyle(
                          color: sel
                              ? (isMand ? _red : _amber)
                              : p.sub,
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isMandatory ? _red : _amber)
                    .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (isMandatory ? _red : _amber)
                        .withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isMandatory ? _red : _amber)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMandatory ? 'MANDATORY' : 'DISCRETIONARY',
                    style: TextStyle(
                        color: isMandatory ? _red : _amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ground['label']!,
                      style: TextStyle(
                          color: p.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            _SectionLabel('Notice served date'),
            const SizedBox(height: 8),
            _DatePickerTile(
              date: _noticeDate,
              onTap: () async {
                final d = await showAbodeDatePicker(
                  context,
                  initialDate: _noticeDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) {
                  setState(() {
                    _noticeDate = d;
                    _recalcCourtDate();
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _red.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.gavel_outlined,
                    color: _red, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Earliest court date',
                          style: TextStyle(
                              color: p.sub, fontSize: 12)),
                      Text(fmt.format(_courtDate),
                          style: const TextStyle(
                              color: _red,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text(
                  _selectedGround == '14'
                      ? 'Same day'
                      : '+14 days',
                  style: TextStyle(
                      color: p.muted, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 16),

            if (_arrearsGrounds.contains(_selectedGround)) ...[
              _SectionLabel('Rent arrears amount (£)'),
              const SizedBox(height: 8),
              _DarkTextField(
                  controller: _arrearsCtrl,
                  hint: '0.00',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
            ],

            _SectionLabel('Notes / evidence (optional)'),
            const SizedBox(height: 8),
            _DarkTextField(
                controller: _notesCtrl,
                hint: 'Supporting evidence, case notes…',
                maxLines: 3),
            const SizedBox(height: 24),

            _SaveButton(
              label: 'Serve Section 8 Notice',
              saving: _saving,
              color: _red,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_tenancyId == null) {
      _snack('Please select a property', _amber);
      return;
    }
    setState(() => _saving = true);
    final arrears = _arrearsGrounds.contains(_selectedGround)
        ? double.tryParse(_arrearsCtrl.text.trim())
        : null;
    final ok = await ref
        .read(createSection8GroundProvider.notifier)
        .create(
          tenancyId: _tenancyId!,
          groundNumber: _selectedGround,
          noticeServedDate: _noticeDate,
          earliestCourtDate: _courtDate,
          arrearsAmount: arrears,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        _snack('Section 8 notice recorded', _green);
      } else {
        _snack('Failed — please try again', _red);
      }
    }
  }

  void _snack(String msg, Color color) =>
      showAbodeToast(context, msg);
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.message,
    required this.icon,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: pal.muted, size: 48),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.sub, fontSize: 15, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.muted, fontSize: 12, height: 1.5)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.3)),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  const _TabChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.count});

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.15)
              : pal.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? _accent.withValues(alpha: 0.5)
                  : pal.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: selected ? _accent : pal.sub,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withValues(alpha: 0.25)
                    : pal.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: selected ? _accent : pal.sub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _InfoChip(this.icon, this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: pal.muted),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(color: pal.muted, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final color = switch (status) {
      'notice_served'     => _amber,
      'tenant_accepted'   => _green,
      'court_applied'     => _red,
      'hearing_listed'    => _red,
      'order_granted'     => _red,
      'tribunal_referred' => _red,
      _                   => pal.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final color = switch (status) {
      'pending'                => _amber,
      'approved'               => _green,
      'conditionally approved' => _accent,
      'refused'                => _red,
      'notice served'          => _amber,
      'court applied'          => _red,
      'order granted'          => _red,
      _                        => pal.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _PetStatusPill extends StatelessWidget {
  final String status;
  const _PetStatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final color = switch (status) {
      'pending'                => _amber,
      'approved'               => _green,
      'conditionally approved' => _accent,
      'refused'                => _red,
      _                        => pal.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ResponseButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _TenancyDropdown extends StatelessWidget {
  final AsyncValue<List<dynamic>> tenanciesAsync;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TenancyDropdown({
    required this.tenanciesAsync,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: tenanciesAsync.when(
        loading: () => const SizedBox(
            height: 40,
            child: Center(
                child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2))),
        error: (_, __) => const SizedBox(height: 40),
        data: (tenancies) => DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text('Select property…',
                style: TextStyle(color: pal.muted, fontSize: 14)),
            dropdownColor: pal.surface,
            style: TextStyle(color: pal.text, fontSize: 14),
            isExpanded: true,
            items: tenancies
                .map((t) {
                  final address = '${t.addressLine1}, ${t.postcode}';
                  return DropdownMenuItem<String>(
                    value: t.id as String,
                    child:
                        Text(address, overflow: TextOverflow.ellipsis),
                  );
                })
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final Color? color;
  const _DatePickerTile(
      {required this.date, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    final fmt = DateFormat('d MMM yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: color ?? pal.muted),
            const SizedBox(width: 10),
            Text(fmt.format(date),
                style: TextStyle(
                    color: color ?? pal.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: pal.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final Color color;
  final VoidCallback onTap;
  const _SaveButton({
    required this.label,
    required this.saving,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: saving ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: saving ? color.withValues(alpha: 0.4) : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ),
      );
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: pal.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.muted, fontSize: 14),
        filled: true,
        fillColor: pal.card,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: pal.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: pal.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Text(label,
        style: TextStyle(
            color: pal.sub,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3));
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  const _SelectChip(
      {required this.label, required this.selected, required this.color});
  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.15) : pal.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : pal.border),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? color : pal.sub,
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}
