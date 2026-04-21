import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../providers/ride_flow.dart';

class VehicleSelectSheet extends ConsumerStatefulWidget {
  final LatLng pickup; final String pickupAddress;
  final LatLng dropoff; final String dropoffAddress;
  const VehicleSelectSheet({
    super.key,
    required this.pickup, required this.pickupAddress,
    required this.dropoff, required this.dropoffAddress,
  });
  @override
  ConsumerState<VehicleSelectSheet> createState() => _VehicleSelectSheetState();
}

class _VehicleSelectSheetState extends ConsumerState<VehicleSelectSheet> {
  final Map<String, FareEstimate> _estimates = {};
  bool _loading = true;
  String _selected = 'economy';
  String? _error;
  String? _promoCode;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      for (final t in vehicleTypes) {
        final e = await ref.read(rideServiceProvider).estimate(
          pickupLat: widget.pickup.latitude, pickupLng: widget.pickup.longitude,
          dropoffLat: widget.dropoff.latitude, dropoffLng: widget.dropoff.longitude,
          vehicleType: t, promoCode: _promoCode,
        );
        _estimates[t] = e;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyPromo() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apply promo code'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. RIDENOW50')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim().toUpperCase()), child: const Text('Apply')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref.read(rideServiceProvider).validatePromo(code);
      setState(() { _promoCode = code; _promoError = null; });
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo applied!'), backgroundColor: AppColors.success));
    } catch (e) {
      setState(() => _promoError = e.toString());
    }
  }

  Future<void> _confirm() async {
    Navigator.pop(context); // close sheet first
    try {
      await ref.read(rideFlowProvider.notifier).request(
        pickupLat: widget.pickup.latitude, pickupLng: widget.pickup.longitude, pickupAddress: widget.pickupAddress,
        dropoffLat: widget.dropoff.latitude, dropoffLng: widget.dropoff.longitude, dropoffAddress: widget.dropoffAddress,
        vehicleType: _selected, promoCode: _promoCode,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            _RoutePreview(pickup: widget.pickupAddress, dropoff: widget.dropoffAddress),
            const SizedBox(height: 16),
            const Text('Choose a ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error))
            else
              ...vehicleTypes.map((t) {
                final est = _estimates[t];
                final selected = _selected == t;
                return GestureDetector(
                  onTap: () => setState(() => _selected = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                    ),
                    child: Row(children: [
                      Icon(_iconFor(t), size: 36, color: AppColors.secondary),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicleTypeLabel(t), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            est != null ? '${formatMin(est.estimatedDurationMin)} • ${formatKm(est.estimatedDistanceKm)}' : '…',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      )),
                      Text(
                        est != null ? formatCop(est.estimatedFare) : '...',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 12),
            InkWell(
              onTap: _applyPromo,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(_promoCode != null ? 'Promo: $_promoCode' : 'Have a promo code?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            if (_promoError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_promoError!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _confirm,
              child: const Text('Confirm RideNow'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String t) => switch (t) {
        'economy' => Icons.directions_car_filled,
        'comfort' => Icons.airline_seat_recline_normal,
        'premium' => Icons.star,
        'xl' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };
}

class _RoutePreview extends StatelessWidget {
  final String pickup; final String dropoff;
  const _RoutePreview({required this.pickup, required this.dropoff});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        const Icon(Icons.trip_origin, color: AppColors.success, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const Padding(padding: EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: SizedBox(height: 12, child: VerticalDivider(width: 1, thickness: 1))),
      Row(children: [
        const Icon(Icons.location_on, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(dropoff, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }
}
