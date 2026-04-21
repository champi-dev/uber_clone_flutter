import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/api_config.dart';
import '../../core/theme/app_theme.dart';

class RideMapView extends StatelessWidget {
  final MapController? controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final void Function(LatLng)? onLongPress;

  const RideMapView({
    super.key,
    this.controller,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.polylines = const [],
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onLongPress: (_, p) => onLongPress?.call(p),
        backgroundColor: AppColors.surfaceAlt,
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConfig.mapTileUrl,
          userAgentPackageName: 'com.ridenow.rider',
          maxZoom: 20,
          retinaMode: true,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Pin with a subtle pulse + shadow.
class _PulsePin extends StatefulWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _PulsePin({required this.color, required this.icon, this.size = 42});
  @override
  State<_PulsePin> createState() => _PulsePinState();
}

class _PulsePinState extends State<_PulsePin> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        Container(
          width: widget.size * (1 + _c.value * 0.6),
          height: widget.size * (1 + _c.value * 0.6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: (1 - _c.value) * 0.35),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: widget.size * 0.55,
          height: widget.size * 0.55,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.3),
        ),
      ]),
    );
  }
}

Marker pickupMarker(LatLng p) => Marker(
      point: p, width: 56, height: 56,
      child: const _PulsePin(color: AppColors.accent, icon: Icons.person),
    );

Marker dropoffMarker(LatLng p) => Marker(
      point: p, width: 56, height: 56,
      child: const _PulsePin(color: AppColors.primary, icon: Icons.flag_rounded),
    );

/// Driver car marker that smoothly tweens position + heading between ticks.
class DriverMarker extends StatelessWidget {
  final LatLng point;
  final double heading;
  const DriverMarker({super.key, required this.point, required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * 3.14159265 / 180,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(9),
        child: const Icon(Icons.navigation, color: Colors.white, size: 22),
      ),
    );
  }
}

Marker buildDriverMarker(LatLng p, double heading) => Marker(
      point: p, width: 52, height: 52, child: DriverMarker(point: p, heading: heading),
    );
