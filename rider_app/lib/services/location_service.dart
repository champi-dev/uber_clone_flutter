import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  /// Reverse geocode via Google Geocoding API. Returns a human-readable address.
  Future<String?> reverseGeocode(LatLng p) async {
    final key = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (key.isEmpty) return null;
    try {
      final r = await _dio.get('https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {'latlng': '${p.latitude},${p.longitude}', 'key': key, 'language': 'es'});
      if (r.data['status'] == 'OK' && (r.data['results'] as List).isNotEmpty) {
        return r.data['results'][0]['formatted_address'] as String;
      }
    } catch (_) {}
    return null;
  }
}
