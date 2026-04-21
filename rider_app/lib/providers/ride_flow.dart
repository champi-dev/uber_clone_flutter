import 'dart:async';
import 'dart:convert' as _conv;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';

class _JsonDecoder {
  const _JsonDecoder();
  dynamic decode(String s) => const _conv.JsonDecoder().convert(s);
}

enum RideFlowPhase { idle, searching, accepted, driverArriving, driverArrived, inProgress, completed, cancelled }

class RideFlowState {
  final RideFlowPhase phase;
  final Ride? ride;
  final double? driverLat;
  final double? driverLng;
  final double? driverHeading;
  final int? etaMinutes;
  final double? distanceRemainingKm;
  final num? currentFare;
  final Map<String, dynamic>? completion;
  final String? errorMessage;
  final List<(double, double)> routeToPickup;
  final List<(double, double)> routeToDropoff;

  const RideFlowState({
    this.phase = RideFlowPhase.idle,
    this.ride, this.driverLat, this.driverLng, this.driverHeading,
    this.etaMinutes, this.distanceRemainingKm, this.currentFare,
    this.completion, this.errorMessage,
    this.routeToPickup = const [],
    this.routeToDropoff = const [],
  });

  RideFlowState copy({
    RideFlowPhase? phase, Ride? ride,
    double? driverLat, double? driverLng, double? driverHeading,
    int? etaMinutes, double? distanceRemainingKm, num? currentFare,
    Map<String, dynamic>? completion, String? errorMessage,
    List<(double, double)>? routeToPickup,
    List<(double, double)>? routeToDropoff,
  }) => RideFlowState(
    phase: phase ?? this.phase,
    ride: ride ?? this.ride,
    driverLat: driverLat ?? this.driverLat,
    driverLng: driverLng ?? this.driverLng,
    driverHeading: driverHeading ?? this.driverHeading,
    etaMinutes: etaMinutes ?? this.etaMinutes,
    distanceRemainingKm: distanceRemainingKm ?? this.distanceRemainingKm,
    currentFare: currentFare ?? this.currentFare,
    completion: completion ?? this.completion,
    errorMessage: errorMessage,
    routeToPickup: routeToPickup ?? this.routeToPickup,
    routeToDropoff: routeToDropoff ?? this.routeToDropoff,
  );
}

List<(double, double)> _parseRoute(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((m) =>
        ((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble())).toList();
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = const _JsonDecoder().decode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((m) =>
            ((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble())).toList();
      }
    } catch (_) {}
  }
  return const [];
}

class RideFlowNotifier extends StateNotifier<RideFlowState> {
  final Ref ref;
  StreamSubscription? _sub;
  String? _currentRideId;

  RideFlowNotifier(this.ref) : super(const RideFlowState());

  Future<void> request({
    required double pickupLat, required double pickupLng, required String pickupAddress,
    required double dropoffLat, required double dropoffLng, required String dropoffAddress,
    required String vehicleType, String? promoCode,
  }) async {
    state = state.copy(phase: RideFlowPhase.searching, errorMessage: null);
    try {
      final res = await ref.read(rideServiceProvider).create(
        pickupLat: pickupLat, pickupLng: pickupLng, pickupAddress: pickupAddress,
        dropoffLat: dropoffLat, dropoffLng: dropoffLng, dropoffAddress: dropoffAddress,
        vehicleType: vehicleType, promoCode: promoCode,
      );
      state = state.copy(phase: RideFlowPhase.searching, ride: res.ride);
      _attachSocket(res.ride.id);
    } catch (e) {
      state = state.copy(phase: RideFlowPhase.idle, errorMessage: e.toString());
      rethrow;
    }
  }

