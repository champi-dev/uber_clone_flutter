import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/landmarks.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../providers/ride_flow.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/map/map_view.dart';
import '../../widgets/map/smooth_driver_layer.dart';
import '../ride/destination_sheet.dart';
import '../ride/vehicle_select_sheet.dart';
import '../ride/searching_overlay.dart';
import '../ride/driver_en_route_sheet.dart';
import '../ride/ride_in_progress_sheet.dart';
import '../ride/ride_complete_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _map = MapController();
  LatLng _pickup = LatLng(monteriaCenter.lat, monteriaCenter.lng);
  String _pickupAddress = 'Current Location';
  LatLng? _dropoff;
  bool _locatingUser = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  // Montería bounding box — anything outside falls back to city center.
  static const _monteriaMinLat = 8.5, _monteriaMaxLat = 9.0;
  static const _monteriaMinLng = -76.1, _monteriaMaxLng = -75.6;

  Future<void> _initLocation() async {
    final svc = ref.read(locationServiceProvider);
    final p = await svc.currentPoint();
    if (!mounted) return;
    if (p != null &&
        p.latitude >= _monteriaMinLat && p.latitude <= _monteriaMaxLat &&
        p.longitude >= _monteriaMinLng && p.longitude <= _monteriaMaxLng) {
      setState(() { _pickup = p; _locatingUser = false; });
      _map.move(p, 15);
      // Reverse geocode to a nice address asynchronously
      final addr = await svc.reverseGeocode(p);
      if (!mounted) return;
      if (addr != null) setState(() => _pickupAddress = addr);
    } else {
      // Fallback: keep Montería center
      setState(() => _locatingUser = false);
    }
  }

  void _onLocationsChosen(LatLng pickup, String pickupAddr, LatLng dropoff, String dropoffAddr) {
    setState(() { _pickup = pickup; _pickupAddress = pickupAddr; _dropoff = dropoff; });
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([pickup, dropoff]),
      padding: const EdgeInsets.fromLTRB(60, 140, 60, 260),
    ));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleSelectSheet(
        pickup: pickup, pickupAddress: pickupAddr,
        dropoff: dropoff, dropoffAddress: dropoffAddr,
      ),
    );
  }

  // Auto-fit map to relevant points per phase.
  void _fitBoundsFor(RideFlowState flow) {
    try {
      final pts = <LatLng>[];
      if (flow.phase == RideFlowPhase.accepted || flow.phase == RideFlowPhase.driverArriving) {
        if (flow.driverLat != null) pts.add(LatLng(flow.driverLat!, flow.driverLng!));
        pts.add(_pickup);
      } else if (flow.phase == RideFlowPhase.inProgress) {
        if (flow.driverLat != null) pts.add(LatLng(flow.driverLat!, flow.driverLng!));
        if (_dropoff != null) pts.add(_dropoff!);
      }
      if (pts.length >= 2) {
        final bounds = LatLngBounds.fromPoints(pts);
        _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(60, 140, 60, 260)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);

    ref.listen(rideFlowProvider, (prev, next) {
      if (prev?.phase != next.phase) {
        if (next.phase == RideFlowPhase.accepted) WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsFor(next));
        if (next.phase == RideFlowPhase.inProgress) WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsFor(next));
        if (next.phase == RideFlowPhase.completed) {
          Future.microtask(() {
            if (!mounted) return;
            showModalBottomSheet(
              context: context, isScrollControlled: true, isDismissible: false, enableDrag: false,
              backgroundColor: Colors.transparent,
              builder: (_) => const RideCompleteSheet(),
            );
          });
        }
      }
      if (next.phase == RideFlowPhase.cancelled && prev?.phase != RideFlowPhase.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Ride cancelled')),
        );
        Future.delayed(const Duration(seconds: 2), () => ref.read(rideFlowProvider.notifier).reset());
      }
    });

    // Base markers
    final markers = <Marker>[pickupMarker(_pickup)];
    if (_dropoff != null) markers.add(dropoffMarker(_dropoff!));

    // Route polyline (to pickup before ride starts; to dropoff during ride)
    final polylines = <Polyline>[];
    if ((flow.phase == RideFlowPhase.accepted ||
            flow.phase == RideFlowPhase.driverArriving ||
            flow.phase == RideFlowPhase.driverArrived) &&
        flow.routeToPickup.isNotEmpty) {
      polylines.add(Polyline(
        points: flow.routeToPickup.map((p) => LatLng(p.$1, p.$2)).toList(),
        color: AppColors.primary,
        strokeWidth: 5,
        borderStrokeWidth: 2,
        borderColor: Colors.white,
      ));
    }
    if (flow.phase == RideFlowPhase.inProgress && flow.routeToDropoff.isNotEmpty) {
      polylines.add(Polyline(
        points: flow.routeToDropoff.map((p) => LatLng(p.$1, p.$2)).toList(),
        color: AppColors.accent,
        strokeWidth: 5,
        borderStrokeWidth: 2,
        borderColor: Colors.white,
      ));
    }

    final driverLatLng = (flow.driverLat != null && flow.driverLng != null)
        ? LatLng(flow.driverLat!, flow.driverLng!) : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 14,
              backgroundColor: AppColors.surfaceAlt,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.ridenow.rider',
                maxZoom: 20,
                retinaMode: true,
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
              // Smooth animated driver
              SmoothDriverLayer(
                target: driverLatLng,
                heading: flow.driverHeading ?? 0,
              ),
            ],
          ),
          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => Row(
                  children: [
                    _CircleBtn(icon: Icons.menu, onTap: () => Scaffold.of(context).openDrawer()),
                    const Spacer(),
                    _CircleBtn(
                      icon: _locatingUser ? Icons.gps_not_fixed_rounded : Icons.my_location_rounded,
                      onTap: () => _map.move(_pickup, 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (flow.phase == RideFlowPhase.idle) _buildIdleBottom(context),
          if (flow.phase == RideFlowPhase.searching) const SearchingOverlay(),
          if (flow.phase == RideFlowPhase.accepted ||
              flow.phase == RideFlowPhase.driverArriving ||
              flow.phase == RideFlowPhase.driverArrived)
            const Positioned(left: 0, right: 0, bottom: 0, child: DriverEnRouteSheet()),
          if (flow.phase == RideFlowPhase.inProgress)
            const Positioned(left: 0, right: 0, bottom: 0, child: RideInProgressSheet()),
        ],
      ),
    );
  }

  Widget _buildIdleBottom(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, 10)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  final r = await showModalBottomSheet<RideLocations>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => DestinationSheet(
                      initialPickup: _pickup,
                      initialPickupAddress: _pickupAddress,
                    ),
                  );
                  if (r != null) _onLocationsChosen(r.pickup, r.pickupAddress, r.dropoff, r.dropoffAddress);
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.search, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Where to?',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                            const SizedBox(height: 2),
                            const Text('Book your next ride',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: AppColors.primary)),
        ),
      ),
    );
  }
}
