// Minimal data classes — avoid codegen for demo simplicity.

class User {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String role;
  final double ratingAvg;
  final int ratingCount;

  User({required this.id, required this.email, required this.fullName, required this.phone,
    this.avatarUrl, required this.role, required this.ratingAvg, required this.ratingCount});

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'],
    email: j['email'] ?? '',
    fullName: j['fullName'] ?? j['full_name'] ?? '',
    phone: j['phone'] ?? '',
    avatarUrl: j['avatarUrl'] ?? j['avatar_url'],
    role: j['role'] ?? 'rider',
    ratingAvg: (j['ratingAvg'] ?? j['rating_avg'] ?? 5.0).toDouble(),
    ratingCount: (j['ratingCount'] ?? j['rating_count'] ?? 0) as int,
  );
}

class Vehicle {
  final String id;
  final String vehicleType;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  final int capacity;

  Vehicle({required this.id, required this.vehicleType, required this.make, required this.model,
    required this.year, required this.color, required this.plateNumber, required this.capacity});

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'],
    vehicleType: j['vehicleType'] ?? j['vehicle_type'],
    make: j['make'], model: j['model'], year: j['year'],
    color: j['color'], plateNumber: j['plateNumber'] ?? j['plate_number'],
    capacity: j['capacity'] ?? 4,
  );
}

class SavedPlace {
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final String icon;
  final int sortOrder;

  SavedPlace({required this.id, required this.label, required this.address,
    required this.lat, required this.lng, required this.icon, required this.sortOrder});

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
    id: j['id'],
    label: j['label'],
    address: j['address'],
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    icon: j['icon'] ?? 'home',
    sortOrder: (j['sortOrder'] ?? j['sort_order'] ?? 0) as int,
  );
}

class FareEstimate {
  final num estimatedFare;
  final double estimatedDistanceKm;
  final int estimatedDurationMin;
  final double surgeMultiplier;
  final String vehicleType;
  final Map<String, dynamic> breakdown;

  FareEstimate({required this.estimatedFare, required this.estimatedDistanceKm,
    required this.estimatedDurationMin, required this.surgeMultiplier,
    required this.vehicleType, required this.breakdown});

  factory FareEstimate.fromJson(Map<String, dynamic> j) => FareEstimate(
    estimatedFare: j['estimated_fare'] as num,
    estimatedDistanceKm: (j['estimated_distance_km'] as num).toDouble(),
    estimatedDurationMin: (j['estimated_duration_min'] as num).toInt(),
    surgeMultiplier: (j['surge_multiplier'] as num).toDouble(),
    vehicleType: j['vehicle_type'],
    breakdown: (j['fare_breakdown'] as Map).cast<String, dynamic>(),
  );
}

class Ride {
  final String id;
  final String status;
  final String vehicleTypeRequested;
  final String pickupAddress;
  final double pickupLat, pickupLng;
  final String dropoffAddress;
  final double dropoffLat, dropoffLng;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;
  final num? estimatedFare;
  final num? actualFare;
  final String? routePolyline;
  final User? driver;
  final Vehicle? vehicle;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final num? actualDistanceKm;
  final int? actualDurationMin;
  final Map<String, dynamic>? rating;

  Ride({
    required this.id, required this.status, required this.vehicleTypeRequested,
    required this.pickupAddress, required this.pickupLat, required this.pickupLng,
    required this.dropoffAddress, required this.dropoffLat, required this.dropoffLng,
    this.estimatedDistanceKm, this.estimatedDurationMin,
    this.estimatedFare, this.actualFare,
    this.routePolyline, this.driver, this.vehicle,
    required this.requestedAt, this.completedAt, this.cancelledAt,
    this.cancellationReason, this.cancelledBy,
    this.actualDistanceKm, this.actualDurationMin, this.rating,
  });

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
    id: j['id'],
    status: j['status'],
    vehicleTypeRequested: j['vehicleTypeRequested'] ?? j['vehicle_type_requested'],
    pickupAddress: j['pickupAddress'] ?? j['pickup_address'],
    pickupLat: (j['pickupLat'] ?? j['pickup_lat'] as num).toDouble(),
    pickupLng: (j['pickupLng'] ?? j['pickup_lng'] as num).toDouble(),
    dropoffAddress: j['dropoffAddress'] ?? j['dropoff_address'],
    dropoffLat: (j['dropoffLat'] ?? j['dropoff_lat'] as num).toDouble(),
    dropoffLng: (j['dropoffLng'] ?? j['dropoff_lng'] as num).toDouble(),
    estimatedDistanceKm: (j['estimatedDistanceKm'] ?? j['estimated_distance_km'])?.toDouble(),
    estimatedDurationMin: (j['estimatedDurationMin'] ?? j['estimated_duration_min'])?.toInt(),
    estimatedFare: j['estimatedFare'] ?? j['estimated_fare'],
    actualFare: j['actualFare'] ?? j['actual_fare'],
    routePolyline: j['routePolyline'] ?? j['route_polyline'],
    driver: j['driver'] != null ? User.fromJson((j['driver'] as Map).cast<String, dynamic>()) : null,
    vehicle: j['vehicle'] != null ? Vehicle.fromJson((j['vehicle'] as Map).cast<String, dynamic>()) : null,
    requestedAt: DateTime.parse(j['requestedAt'] ?? j['requested_at']),
    completedAt: _dt(j['completedAt'] ?? j['completed_at']),
    cancelledAt: _dt(j['cancelledAt'] ?? j['cancelled_at']),
    cancellationReason: j['cancellationReason'] ?? j['cancellation_reason'],
    cancelledBy: j['cancelledBy'] ?? j['cancelled_by'],
    actualDistanceKm: j['actualDistanceKm'] ?? j['actual_distance_km'],
    actualDurationMin: j['actualDurationMin'] ?? j['actual_duration_min'],
    rating: j['rating'] == null ? null : (j['rating'] as Map).cast<String, dynamic>(),
  );

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v.toString());
}

const vehicleTypes = ['economy', 'comfort', 'premium', 'xl'];

String vehicleTypeLabel(String t) {
  switch (t) {
    case 'economy': return 'Economy';
    case 'comfort': return 'Comfort';
    case 'premium': return 'Premium';
    case 'xl': return 'XL';
  }
  return t;
}
