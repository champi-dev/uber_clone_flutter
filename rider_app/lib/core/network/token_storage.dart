import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  final _s = const FlutterSecureStorage();

  Future<String?> getAccess() => _s.read(key: _access);
  Future<String?> getRefresh() => _s.read(key: _refresh);
  Future<void> save(String access, String refresh) async {
    await _s.write(key: _access, value: access);
    await _s.write(key: _refresh, value: refresh);
  }
  Future<void> clear() async {
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
  }
}
