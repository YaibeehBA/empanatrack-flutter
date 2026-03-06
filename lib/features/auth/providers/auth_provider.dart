import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/usuario_sesion.dart';

import '../../ventas/providers/reporte_provider.dart';
import '../../ventas/providers/ventas_provider.dart';
import '../../ventas/providers/productos_provider.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../../features/clientes/providers/registro_cliente_provider.dart';  


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

// MODIFICADO: AuthNotifier ahora recibe Ref
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  
  AuthNotifier(this._ref) : super(const AuthState());

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

  // MODIFICADO: Hacer login con limpieza de cache
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

      // NUEVO: Limpiar TODOS los providers cacheados del usuario anterior
      _limpiarCache();

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

  // MODIFICADO: Cerrar sesión con limpieza de cache
  Future<void> logout() async {
    await TokenStorage.limpiar();
    _limpiarCache();  // NUEVO: Limpiar cache al cerrar sesión
    state = const AuthState();
  }

  // NUEVO: Método privado para limpiar el cache de todos los providers
 void _limpiarCache() {
  // Providers simples
  _ref.invalidate(ventasHoyProvider);
  _ref.invalidate(clientesProvider);
  _ref.invalidate(productosProvider);
  _ref.invalidate(empresasProvider);

  // Providers family — invalidar todos los periodos
  _ref.invalidate(resumenDiaProvider('hoy'));
  _ref.invalidate(resumenDiaProvider('ayer'));
  _ref.invalidate(resumenDiaProvider('semana'));
  _ref.invalidate(resumenDiaProvider('mes'));
  _ref.invalidate(historialVentasProvider('hoy'));
  _ref.invalidate(historialVentasProvider('ayer'));
  _ref.invalidate(historialVentasProvider('semana'));
  _ref.invalidate(historialVentasProvider('mes'));

  // Resetear el periodo al default
  _ref.read(periodoSeleccionadoProvider.notifier).state = 'hoy';
}
}

// MODIFICADO: El provider ahora pasa ref al AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);