import 'package:dio/dio.dart';
import '../constants/api_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final int? status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final Dio _dio;
  final TokenStorage storage;
  bool _refreshing = false;

  ApiClient(this.storage)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final tok = await storage.getAccess();
        if (tok != null) opts.headers['Authorization'] = 'Bearer $tok';
        handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 && !_refreshing) {
          _refreshing = true;
          try {
            final refresh = await storage.getRefresh();
            if (refresh == null) throw err;
            final r = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
                .post('/auth/refresh', data: {'refresh_token': refresh});
            final data = r.data['data'];
            await storage.save(data['access_token'], data['refresh_token']);
            final req = err.requestOptions;
            req.headers['Authorization'] = 'Bearer ${data['access_token']}';
            final retry = await _dio.fetch(req);
            return handler.resolve(retry);
          } catch (_) {
            await storage.clear();
          } finally {
            _refreshing = false;
          }
        }
        handler.next(err);
      },
    ));
  }

  Future<dynamic> _handle(Future<Response> req) async {
    try {
      final r = await req;
      final body = r.data;
      if (body is Map && body['success'] == true) return body['data'];
      throw ApiException(r.statusCode, body?['error']?.toString() ?? 'Request failed');
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['error']?.toString() : null;
      throw ApiException(e.response?.statusCode, msg ?? e.message ?? 'Network error');
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _handle(_dio.get(path, queryParameters: query));
  Future<dynamic> post(String path, {Object? body}) => _handle(_dio.post(path, data: body));
  Future<dynamic> put(String path, {Object? body}) => _handle(_dio.put(path, data: body));
  Future<dynamic> patch(String path, {Object? body}) => _handle(_dio.patch(path, data: body));
  Future<dynamic> delete(String path) => _handle(_dio.delete(path));

  /// For paginated endpoints; returns both data and pagination metadata.
  Future<({dynamic data, Map<String, dynamic>? pagination})> getPaged(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query);
      final body = r.data;
      if (body is Map && body['success'] == true) {
        return (data: body['data'], pagination: (body['pagination'] as Map?)?.cast<String, dynamic>());
      }
      throw ApiException(r.statusCode, body?['error']?.toString() ?? 'Request failed');
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['error']?.toString() : null;
      throw ApiException(e.response?.statusCode, msg ?? e.message ?? 'Network error');
    }
  }
}
