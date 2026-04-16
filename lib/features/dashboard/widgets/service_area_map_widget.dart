import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../models/service_area.dart';

/// Interactive flutter_map widget for setting contractor service areas.
///
/// - Tapping the map fires [onTap] with the tapped [LatLng].
/// - Confirmed [serviceAreas] are shown as orange filled circles.
/// - [previewArea] is shown as a blue dashed circle while configuring.
class ServiceAreaMapWidget extends StatefulWidget {
  final List<ServiceArea> serviceAreas;
  final ServiceArea? previewArea;
  final void Function(LatLng latLng) onTap;

  /// Optional initial center (e.g. from geolocator). Defaults to London.
  final LatLng? initialCenter;

  const ServiceAreaMapWidget({
    super.key,
    required this.serviceAreas,
    this.previewArea,
    required this.onTap,
    this.initialCenter,
  });

  @override
  State<ServiceAreaMapWidget> createState() => _ServiceAreaMapWidgetState();
}

class _ServiceAreaMapWidgetState extends State<ServiceAreaMapWidget> {
  late final MapController _controller;

  static const _defaultCenter = LatLng(51.5074, -0.1278); // London

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  void didUpdateWidget(ServiceAreaMapWidget old) {
    super.didUpdateWidget(old);
    // When a preview area is newly set, animate the map to it
    if (widget.previewArea != null &&
        widget.previewArea != old.previewArea) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.move(
          LatLng(widget.previewArea!.lat, widget.previewArea!.lng),
          12,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final circles = <CircleMarker>[];
    final markers = <Marker>[];

    // Confirmed areas
    for (final area in widget.serviceAreas) {
      circles.add(CircleMarker(
        point: LatLng(area.lat, area.lng),
        radius: area.radius,
        useRadiusInMeter: true,
        color: AppTheme.contractorColor.withValues(alpha: 0.18),
        borderColor: AppTheme.contractorColor,
        borderStrokeWidth: 2,
      ));
      markers.add(Marker(
        point: LatLng(area.lat, area.lng),
        width: 32,
        height: 32,
        child: const _MapPin(color: AppTheme.contractorColor),
      ));
    }

    // Preview area (blue while configuring)
    if (widget.previewArea != null) {
      final p = widget.previewArea!;
      circles.add(CircleMarker(
        point: LatLng(p.lat, p.lng),
        radius: p.radius,
        useRadiusInMeter: true,
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        borderColor: const Color(0xFF2563EB),
        borderStrokeWidth: 2,
      ));
      markers.add(Marker(
        point: LatLng(p.lat, p.lng),
        width: 32,
        height: 32,
        child: const _MapPin(color: Color(0xFF2563EB)),
      ));
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.initialCenter ?? _defaultCenter,
        initialZoom: widget.serviceAreas.isNotEmpty ? 10 : 9,
        onTap: (_, latLng) => widget.onTap(latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'uk.co.flowsapp',
        ),
        CircleLayer(circles: circles),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) => Icon(
        Icons.location_on,
        color: color,
        size: 32,
        shadows: const [
          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      );
}
