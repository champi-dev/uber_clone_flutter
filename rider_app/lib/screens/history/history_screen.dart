import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all';
  Future<List<Ride>>? _future;

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    setState(() {
      _future = ref.read(rideServiceProvider).history(status: _filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Rides')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _chip('all', 'All'),
              const SizedBox(width: 8),
              _chip('completed', 'Completed'),
              const SizedBox(width: 8),
              _chip('cancelled', 'Cancelled'),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: FutureBuilder<List<Ride>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                  final rides = snap.data ?? [];
                  if (rides.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      Icon(Icons.history, size: 80, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Center(child: Text('No rides yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16))),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RideCard(ride: rides[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) { setState(() => _filter = value); _load(); },
      selectedColor: AppColors.primary.withOpacity(0.15),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Ride ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final cancelled = ride.status == 'cancelled';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formatDate(ride.requestedAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cancelled ? AppColors.error.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cancelled ? 'Cancelled' : 'Completed',
                    style: TextStyle(
                      color: cancelled ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w600, fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.trip_origin, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(child: Text(ride.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(ride.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                if (ride.driver != null) ...[
                  CircleAvatar(
                    radius: 14, backgroundColor: AppColors.secondary,
                    child: Text(ride.driver!.fullName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ride.driver!.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
                ] else
                  const Expanded(child: Text('—')),
                Text(
                  (ride.actualFare ?? ride.estimatedFare) != null
                      ? formatCop(ride.actualFare ?? ride.estimatedFare!) : '—',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