  void _attachSocket(String rideId) {
    _currentRideId = rideId;
    final sc = ref.read(socketClientProvider);
    sc.joinRide(rideId);
    final s = sc.socket;
    if (s == null) return;
    s.off('ride:accepted');
    s.off('ride:driver_arriving');
    s.off('ride:driver_arrived');
    s.off('ride:started');
    s.off('ride:location_tick');
    s.off('ride:completed');
    s.off('ride:cancelled');
    s.off('ride:no_drivers');

    s.on('ride:accepted', (data) async {
      if (data['ride_id'] != rideId) return;
      final ride = await ref.read(rideServiceProvider).get(rideId);
      final loc = data['driver_location'] as Map?;
      state = state.copy(
        phase: RideFlowPhase.accepted,
        ride: ride,
        driverLat: (loc?['lat'] as num?)?.toDouble(),
        driverLng: (loc?['lng'] as num?)?.toDouble(),
        etaMinutes: (data['eta_minutes'] as num?)?.toInt(),
        routeToPickup: _parseRoute(data['route_to_pickup']),
      );
    });
    s.on('ride:driver_arriving', (data) {
      if (data['ride_id'] != rideId) return;
      final loc = (data['driver_location'] as Map?) ?? {};
      state = state.copy(
        phase: state.phase == RideFlowPhase.accepted ? RideFlowPhase.driverArriving : state.phase,
        driverLat: (loc['lat'] as num?)?.toDouble(),
        driverLng: (loc['lng'] as num?)?.toDouble(),
        driverHeading: (loc['heading'] as num?)?.toDouble(),
        etaMinutes: (data['eta_minutes'] as num?)?.toInt(),
        distanceRemainingKm: (data['distance_km'] as num?)?.toDouble(),
      );
    });
    s.on('ride:driver_arrived', (data) {
      if (data['ride_id'] != rideId) return;
      state = state.copy(phase: RideFlowPhase.driverArrived);
    });
    s.on('ride:started', (data) async {
      if (data['ride_id'] != rideId) return;
      final ride = await ref.read(rideServiceProvider).get(rideId);
      state = state.copy(
        phase: RideFlowPhase.inProgress,
        ride: ride,
        routeToDropoff: _parseRoute(data['route_polyline']),
        etaMinutes: (data['eta_minutes'] as num?)?.toInt(),
      );
    });
    s.on('ride:location_tick', (data) {
      if (data['ride_id'] != rideId) return;
      state = state.copy(
        driverLat: (data['lat'] as num?)?.toDouble(),
        driverLng: (data['lng'] as num?)?.toDouble(),
        driverHeading: (data['heading'] as num?)?.toDouble(),
        etaMinutes: (data['eta_minutes'] as num?)?.toInt(),
        distanceRemainingKm: (data['distance_remaining_km'] as num?)?.toDouble(),
        currentFare: data['fare_current'] as num?,
      );
    });
    s.on('ride:completed', (data) {
      if (data['ride_id'] != rideId) return;
      state = state.copy(
        phase: RideFlowPhase.completed,
        completion: (data as Map).cast<String, dynamic>(),
      );
    });
    s.on('ride:cancelled', (data) {
      if (data['ride_id'] != rideId) return;
      state = state.copy(phase: RideFlowPhase.cancelled);
    });
    s.on('ride:no_drivers', (data) {
      if (data['ride_id'] != rideId) return;
      state = state.copy(phase: RideFlowPhase.cancelled, errorMessage: 'No drivers available');
    });
  }

  Future<void> cancel() async {
    final id = state.ride?.id;
    if (id == null) return;
    try {
      await ref.read(rideServiceProvider).cancel(id, reason: 'Cancelled by rider');
      state = state.copy(phase: RideFlowPhase.cancelled);
    } catch (e) {
      state = state.copy(errorMessage: e.toString());
    }
  }

  Future<void> rate(int score, {String? comment, List<String>? tags}) async {
    final id = state.ride?.id;
    if (id == null) return;
    await ref.read(rideServiceProvider).rate(id, score, comment: comment, tags: tags);
    reset();
  }

  void reset() {
    if (_currentRideId != null) ref.read(socketClientProvider).leaveRide(_currentRideId!);
    _currentRideId = null;
    state = const RideFlowState();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}

final rideFlowProvider = StateNotifierProvider<RideFlowNotifier, RideFlowState>((ref) => RideFlowNotifier(ref));
