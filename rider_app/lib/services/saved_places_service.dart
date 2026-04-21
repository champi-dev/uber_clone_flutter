import '../core/network/api_client.dart';
import '../models/models.dart';

class SavedPlacesService {
  final ApiClient api;
  SavedPlacesService(this.api);

  Future<List<SavedPlace>> list() async {
    final d = await api.get('/saved-places') as List;
    return d.cast<Map>().map((m) => SavedPlace.fromJson(m.cast<String, dynamic>())).toList();
  }

  Future<SavedPlace> create({required String label, required String address,
      required double lat, required double lng, String icon = 'home', int sortOrder = 0}) async {
    final d = await api.post('/saved-places', body: {
      'label': label, 'address': address, 'lat': lat, 'lng': lng, 'icon': icon, 'sort_order': sortOrder,
    });
    return SavedPlace.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<SavedPlace> update(String id, Map<String, dynamic> changes) async {
    final d = await api.put('/saved-places/$id', body: changes);
    return SavedPlace.fromJson((d as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) async { await api.delete('/saved-places/$id'); }
}
