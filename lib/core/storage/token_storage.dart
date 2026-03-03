import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// flutter_secure_storage guarda el token en el Keystore de Android
// Mucho más seguro que SharedPreferences
class TokenStorage {
  static const _storage   = FlutterSecureStorage();
  static const _keyToken  = 'access_token';
  static const _keyRol    = 'rol';
  static const _keyNombre = 'nombre';

  // Guardar datos al hacer login
  static Future<void> guardar({
    required String token,
    required String rol,
    required String nombre,
  }) async {
    await _storage.write(key: _keyToken,  value: token);
    await _storage.write(key: _keyRol,    value: rol);
    await _storage.write(key: _keyNombre, value: nombre);
  }

  // Leer el token
  static Future<String?> leerToken()  async =>
      await _storage.read(key: _keyToken);

  // Leer el rol (vendedor, cliente, administrador)
  static Future<String?> leerRol()    async =>
      await _storage.read(key: _keyRol);

  // Leer el nombre del usuario logueado
  static Future<String?> leerNombre() async =>
      await _storage.read(key: _keyNombre);

  // Borrar todo al cerrar sesión
  static Future<void> limpiar() async =>
      await _storage.deleteAll();

  // Verificar si hay sesión activa
  static Future<bool> haySesion() async {
    final token = await leerToken();
    return token != null && token.isNotEmpty;
  }
}