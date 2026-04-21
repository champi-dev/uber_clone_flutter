import '../core/network/api_client.dart';
import '../models/models.dart';

class RideService {
  final ApiClient api;
  RideService(this.api);

  Future<FareEstimate> estimate({
    required double pickupLat, required double pickupLng,
    required double dropoffLat, required double dropoffLng,
    required String vehicleType, String? promoCode,
  }) async {
    final d = await api.get('/fare/estimate', query: {
      'pickup_lat': pickupLat, 'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat, 'dropoff_lng': dropoffLng,
      'vehicle_type': vehicleType,
      if (promoCode != null) 'promo_code': promoCode,
    });
    return FareEstimate.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<({Ride ride, FareEstimate estimate})> create({
    required double pickupLat, required double pickupLng, required String pickupAddress,
    required double dropoffLat, required double dropoffLng, required String dropoffAddress,
    required String vehicleType, String? promoCode,
  }) async {
    final d = await api.post('/rides', body: {
      'pickup_lat': pickupLat, 'pickup_lng': pickupLng, 'pickup_address': pickupAddress,
      'dropoff_lat': dropoffLat, 'dropoff_lng': dropoffLng, 'dropoff_address': dropoffAddress,
      'vehicle_type_requested': vehicleType,
      if (promoCode != null) 'promo_code': promoCode,
    });
    final m = (d as Map).cast<String, dynamic>();
    return (
      ride: Ride.fromJson((m['ride'] as Map).cast<String, dynamic>()),
      estimate: FareEstimate.fromJson((m['estimate'] as Map).cast<String, dynamic>()),
    );
  }

  Future<Ride> get(String id) async {
    final d = await api.get('/rides/$id');
    return Ride.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<Ride> cancel(String id, {String? reason}) async {
    final d = await api.patch('/rides/$id/cancel', body: {if (reason != null) 'reason': reason});
    return Ride.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<void> rate(String id, int score, {String? comment, List<String>? tags}) async {
    await api.post('/rides/$id/rate', body: {
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });
  }

  Future<List<Ride>> history({int page = 1, int limit = 20, String? status}) async {
    final r = await api.getPaged('/rides/history', query: {
      'page': page, 'limit': limit, if (status != null && status != 'all') 'status': status,
    });
    return ((r.data as List).cast<Map>()).map((m) => Ride.fromJson(m.cast<String, dynamic>())).toList();
  }

  Future<Map<String, dynamic>> validatePromo(String code) async {
    final d = await api.post('/promo/validate', body: {'code': code});
    return (d as Map).cast<String, dynamic>();
  }
}
