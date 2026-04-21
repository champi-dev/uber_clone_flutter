import 'package:flutter/material.dart';

/// Animates value changes with a vertical slide (like a fare odometer).
class OdometerText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const OdometerText(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final up = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(anim);
        return ClipRect(
          child: SlideTransition(
            position: up,
            child: FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Text(value, key: ValueKey(value), style: style),
    );
  }
}
