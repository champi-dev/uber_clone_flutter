import 'dart:io' show Platform;

class ApiConfig {
  // For Android emulator, use 10.0.2.2 to access host. For iOS sim / desktop, localhost works.
  static String get _host {
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }

  static String get baseUrl => 'http://$_host:3000/api/v1';
  static String get wsUrl => 'http://$_host:3000';
  // CartoDB Voyager — clean modern cartography, no API key required for dev use.
  static const String mapTileUrl = 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String mapAttribution = '© OpenStreetMap contributors © CARTO';
}
