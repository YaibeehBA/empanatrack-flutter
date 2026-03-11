// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class ApiClient {
   static const _baseUrl = 'http://10.0.2.2:8000';
   static String get baseUrl => _baseUrl;
  // ⚠️ 10.0.2.2 es la IP especial del emulador Android
  // para referirse a localhost de tu PC.
  // Cuando tengas la app en celular real, cambia por
  // la IP local de tu PC: ej. http://192.168.1.x:8000
  
  //static const _baseUrl = 'https://3143-2800-bf0-806e-fff-c07d-6aa8-9577-159e.ngrok-free.app';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Inicializar interceptors — se llama una vez al arrancar la app
  static void inicializar() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // Antes de cada request: agrega el token si existe
        onRequest: (options, handler) async {
          final token = await TokenStorage.leerToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        // Si el servidor responde 401: sesión expirada
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await TokenStorage.limpiar();
            // En el siguiente paso manejaremos la redirección al login
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ── Métodos de acceso ──────────────────────────────────────

  static Future<Response> get(String path,
      {Map<String, dynamic>? params}) async {
    return await _dio.get(path, queryParameters: params);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  static Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  static Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
  // Métodos sin autenticación (para registro y endpoints públicos)
static Future<Response> getPublico(
  String path, {
  Map<String, dynamic>? params,
}) async {
  final dio = Dio(BaseOptions(
    baseUrl:         _baseUrl,
    connectTimeout:  const Duration(seconds: 10),
    receiveTimeout:  const Duration(seconds: 10),
  ));
  return await dio.get(path, queryParameters: params);
}

static Future<Response> postPublico(
  String path, {
  required Map<String, dynamic> data,
}) async {
  final dio = Dio(BaseOptions(
    baseUrl:        _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  return await dio.post(path, data: data);
}

static Future<Response> postFormData(
  String path, {
  required FormData formData,
}) async {
  return await _dio.post(path, data: formData);
}

}

