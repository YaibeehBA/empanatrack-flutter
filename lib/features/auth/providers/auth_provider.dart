import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/usuario_sesion.dart';

// Estado posible del login
enum AuthEstado { inicial, cargando, autenticado, error }

class AuthState {
  final AuthEstado   estado;
  final UsuarioSesion? sesion;
  final String?      mensajeError;

  const AuthState({
    this.estado       = AuthEstado.inicial,
    this.sesion,
    this.mensajeError,
  });

  AuthState copyWith({
    AuthEstado?    estado,
    UsuarioSesion? sesion,
    String?        mensajeError,
  }) {
    return AuthState(
      estado:        estado       ?? this.estado,
      sesion:        sesion       ?? this.sesion,
      mensajeError:  mensajeError ?? this.mensajeError,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // Verificar si ya hay sesión guardada al abrir la app
  Future<void> verificarSesion() async {
    final hay = await TokenStorage.haySesion();
    if (hay) {
      final token  = await TokenStorage.leerToken();
      final rol    = await TokenStorage.leerRol();
      final nombre = await TokenStorage.leerNombre();
      state = state.copyWith(
        estado: AuthEstado.autenticado,
        sesion: UsuarioSesion(
          token:  token!,
          rol:    rol!,
          nombre: nombre!,
        ),
      );
    }
  }

  // Hacer login
  Future<void> login(String nombreUsuario, String contrasena) async {
    state = state.copyWith(estado: AuthEstado.cargando);
    try {
      final response = await ApiClient.post('/auth/login', data: {
        'nombre_usuario': nombreUsuario,
        'contrasena':     contrasena,
      });

      final data   = response.data;
      final sesion = UsuarioSesion(
        token:  data['access_token'],
        rol:    data['rol'],
        nombre: data['nombre'],
      );

      // Guardar en almacenamiento seguro
      await TokenStorage.guardar(
        token:  sesion.token,
        rol:    sesion.rol,
        nombre: sesion.nombre,
      );

      state = state.copyWith(
        estado: AuthEstado.autenticado,
        sesion: sesion,
      );
    } catch (e) {
      String mensaje = 'Error al iniciar sesión.';
      // Extraer el mensaje de error que manda FastAPI
      if (e.toString().contains('401')) {
        mensaje = 'Usuario o contraseña incorrectos.';
      } else if (e.toString().contains('Connection')) {
        mensaje = 'No se puede conectar al servidor.';
      }
      state = state.copyWith(
        estado:       AuthEstado.error,
        mensajeError: mensaje,
      );
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await TokenStorage.limpiar();
    state = const AuthState();
  }
}

// El provider que usan las pantallas
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);