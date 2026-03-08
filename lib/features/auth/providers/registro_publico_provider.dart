// lib/features/auth/providers/registro_publico_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Modelo empresa ─────────────────────────────────────────
class EmpresaOpcion {
  final String id;
  final String nombre;
  const EmpresaOpcion({required this.id, required this.nombre});

  factory EmpresaOpcion.fromJson(Map<String, dynamic> json) =>
      EmpresaOpcion(id: json['id'], nombre: json['nombre']);
}

// ── Provider de empresas para el buscador ─────────────────
final empresasPublicasProvider =
    FutureProvider.family<List<EmpresaOpcion>, String>(
        (ref, busqueda) async {
  final response = await ApiClient.getPublico(
    '/auth/empresas-publico',
    params: busqueda.isNotEmpty ? {'buscar': busqueda} : {},
  );
  final lista = response.data as List;
  return lista.map((e) => EmpresaOpcion.fromJson(e)).toList();
});

// ── Estado del registro ────────────────────────────────────
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
    String?         empresaId,
    String?         empresaNombre,
    String?         empresaDireccion,
    String?         empresaTelefono,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      final response = await ApiClient.postPublico(
        '/auth/registro',
        data: {
          'cedula':            cedula,
          'nombre':            nombre,
          'nombre_usuario':    nombreUsuario,
          'contrasena':        contrasena,
          'correo':
              correo?.trim().isEmpty == true
                  ? null
                  : correo?.trim(),
          'telefono':
              telefono?.trim().isEmpty == true
                  ? null
                  : telefono?.trim(),
          'empresa_id':        empresaId,
          'empresa_nombre':
              empresaNombre?.trim().isEmpty == true
                  ? null
                  : empresaNombre?.trim(),
          'empresa_direccion':
              empresaDireccion?.trim().isEmpty == true
                  ? null
                  : empresaDireccion?.trim(),
          'empresa_telefono':
              empresaTelefono?.trim().isEmpty == true
                  ? null
                  : empresaTelefono?.trim(),
        },
      );
      state = state.copyWith(
        cargando: false,
        exitoso:  true,
        mensaje:  response.data['mensaje'] ?? 'Registro exitoso.',
      );
    } catch (e) {
      String msg = 'Error al registrarse. Intenta de nuevo.';
      final match =
          RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
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