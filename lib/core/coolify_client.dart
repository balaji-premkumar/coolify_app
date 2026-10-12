import 'package:dio/dio.dart';

class TokenRejected implements Exception {
  @override
  String toString() => 'Token expired or revoked';
}

/// Thin Coolify v4 API client. Only what the shell needs for now.
class CoolifyClient {
  CoolifyClient({required String baseUrl, required String token})
      : dio = Dio(BaseOptions(
          baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1',
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    dio.interceptors.add(InterceptorsWrapper(onError: (e, h) {
      if (e.response?.statusCode == 401) {
        return h.reject(DioException(
            requestOptions: e.requestOptions, error: TokenRejected(), response: e.response));
      }
      h.next(e);
    }));
  }

  final Dio dio;

  Future<String> version() async => (await dio.get<String>('/version')).data!.trim();

  Future<Map<String, dynamic>> currentTeam() async =>
      Map<String, dynamic>.from((await dio.get('/teams/current')).data as Map);

  Future<List<dynamic>> _list(String path, [Map<String, dynamic>? q]) async {
    final d = (await dio.get(path, queryParameters: q)).data;
    if (d is List) return d;
    // Some endpoints wrap the list, e.g. {"deployments": [...]}.
    if (d is Map) {
      for (final v in d.values) {
        if (v is List) return v;
      }
    }
    return const [];
  }

  Future<List<dynamic>> servers() => _list('/servers');
  Future<List<dynamic>> resources() => _list('/resources');
  Future<List<dynamic>> runningDeployments() => _list('/deployments');
  Future<List<dynamic>> applicationDeployments(String uuid) =>
      _list('/deployments/applications/$uuid', {'skip': 0, 'take': 30});
  Future<List<dynamic>> serverResources(String uuid) => _list('/servers/$uuid/resources');

  Future<Map<String, dynamic>> _map(String path, [Map<String, dynamic>? q]) async =>
      Map<String, dynamic>.from((await dio.get(path, queryParameters: q)).data as Map);

  Future<Map<String, dynamic>> server(String uuid) => _map('/servers/$uuid');
  Future<Map<String, dynamic>> application(String uuid) => _map('/applications/$uuid');
  Future<Map<String, dynamic>> database(String uuid) => _map('/databases/$uuid');
  Future<Map<String, dynamic>> service(String uuid) => _map('/services/$uuid');
  Future<Map<String, dynamic>> deployment(String uuid) => _map('/deployments/$uuid');

  /// Runtime container logs. Only applications expose this endpoint.
  Future<String> applicationLogs(String uuid, {int lines = 200}) async {
    final d = await _map('/applications/$uuid/logs', {'lines': lines});
    return '${d['logs'] ?? ''}';
  }
}

/// Normalises user input: adds https:// when missing, strips trailing slashes
/// and a pasted `/api/v1` suffix.
String normalizeUrl(String input) {
  var u = input.trim();
  if (!RegExp(r'^https?://').hasMatch(u)) u = 'https://$u';
  u = u.replaceAll(RegExp(r'/+$'), '').replaceAll(RegExp(r'/api(/v1)?$'), '');
  return u;
}
