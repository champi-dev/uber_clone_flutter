import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../models/models.dart';

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final User user;
  AuthResult(this.accessToken, this.refreshToken, this.user);
}

class AuthService {
  final ApiClient api;
  final TokenStorage storage;
  AuthService(this.api, this.storage);

  Future<AuthResult> register({
    required String email, required String password,
    required String fullName, required String phone,
  }) async {
    final d = await api.post('/auth/register', body: {
      'email': email, 'password': password, 'full_name': fullName, 'phone': phone, 'role': 'rider',
    });
    return _pack(d);
  }

  Future<AuthResult> login(String email, String password) async {
    final d = await api.post('/auth/login', body: {'email': email, 'password': password});
    return _pack(d);
  }

  Future<User> me() async {
    final d = await api.get('/auth/me');
    return User.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    final r = await storage.getRefresh();
    if (r != null) {
      try { await api.post('/auth/logout', body: {'refresh_token': r}); } catch (_) {}
    }
    await storage.clear();
  }

  Future<AuthResult> _pack(dynamic d) async {
    final m = (d as Map).cast<String, dynamic>();
    final a = m['access_token'] as String;
    final r = m['refresh_token'] as String;
    await storage.save(a, r);
    return AuthResult(a, r, User.fromJson((m['user'] as Map).cast<String, dynamic>()));
  }
}
