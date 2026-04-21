import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ride_flow.dart';

class DriverEnRouteSheet extends ConsumerStatefulWidget {
  const DriverEnRouteSheet({super.key});
  @override
  ConsumerState<DriverEnRouteSheet> createState() => _DriverEnRouteSheetState();
}

class _DriverEnRouteSheetState extends ConsumerState<DriverEnRouteSheet> {
  bool _hapticFired = false;

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
    final driver = flow.ride?.driver;
    final vehicle = flow.ride?.vehicle;
    final isArrived = flow.phase == RideFlowPhase.driverArrived;

    if (flow.etaMinutes != null && flow.etaMinutes! <= 1 && !_hapticFired) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    }

    final statusText = isArrived
        ? 'Your driver is here'
        : flow.etaMinutes != null
            ? '${flow.etaMinutes} min away'
            : 'On the way…';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      child: SafeArea(
        key: ValueKey(isArrived),
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, -6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 16),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isArrived ? AppColors.accent.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: isArrived ? AppColors.accent : AppColors.primary, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(statusText, style: TextStyle(color: isArrived ? AppColors.accent : AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 28, backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 26, backgroundColor: AppColors.primary,
                        child: Text(
                          (driver?.fullName.isNotEmpty ?? false) ? driver!.fullName[0].toUpperCase() : 'D',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver?.fullName ?? 'Driver',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(driver?.ratingAvg.toStringAsFixed(2) ?? '—',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          if (vehicle != null) ...[
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${vehicle.color} ${vehicle.make}',
                                style: const TextStyle(color: AppColors.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  if (vehicle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary, borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(vehicle.plateNumber,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showCall(context, driver?.fullName ?? 'Driver');
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Contact'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    onPressed: () => _confirmCancel(context, ref),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancel'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showCall(BuildContext ctx, String name) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Calling $name…'),
        content: const Text('00:05\n\n(simulated call)'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hang up'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext ctx, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel ride?'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(rideFlowProvider.notifier).cancel();
  }
}
