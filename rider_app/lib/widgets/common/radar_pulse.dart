import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RadarPulse extends StatefulWidget {
  final double size;
  final Color color;
  const RadarPulse({super.key, this.size = 260, this.color = AppColors.accent});
  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size, height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 4; i++) _ring(i),
            // Core dot with gradient
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white, widget.color]),
                boxShadow: [
                  BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(int i) {
    final offset = i * 0.25;
    final t = ((_c.value + offset) % 1.0);
    final curved = Curves.easeOut.transform(t);
    final size = widget.size * curved;
    final opacity = (1 - curved);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.color.withValues(alpha: 0.0),
            widget.color.withValues(alpha: opacity * 0.15),
            widget.color.withValues(alpha: opacity * 0.35),
          ],
          stops: const [0.5, 0.85, 1.0],
        ),
        border: Border.all(color: widget.color.withValues(alpha: opacity * 0.6), width: 1.5),
      ),
    );
  }
}
