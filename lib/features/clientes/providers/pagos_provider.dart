import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/venta_model.dart';

// Estado del formulario de pago
class PagoState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;

  const PagoState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
  });

  PagoState copyWith({bool? cargando, String? error, bool? exitoso}) {
    return PagoState(
      cargando: cargando ?? this.cargando,
      error:    error,
      exitoso:  exitoso  ?? this.exitoso,
    );
  }
}

class PagoNotifier extends StateNotifier<PagoState> {
  PagoNotifier() : super(const PagoState());

  Future<void> registrarPago({
    required String  clienteId,
    String?          ventaId,
    required double  monto,
    required String  tipo,
    String?          notas,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post('/pagos/', data: {
        'cliente_id': clienteId,
        'venta_id':   ventaId,
        'monto':      monto,
        'tipo':       tipo,
        'notas':      notas,
      });
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String mensaje = 'Error al registrar el pago.';
      if (e.toString().contains('400')) {
        // Extraer mensaje de FastAPI
        final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
        if (match != null) mensaje = match.group(1)!;
      }
      state = state.copyWith(cargando: false, error: mensaje);
    }
  }

  void resetear() => state = const PagoState();
}

final pagoProvider =
    StateNotifierProvider.autoDispose<PagoNotifier, PagoState>(
  (ref) => PagoNotifier(),
);

// Ventas pendientes de un cliente (para elegir a cuál abonar)
final ventasPendientesProvider =
    FutureProvider.family<List<VentaModel>, String>((ref, clienteId) async {
  final response = await ApiClient.get(
    '/ventas/',
    params: {'cliente_id': clienteId, 'estado': 'pendiente'},
  );
  final lista = response.data as List;
  return lista.map((v) => VentaModel.fromJson(v)).toList();
});