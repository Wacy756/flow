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

  @override
  void initState() {
    super.initState();
    _selectedWorkTypes =
        List<String>.from(widget.existing?.workTypes ?? []);
    _serviceAreas =
        List<ServiceArea>.from(widget.existing?.serviceAreas ?? []);
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Geolocator
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
                backgroundColor: Colors.red),
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
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // -------------------------------------------------------------------------
  // Map interaction
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
  // Save
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_selectedWorkTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one work type.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_serviceAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one service area.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final ok = await ref.read(saveContractorDetailsProvider.notifier).save(
          workTypes: _selectedWorkTypes,
          serviceAreas: _serviceAreas,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------------------
  // Build
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
          color: AppTheme.surface,
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
                  color: AppTheme.borderLight,
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
                      gradient: AppTheme.roleGradient('contractor'),
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Select work types and set your service areas.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
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
                  // ── Work types ──────────────────────────────────────────
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
                                ? AppTheme.contractorColor
                                : AppTheme.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.contractorColor
                                  : AppTheme.borderLight,
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

                  // ── Service areas ────────────────────────────────────────
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
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 14),
                        label: const Text('My Location',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
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

                  const SizedBox(height: 24),

                  // Error
                  if (saveState.hasError)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(saveState.error.toString(),
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                        isSaving ? 'Saving…' : 'Save Details',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.contractorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      );
}

// ---------------------------------------------------------------------------
// Preview configuration panel
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
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
                    color: Color(0xFF1E40AF)),
              ),
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close,
                    size: 18, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Area name
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Area name (e.g. Central London)',
              labelStyle:
                  const TextStyle(color: Color(0xFF2563EB), fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Radius slider
          Row(
            children: [
              const Text('Radius: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
              Text(
                '${radiusMiles.round()} miles',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF)),
              ),
            ],
          ),
          Slider(
            value: radiusMiles,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: const Color(0xFF2563EB),
            onChanged: onRadiusChange,
          ),
          const SizedBox(height: 4),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isEditing ? 'Update Area' : 'Add to Service Areas',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service area list tile
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
        color: isEditing
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEditing
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${area.radiusMiles.toStringAsFixed(0)}mi',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isEditing
                      ? const Color(0xFF2563EB)
                      : AppTheme.contractorColor,
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
                        fontWeight: FontWeight.w700, fontSize: 13)),
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
                    ? const Color(0xFF2563EB)
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
