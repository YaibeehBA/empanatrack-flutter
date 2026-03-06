import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class RegistroPublicoState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;
  final String  mensaje;

  const RegistroPublicoState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
    this.mensaje  = '',
  });

  RegistroPublicoState copyWith({
    bool?   cargando,
    String? error,
    bool?   exitoso,
    String? mensaje,
  }) =>
      RegistroPublicoState(
        cargando: cargando ?? this.cargando,
        error:    error,
        exitoso:  exitoso  ?? this.exitoso,
        mensaje:  mensaje  ?? this.mensaje,
      );
}

class RegistroPublicoNotifier
    extends StateNotifier<RegistroPublicoState> {
  RegistroPublicoNotifier() : super(const RegistroPublicoState());

  Future<void> registrar({
    required String cedula,
    required String nombre,
    required String nombreUsuario,
    required String contrasena,
    String?         correo,
    String?         telefono,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      final response = await ApiClient.post('/auth/registro', data: {
        'cedula':          cedula,
        'nombre':          nombre,
        'nombre_usuario':  nombreUsuario,
        'contrasena':      contrasena,
        'correo':  correo?.trim().isEmpty   == true ? null : correo?.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
      });

      state = state.copyWith(
        cargando: false,
        exitoso:  true,
        mensaje:  response.data['mensaje'] ?? 'Registro exitoso.',
      );
    } catch (e) {
      String msg = 'Error al registrarse. Intenta de nuevo.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  void resetear() => state = const RegistroPublicoState();
}

final registroPublicoProvider = StateNotifierProvider
    .autoDispose<RegistroPublicoNotifier, RegistroPublicoState>(
  (ref) => RegistroPublicoNotifier(),
);