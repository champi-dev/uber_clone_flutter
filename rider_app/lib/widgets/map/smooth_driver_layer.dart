import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_view.dart';

/// MarkerLayer whose driver position tweens smoothly between ticks.
class SmoothDriverLayer extends StatefulWidget {
  final LatLng? target;
  final double heading;
  final Duration duration;
  const SmoothDriverLayer({
    super.key,
    required this.target,
    required this.heading,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<SmoothDriverLayer> createState() => _SmoothDriverLayerState();
}

class _SmoothDriverLayerState extends State<SmoothDriverLayer> {
  LatLng? _from;
  LatLng? _to;
  double _headingFrom = 0;
  double _headingTo = 0;

  @override
  void didUpdateWidget(covariant SmoothDriverLayer old) {
    super.didUpdateWidget(old);
    if (widget.target != null && widget.target != _to) {
      _from = _to ?? widget.target;
      _to = widget.target;
      _headingFrom = _headingTo;
      _headingTo = widget.heading;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.target != null) {
      _to = widget.target;
      _from = widget.target;
      _headingTo = widget.heading;
      _headingFrom = widget.heading;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_to == null || _from == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(_to),
      tween: Tween(begin: 0, end: 1),
      duration: widget.duration,
      curve: Curves.linear,
      builder: (_, t, __) {
        final lat = _from!.latitude + (_to!.latitude - _from!.latitude) * t;
        final lng = _from!.longitude + (_to!.longitude - _from!.longitude) * t;
        final h = _lerpAngle(_headingFrom, _headingTo, Curves.easeOut.transform(t));
        return MarkerLayer(markers: [buildDriverMarker(LatLng(lat, lng), h)]);
      },
    );
  }

  double _lerpAngle(double a, double b, double t) {
    final diff = ((b - a + 540) % 360) - 180;
    return a + diff * t;
  }
}
