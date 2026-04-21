import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../core/socket/socket_client.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../services/saved_places_service.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.read(tokenStorageProvider)));
final socketClientProvider = Provider<SocketClient>((_) => SocketClient());

final authServiceProvider = Provider<AuthService>((ref) =>
    AuthService(ref.read(apiClientProvider), ref.read(tokenStorageProvider)));
final rideServiceProvider = Provider<RideService>((ref) => RideService(ref.read(apiClientProvider)));
final savedPlacesServiceProvider = Provider<SavedPlacesService>((ref) => SavedPlacesService(ref.read(apiClientProvider)));
final placesServiceProvider = Provider<PlacesService>((_) => PlacesService());
final locationServiceProvider = Provider<LocationService>((_) => LocationService());

/// Auth state: null = not authenticated; non-null = logged in user.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AsyncValue.loading()) { _bootstrap(); }

  Future<void> _bootstrap() async {
    final storage = ref.read(tokenStorageProvider);
    final tok = await storage.getAccess();
    if (tok == null) { state = const AsyncValue.data(null); return; }
    try {
      final u = await ref.read(authServiceProvider).me();
      state = AsyncValue.data(u);
      _connectSocket();
    } catch (_) {
      await storage.clear();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final r = await ref.read(authServiceProvider).login(email, password);
      state = AsyncValue.data(r.user);
      _connectSocket();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({required String email, required String password,
      required String fullName, required String phone}) async {
    state = const AsyncValue.loading();
    try {
      final r = await ref.read(authServiceProvider).register(
            email: email, password: password, fullName: fullName, phone: phone);
      state = AsyncValue.data(r.user);
      _connectSocket();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    ref.read(socketClientProvider).dispose();
    state = const AsyncValue.data(null);
  }

  Future<void> _connectSocket() async {
    final tok = await ref.read(tokenStorageProvider).getAccess();
    if (tok != null) ref.read(socketClientProvider).connect(tok);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) => AuthNotifier(ref));
