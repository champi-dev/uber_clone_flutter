import 'dart:io' show Platform;

class ApiConfig {
  // Override at build time, e.g.:
  //   flutter build appbundle --dart-define=API_BASE_URL=https://ridenow.champi.lat/api/v1 \
  //     --dart-define=WS_URL=https://ridenow.champi.lat
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envWsUrl = String.fromEnvironment('WS_URL');

  // For Android emulator, use 10.0.2.2 to access host. For iOS sim / desktop, localhost works.
  static String get _host {
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }

  static String get baseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : 'http://$_host:3000/api/v1';
  static String get wsUrl =>
      _envWsUrl.isNotEmpty ? _envWsUrl : 'http://$_host:3000';
  // CartoDB Voyager — clean modern cartography, no API key required for dev use.
  static const String mapTileUrl = 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String mapAttribution = '© OpenStreetMap contributors © CARTO';
}
