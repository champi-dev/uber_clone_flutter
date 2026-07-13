import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

class DeviceLocation {
  final LatLng point;
  final String address;
  DeviceLocation(this.point, this.address);
}

class LocationService {
  final Dio _dio = Dio();

  Future<LatLng?> currentPoint() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode via free OSM Nominatim. Returns a human-readable address.
  Future<String?> reverseGeocode(LatLng p) async {
    try {
      final r = await _dio.get('https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': p.latitude,
            'lon': p.longitude,
            'format': 'jsonv2',
            'accept-language': 'es',
          },
          options: Options(headers: {'User-Agent': 'RideNow/1.0 (ridenow.champi.lat)'}));
      final name = r.data['display_name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name.split(',').take(3).map((s) => s.trim()).join(', ');
      }
    } catch (_) {}
    return null;
  }
}
