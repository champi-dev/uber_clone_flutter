import 'package:dio/dio.dart';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  PlaceSuggestion({required this.placeId, required this.mainText, required this.secondaryText});
  String get display => secondaryText.isEmpty ? mainText : '$mainText, $secondaryText';
}

class PlaceDetail {
  final String address;
  final double lat;
  final double lng;
  PlaceDetail({required this.address, required this.lat, required this.lng});
}

/// Free geocoding via OpenStreetMap Nominatim — no API key required.
/// Biased to Montería, Colombia. Coordinates come with each suggestion,
/// so `details` is a local lookup (no second request).
class PlacesService {
  static const _monteriaLat = 8.7530;
  static const _monteriaLng = -75.8820;
  static const _viewboxDelta = 0.27; // ~30 km

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'RideNow/1.0 (ridenow.champi.lat)'},
  ));

  final Map<String, PlaceDetail> _detailsCache = {};

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 2) return [];
    final r = await _dio.get('/search', queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'limit': 6,
      'addressdetails': 1,
      'countrycodes': 'co',
      'accept-language': 'es',
      'viewbox':
          '${_monteriaLng - _viewboxDelta},${_monteriaLat + _viewboxDelta},'
          '${_monteriaLng + _viewboxDelta},${_monteriaLat - _viewboxDelta}',
    });
    final results = (r.data as List).cast<Map>();
    return results.map((p) {
      final id = '${p['osm_type']}:${p['osm_id']}';
      final displayName = p['display_name'] as String;
      final main = (p['name'] as String?)?.isNotEmpty == true
          ? p['name'] as String
          : displayName.split(',').first;
      final secondary = displayName
          .split(',')
          .skip(1)
          .take(3)
          .map((s) => s.trim())
          .join(', ');
      _detailsCache[id] = PlaceDetail(
        address: displayName.split(',').take(3).map((s) => s.trim()).join(', '),
        lat: double.parse(p['lat'] as String),
        lng: double.parse(p['lon'] as String),
      );
      return PlaceSuggestion(placeId: id, mainText: main, secondaryText: secondary);
    }).toList();
  }

  Future<PlaceDetail> details(String placeId) async {
    final cached = _detailsCache[placeId];
    if (cached != null) return cached;
    throw Exception('Unknown place: $placeId');
  }
}
