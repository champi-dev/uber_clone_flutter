import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/ride_flow.dart';

class RideCompleteSheet extends ConsumerStatefulWidget {
  const RideCompleteSheet({super.key});
  @override
  ConsumerState<RideCompleteSheet> createState() => _RideCompleteSheetState();
}

class _RideCompleteSheetState extends ConsumerState<RideCompleteSheet> {
  int _score = 0;
  final _comment = TextEditingController();
  final Set<String> _tags = {};
  bool _submitting = false;

  final _tagOptions = const ['Great conversation', 'Clean car', 'Smooth ride', 'Excellent navigation'];

  Future<void> _submit() async {
    if (_score == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(rideFlowProvider.notifier).rate(
        _score,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        tags: _tags.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _skip() {
    ref.read(rideFlowProvider.notifier).reset();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
    final c = flow.completion ?? {};
    final fare = c['actual_fare'] as num?;
    final distance = c['distance_km'] as num?;
    final duration = c['duration_min'] as num?;
    final breakdown = (c['fare_breakdown'] as Map?)?.cast<String, dynamic>();
    final driverName = flow.ride?.driver?.fullName ?? 'your driver';

    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.6, maxChildSize: 0.95, expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Center(
              child: CircleAvatar(
                radius: 32, backgroundColor: AppColors.success,
                child: Icon(Icons.check, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('Ride Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Paid', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  if (fare != null)
                    Text(formatCop(fare), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (distance != null && duration != null)
                    Text('${formatKm(distance)} • ${formatMin(duration)}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  if (breakdown != null) ...[
                    const Divider(height: 24),
                    _BreakdownRow('Base fare', breakdown['base_fare']),
                    _BreakdownRow('Distance', breakdown['distance_charge']),
                    _BreakdownRow('Time', breakdown['time_charge']),
                    _BreakdownRow('Booking fee', breakdown['booking_fee']),
                    if ((breakdown['discount_amount'] as num? ?? 0) > 0)
                      _BreakdownRow('Discount', -(breakdown['discount_amount'] as num), color: AppColors.success),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('How was your ride with $driverName?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _score;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _score = i + 1);
                  },
                  child: AnimatedScale(
                    scale: filled ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber, size: 44),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: _tagOptions.map((t) {
                final sel = _tags.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (v) => setState(() { if (v) _tags.add(t); else _tags.remove(t); }),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Rating'),
            ),
            TextButton(onPressed: _skip, child: const Text('Skip')),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final num? value;
  final Color? color;
  const _BreakdownRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(formatCop(value!), style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
