import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../models/contractor_profile.dart';
import '../models/service_area.dart';
import '../providers/dashboard_providers.dart';
import 'service_area_map_widget.dart';

void showContractorSetupSheet(
  BuildContext context, {
  ContractorDetails? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContractorSetupSheet(existing: existing),
  );
}

class _ContractorSetupSheet extends ConsumerStatefulWidget {
  final ContractorDetails? existing;
  const _ContractorSetupSheet({this.existing});

  @override
  ConsumerState<_ContractorSetupSheet> createState() =>
      _ContractorSetupSheetState();
}

class _ContractorSetupSheetState
    extends ConsumerState<_ContractorSetupSheet> {
  late List<String> _selectedWorkTypes;
  late List<ServiceArea> _serviceAreas;
  ServiceArea? _previewArea;
  final _areaNameController = TextEditingController();
  double _radiusMiles = 5;
  int? _editingIndex;
  LatLng? _deviceLocation;
  bool _gettingLocation = false;

  // Credentials
  final _insuranceCertController = TextEditingController();
  DateTime? _insuranceExpiry;
  final _gasSafeController = TextEditingController();
  DateTime? _gasSafeExpiry;
  final _niceicController = TextEditingController();
  DateTime? _niceicExpiry;

  @override
  void initState() {
    super.initState();
    _selectedWorkTypes =
        List<String>.from(widget.existing?.workTypes ?? []);
    _serviceAreas =
        List<ServiceArea>.from(widget.existing?.serviceAreas ?? []);
    // Pre-fill cert fields from existing profile
    final e = widget.existing;
    if (e != null) {
      _insuranceCertController.text = e.insuranceCertNumber ?? '';
      _insuranceExpiry = e.insuranceExpiry;
      _gasSafeController.text = e.gasSafeNumber ?? '';
      _gasSafeExpiry = e.gasSafeExpiry;
      _niceicController.text = e.niceicNumber ?? '';
      _niceicExpiry = e.niceicExpiry;
    }
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    _insuranceCertController.dispose();
    _gasSafeController.dispose();
    _niceicController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------

  Future<void> _useMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: AppTheme.darkBg),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _deviceLocation = LatLng(pos.latitude, pos.longitude);
          _previewArea = ServiceArea(
            name: _areaNameController.text.trim().isEmpty
                ? 'Area ${_serviceAreas.length + 1}'
                : _areaNameController.text.trim(),
            lat: pos.latitude,
            lng: pos.longitude,
            radius: _radiusMiles * 1609.34,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not get location: $e'),
              backgroundColor: AppTheme.darkBg),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // -------------------------------------------------------------------------

  void _onMapTap(LatLng latLng) {
    setState(() {
      _previewArea = ServiceArea(
        name: _areaNameController.text.trim().isEmpty
            ? 'Area ${_serviceAreas.length + 1}'
            : _areaNameController.text.trim(),
        lat: latLng.latitude,
        lng: latLng.longitude,
        radius: _radiusMiles * 1609.34,
      );
    });
  }

  void _updateRadius(double miles) {
    setState(() {
      _radiusMiles = miles;
      if (_previewArea != null) {
        _previewArea = _previewArea!.copyWith(radius: miles * 1609.34);
      }
    });
  }

  void _confirmArea() {
    if (_previewArea == null) return;
    final named = _previewArea!.copyWith(
      name: _areaNameController.text.trim().isEmpty
          ? 'Area ${_serviceAreas.length + 1}'
          : _areaNameController.text.trim(),
    );
    setState(() {
      if (_editingIndex != null) {
        _serviceAreas[_editingIndex!] = named;
      } else {
        _serviceAreas.add(named);
      }
      _previewArea = null;
      _editingIndex = null;
      _areaNameController.clear();
      _radiusMiles = 5;
    });
  }

  void _cancelPreview() {
    setState(() {
      _previewArea = null;
      _editingIndex = null;
      _areaNameController.clear();
      _radiusMiles = 5;
    });
  }

  void _editArea(int index) {
    final area = _serviceAreas[index];
    setState(() {
      _editingIndex = index;
      _areaNameController.text = area.name;
      _radiusMiles = (area.radius / 1609.34).roundToDouble();
      _previewArea = area;
    });
  }

  void _removeArea(int index) {
    setState(() => _serviceAreas.removeAt(index));
  }

  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_selectedWorkTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one work type.'),
            backgroundColor: AppTheme.darkBg),
      );
      return;
    }
    if (_serviceAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one service area.'),
            backgroundColor: AppTheme.darkBg),
      );
      return;
    }

    final ok = await ref.read(saveContractorDetailsProvider.notifier).save(
          workTypes: _selectedWorkTypes,
          serviceAreas: _serviceAreas,
          insuranceCertNumber: _insuranceCertController.text.trim(),
          insuranceExpiry: _insuranceExpiry,
          gasSafeNumber: _gasSafeController.text.trim(),
          gasSafeExpiry: _gasSafeExpiry,
          niceicNumber: _niceicController.text.trim(),
          niceicExpiry: _niceicExpiry,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(saveContractorDetailsProvider);
    final isSaving = saveState.isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.contractorBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.construction_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existing?.isSetUp ?? false
                              ? 'Edit Service Details'
                              : 'Set Up Your Profile',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Select work types and set your service areas.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  // Work types
                  _sectionLabel('What type of work do you do?'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kWorkTypes.map((type) {
                      final selected = _selectedWorkTypes.contains(type);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedWorkTypes.remove(type);
                          } else {
                            _selectedWorkTypes.add(type);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.green
                                : AppTheme.bgPage,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.green
                                  : AppTheme.border,
                              width: selected ? 1.0 : 0.5,
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Service areas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Service Areas'),
                      TextButton.icon(
                        onPressed: _gettingLocation ? null : _useMyLocation,
                        icon: _gettingLocation
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.green),
                              )
                            : const Icon(Icons.my_location, size: 14),
                        label: const Text('My Location',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.green,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _previewArea != null
                        ? 'Configure the area below, then tap "Add".'
                        : 'Tap the map to drop a pin and add a service area.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 320,
                      child: ServiceAreaMapWidget(
                        serviceAreas: _serviceAreas,
                        previewArea: _previewArea,
                        onTap: _onMapTap,
                        initialCenter: _deviceLocation,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preview configuration panel
                  if (_previewArea != null)
                    _PreviewPanel(
                      nameController: _areaNameController,
                      radiusMiles: _radiusMiles,
                      isEditing: _editingIndex != null,
                      onRadiusChange: _updateRadius,
                      onConfirm: _confirmArea,
                      onCancel: _cancelPreview,
                    ),

                  // Saved areas list
                  if (_serviceAreas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._serviceAreas.asMap().entries.map((entry) =>
                        _ServiceAreaTile(
                          area: entry.value,
                          index: entry.key,
                          isEditing: _editingIndex == entry.key,
                          onEdit: () => _editArea(entry.key),
                          onDelete: () => _removeArea(entry.key),
                        )),
                  ],

                  const SizedBox(height: 28),

                  // Credentials
                  _sectionLabel('Credentials (optional)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Adding certifications helps landlords trust your work.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  _CertField(
                    icon: Icons.shield_outlined,
                    label: 'Public Liability Insurance',
                    certController: _insuranceCertController,
                    certHint: 'Policy / cert number',
                    expiry: _insuranceExpiry,
                    onExpiryTap: () async {
                      final d = await _pickDate(context, _insuranceExpiry);
                      if (d != null) setState(() => _insuranceExpiry = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  _CertField(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Gas Safe',
                    certController: _gasSafeController,
                    certHint: 'Registration number',
                    expiry: _gasSafeExpiry,
                    onExpiryTap: () async {
                      final d = await _pickDate(context, _gasSafeExpiry);
                      if (d != null) setState(() => _gasSafeExpiry = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  _CertField(
                    icon: Icons.bolt_outlined,
                    label: 'NICEIC / NAPIT',
                    certController: _niceicController,
                    certHint: 'Registration number',
                    expiry: _niceicExpiry,
                    onExpiryTap: () async {
                      final d = await _pickDate(context, _niceicExpiry);
                      if (d != null) setState(() => _niceicExpiry = d);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Error
                  if (saveState.hasError)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.border, width: 0.5),
                      ),
                      child: Text(saveState.error.toString(),
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _save,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline,
                              color: Colors.white),
                      label: Text(
                        isSaving ? 'Saving...' : 'Save Details',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      );

  Future<DateTime?> _pickDate(
      BuildContext context, DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.green,
            surface: AppTheme.bgSurface,
          ),
        ),
        child: child!,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PreviewPanel extends StatelessWidget {
  final TextEditingController nameController;
  final double radiusMiles;
  final bool isEditing;
  final void Function(double) onRadiusChange;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PreviewPanel({
    required this.nameController,
    required this.radiusMiles,
    required this.isEditing,
    required this.onRadiusChange,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Service Area' : 'Configure New Area',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close,
                    size: 18, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Area name
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Area name (e.g. Central London)',
            ),
          ),
          const SizedBox(height: 12),

          // Radius slider
          Row(
            children: [
              const Text('Radius: ',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text(
                '${radiusMiles.round()} miles',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.green,
              thumbColor: AppTheme.green,
              overlayColor: AppTheme.green.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: radiusMiles,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: onRadiusChange,
            ),
          ),
          const SizedBox(height: 4),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isEditing ? 'Update Area' : 'Add to Service Areas',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ServiceAreaTile extends StatelessWidget {
  final ServiceArea area;
  final int index;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceAreaTile({
    required this.area,
    required this.index,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing ? AppTheme.greenBg : AppTheme.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? AppTheme.green.withValues(alpha: 0.3)
              : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEditing
                  ? AppTheme.green.withValues(alpha: 0.15)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.border, width: 0.5),
            ),
            child: Center(
              child: Text(
                '${area.radiusMiles.toStringAsFixed(0)}mi',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isEditing
                      ? AppTheme.green
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                Text(
                  '${area.lat.toStringAsFixed(4)}, ${area.lng.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined,
                size: 18,
                color: isEditing
                    ? AppTheme.green
                    : AppTheme.textMuted),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.red),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CertField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController certController;
  final String certHint;
  final DateTime? expiry;
  final VoidCallback onExpiryTap;

  const _CertField({
    required this.icon,
    required this.label,
    required this.certController,
    required this.certHint,
    required this.expiry,
    required this.onExpiryTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasExpiry = expiry != null;
    final isExpired =
        hasExpiry && expiry!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: certController,
            decoration: InputDecoration(
              labelText: certHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onExpiryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isExpired
                      ? Colors.red.shade400
                      : AppTheme.border,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: isExpired
                        ? Colors.red.shade400
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasExpiry
                        ? 'Expires ${expiry!.day}/${expiry!.month}/${expiry!.year}'
                        : 'Set expiry date',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired
                          ? Colors.red.shade400
                          : hasExpiry
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                      fontWeight: hasExpiry
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (isExpired) ...[
                    const SizedBox(width: 6),
                    Text(
                      'EXPIRED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade400,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
