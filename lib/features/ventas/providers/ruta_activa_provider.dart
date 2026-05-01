import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/ruta_activa_models.dart';

// ── Estado del día ────────────────────────────────────────
final estadoRutaHoyProvider = FutureProvider.autoDispose<EstadoRutaHoy>((
  ref,
) async {
  final r = await ApiClient.get('/ruta-activa/estado-hoy');
  return EstadoRutaHoy.fromJson(r.data);
});

// ── Stock del día ─────────────────────────────────────────
final stockHoyProvider = FutureProvider.autoDispose<List<ProductoStock>>((
  ref,
) async {
  final r = await ApiClient.get('/ruta-activa/stock-hoy');
  return (r.data as List).map((p) => ProductoStock.fromJson(p)).toList();
});

final stockRestanteProvider = FutureProvider<StockRestanteHoy>((ref) async {
  final r = await ApiClient.get('/ruta-activa/stock-restante');
  return StockRestanteHoy.fromJson(r.data as Map<String, dynamic>);
});

// ── Resumen final ─────────────────────────────────────────
final resumenRutaFinalProvider = FutureProvider.autoDispose
    .family<ResumenRutaFinal, String>((ref, sesionId) async {
      final r = await ApiClient.get('/ruta-activa/resumen/$sesionId');
      return ResumenRutaFinal.fromJson(r.data);
    });

// NOTA: reservasEmpresaProvider fue eliminado de este archivo.
// Usar ÚNICAMENTE el de pedidos_vendedor_provider.dart,
// que devuelve List<PedidoVendedor> correctamente tipado.

// ══════════════════════════════════════════════════════════
//  NOTIFIER — acciones de ruta
// ══════════════════════════════════════════════════════════
class RutaAccionState {
  final bool cargando;
  final String? error;
  const RutaAccionState({this.cargando = false, this.error});
}

class RutaAccionNotifier extends StateNotifier<RutaAccionState> {
  RutaAccionNotifier() : super(const RutaAccionState());

  Future<String?> iniciarRuta({
    required String asignacionId,
    required double lat,
    required double lng,
  }) async {
    if (!mounted) return null;
    state = const RutaAccionState(cargando: true);
    try {
      final r = await ApiClient.post(
        '/ruta-activa/iniciar',
        data: {'asignacion_id': asignacionId, 'lat': lat, 'lng': lng},
      );
      if (!mounted) return null;
      state = const RutaAccionState();
      return r.data['sesion_id'] as String;
    } catch (e) {
      if (!mounted) return null;
      state = RutaAccionState(error: _parseError(e));
      return null;
    }
  }

  Future<bool> registrarLlegada({
    required String sesionId,
    required String empresaId,
    required double lat,
    required double lng,
  }) async {
    try {
      await ApiClient.post(
        '/ruta-activa/registrar-llegada',
        data: {
          'sesion_id':  sesionId,
          'empresa_id': empresaId,
          'lat':        lat,
          'lng':        lng,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> marcarVisitada({
    required String sesionId,
    required String empresaId,
    required double lat,
    required double lng,
  }) async {
    if (!mounted) return null;
    state = const RutaAccionState(cargando: true);
    try {
      await ApiClient.post(
        '/ruta-activa/marcar-visitada',
        data: {
          'sesion_id':  sesionId,
          'empresa_id': empresaId,
          'lat':        lat,
          'lng':        lng,
        },
      );
      if (!mounted) return null;
      state = const RutaAccionState();
      return null;
    } catch (e) {
      final msg = _parseError(e);
      if (!mounted) return msg;
      state = RutaAccionState(error: msg);
      return msg;
    }
  }

  Future<bool> completarRuta(String sesionId) async {
    try {
      if (!mounted) return false;
      state = const RutaAccionState(cargando: true);
      await ApiClient.post(
        '/ruta-activa/completar',
        data: {'sesion_id': sesionId},
      );
      if (!mounted) return true;
      state = const RutaAccionState();
      return true;
    } catch (e) {
      if (!mounted) return false;
      final msg = _parseError(e);
      state = RutaAccionState(error: msg);
      return false;
    }
  }

  Future<bool> guardarStock(List<ProductoStock> items) async {
    if (!mounted) return false;
    state = const RutaAccionState(cargando: true);
    try {
      final conCantidad = items.where((i) => i.cantidad > 0).toList();
      if (conCantidad.isEmpty) {
        if (!mounted) return false;
        state = const RutaAccionState(error: 'Agrega al menos un producto');
        return false;
      }
      await ApiClient.post(
        '/ruta-activa/guardar-stock',
        data: {
          'items': conCantidad
              .map((i) => {'producto_id': i.productoId, 'cantidad': i.cantidad})
              .toList(),
        },
      );
      if (!mounted) return true;
      state = const RutaAccionState();
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = RutaAccionState(error: _parseError(e));
      return false;
    }
  }

  void limpiarError() {
    if (!mounted) return;
    state = const RutaAccionState();
  }

  String _parseError(Object e) {
    final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
    return match?.group(1) ?? 'Error inesperado';
  }
}

final rutaAccionProvider =
    StateNotifierProvider<RutaAccionNotifier, RutaAccionState>(
      (ref) => RutaAccionNotifier(),
    );