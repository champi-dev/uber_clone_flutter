import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/ride_flow.dart';
import '../../widgets/common/odometer_text.dart';

class RideInProgressSheet extends ConsumerWidget {
  const RideInProgressSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(rideFlowProvider);
    final ride = flow.ride;
    final estDist = ride?.estimatedDistanceKm ?? 1.0;
    final remain = flow.distanceRemainingKm ?? estDist;
    final progress = ((estDist - remain) / estDist).clamp(0.0, 1.0);
    final almostThere = progress >= 0.9;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation(almostThere ? AppColors.accent : AppColors.primary),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, -6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(almostThere ? Icons.flag_circle_rounded : Icons.directions_car_filled_rounded,
                        color: almostThere ? AppColors.accent : AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      almostThere ? 'Almost there' : 'On trip',
                      style: TextStyle(
                        color: almostThere ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (flow.etaMinutes != null)
                      OdometerText('${flow.etaMinutes} min',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(ride?.dropoffAddress ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _Stat(label: 'Remaining', value: formatKm(remain))),
                    Container(width: 1, height: 36, color: AppColors.border),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Fare', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          OdometerText(
                            flow.currentFare != null ? formatCop(flow.currentFare!) : '—',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label; final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        OdometerText(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
      ],
    );
  }
}
