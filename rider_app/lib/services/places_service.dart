import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

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

/// Google Places (legacy REST). Biased to Montería, Colombia.
/// NOTE: In a production app the key must NOT ship in the client bundle — proxy via backend.
/// For this local demo bundling is acceptable.
class PlacesService {
  static const _monteriaLat = 8.7530;
  static const _monteriaLng = -75.8820;
  static const _radiusMeters = 30000;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://maps.googleapis.com/maps/api/place',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  String? _sessionToken;
  String _ensureSession() => _sessionToken ??= const Uuid().v4();
  void _resetSession() { _sessionToken = null; }

  String get _key => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 2 || _key.isEmpty) return [];
    final r = await _dio.get('/autocomplete/json', queryParameters: {
      'input': query,
      'key': _key,
      'sessiontoken': _ensureSession(),
      'location': '$_monteriaLat,$_monteriaLng',
      'radius': _radiusMeters,
      'components': 'country:co',
      'language': 'es',
    });
    final data = r.data as Map;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      throw Exception('Places error: ${data['status']} ${data['error_message'] ?? ''}');
    }
    final preds = (data['predictions'] as List? ?? []).cast<Map>();
    return preds.map((p) {
      final sf = (p['structured_formatting'] as Map?) ?? {};
      return PlaceSuggestion(
        placeId: p['place_id'] as String,
        mainText: (sf['main_text'] as String?) ?? p['description'] as String,
        secondaryText: (sf['secondary_text'] as String?) ?? '',
      );
    }).toList();
  }

  Future<PlaceDetail> details(String placeId) async {
    if (_key.isEmpty) throw Exception('Google Places API key missing');
    final r = await _dio.get('/details/json', queryParameters: {
      'place_id': placeId,
      'key': _key,
      'sessiontoken': _ensureSession(),
      'fields': 'formatted_address,name,geometry',
      'language': 'es',
    });
    _resetSession(); // one session per autocomplete→details cycle
    final data = r.data as Map;
    if (data['status'] != 'OK') {
      throw Exception('Places error: ${data['status']} ${data['error_message'] ?? ''}');
    }
    final res = data['result'] as Map;
    final loc = (res['geometry'] as Map)['location'] as Map;
    final address = (res['formatted_address'] as String?) ?? (res['name'] as String? ?? 'Selected place');
    return PlaceDetail(
      address: address,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }
}
