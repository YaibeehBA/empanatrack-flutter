import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/empresa_model.dart';
import '../../../shared/models/cliente_model.dart';

// Estado del formulario
class RegistroClienteState {
  final bool          cargando;
  final String?       error;
  final ClienteModel? clienteCreado;

  const RegistroClienteState({
    this.cargando      = false,
    this.error,
    this.clienteCreado,
  });

  RegistroClienteState copyWith({
    bool?          cargando,
    String?        error,
    ClienteModel?  clienteCreado,
  }) {
    return RegistroClienteState(
      cargando:      cargando      ?? this.cargando,
      error:         error,
      clienteCreado: clienteCreado ?? this.clienteCreado,
    );
  }
}

class RegistroClienteNotifier extends StateNotifier<RegistroClienteState> {
  RegistroClienteNotifier() : super(const RegistroClienteState());

  Future<void> registrar({
    required String cedula,
    required String nombre,
    String?         correo,
    String?         telefono,
    String?         empresaId,
    String?         nombreUsuario,
    String?         contrasena,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      final response = await ApiClient.post('/clientes/', data: {
        'cedula':         cedula,
        'nombre':         nombre,
        'correo':         correo?.isEmpty == true ? null : correo,
        'telefono':       telefono?.isEmpty == true ? null : telefono,
        'empresa_id':     empresaId,
        'nombre_usuario': nombreUsuario?.isEmpty == true ? null : nombreUsuario,
        'contrasena':     contrasena?.isEmpty == true ? null : contrasena,
      });

      final data = response.data;
      final cliente = ClienteModel(
        id:          data['id'],
        cedula:      data['cedula'],
        nombre:      data['nombre'],
        correo:      data['correo'],
        telefono:    data['telefono'],
        empresa:     data['empresa'],
        saldoActual: 0.0,
      );

      state = state.copyWith(cargando: false, clienteCreado: cliente);
    } catch (e) {
      String mensaje = 'Error al registrar el cliente.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) mensaje = match.group(1)!;
      state = state.copyWith(cargando: false, error: mensaje);
    }
  }

  void resetear() => state = const RegistroClienteState();
}

final registroClienteProvider = StateNotifierProvider
    .autoDispose<RegistroClienteNotifier, RegistroClienteState>(
  (ref) => RegistroClienteNotifier(),
);

// Provider de empresas disponibles
final empresasProvider = FutureProvider<List<EmpresaModel>>((ref) async {
  final response = await ApiClient.get('/clientes/empresas/lista');
  final lista    = response.data as List;
  return lista.map((e) => EmpresaModel.fromJson(e)).toList();
});

// Verificar cédula disponible (para admin/vendedor — con auth)
final cedulaDisponibleAdminProvider =
    FutureProvider.family<bool, String>((ref, cedula) async {
  if (cedula.length != 10) return true;
  try {
    final r = await ApiClient.get('/clientes/verificar-cedula/$cedula');
    return r.data['disponible'] as bool;
  } catch (_) {
    return true;
  }
});