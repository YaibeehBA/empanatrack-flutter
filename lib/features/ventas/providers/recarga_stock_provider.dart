import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import '../models/ruta_activa_models.dart';

// ══════════════════════════════════════════════════════════
//  MODELO RecargaStock
// ══════════════════════════════════════════════════════════
class RecargaStock {
  final bool    tieneRecargaActiva;
  final String? recargaId;
  final String? estado;
  final double? latRecarga;
  final double? lngRecarga;
  final String? direccionRecarga;
  final String? notasAdmin;
  final int     recargasUsadas;
  final int     recargasMax;

  RecargaStock({
    required this.tieneRecargaActiva,
    this.recargaId,
    this.estado,
    this.latRecarga,
    this.lngRecarga,
    this.direccionRecarga,
    this.notasAdmin,
    required this.recargasUsadas,
    required this.recargasMax,
  });

  bool get puedesolicitarMas => recargasUsadas < recargasMax;
  bool get esPendiente       => estado == 'pendiente';
  bool get esAceptada        => estado == 'aceptada';
  bool get esRechazada       => estado == 'rechazada';

  factory RecargaStock.inicial() => RecargaStock(
    tieneRecargaActiva: false,
    recargasUsadas:     0,
    recargasMax:        5,
  );

  factory RecargaStock.fromJson(Map<String, dynamic> j) => RecargaStock(
    tieneRecargaActiva: j['tiene_recarga_activa'] ?? false,
    recargaId:          j['recarga_id'],
    estado:             j['estado'],
    latRecarga:         j['lat_recarga'] != null
        ? (j['lat_recarga'] as num).toDouble() : null,
    lngRecarga:         j['lng_recarga'] != null
        ? (j['lng_recarga'] as num).toDouble() : null,
    direccionRecarga:   j['direccion_recarga'],
    notasAdmin:         j['notas_admin'],
    recargasUsadas:     (j['recargas_usadas'] as num?)?.toInt() ?? 0,
    recargasMax:        (j['recargas_max']    as num?)?.toInt() ?? 5,
  );
}

// ══════════════════════════════════════════════════════════
//  ESTADO DE ACCIÓN
// ══════════════════════════════════════════════════════════
class RecargaAccionState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;

  const RecargaAccionState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
  });
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER PRINCIPAL
// ══════════════════════════════════════════════════════════
class RecargaStockNotifier extends StateNotifier<RecargaStock> {
  RecargaStockNotifier() : super(RecargaStock.inicial());

  StreamSubscription? _wsSub;
  String?             _sesionId;

  void iniciar(String sesionId) {
    _sesionId = sesionId;
    _cargar();
    _escucharWs();
  }

  Future<void> _cargar() async {
    if (_sesionId == null) return;
    try {
      final r = await ApiClient.get(
          '/ruta-activa/recarga-activa/$_sesionId');
      if (mounted) {
        state = RecargaStock.fromJson(r.data as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      final tipo = msg['tipo'] as String?;
      if (tipo == 'recarga_respondida') {
        if (mounted) {
          state = RecargaStock(
            tieneRecargaActiva: msg['estado'] == 'aceptada',
            recargaId:          msg['recarga_id'],
            estado:             msg['estado'],
            latRecarga:         msg['lat_recarga'] != null
                ? (msg['lat_recarga'] as num).toDouble() : null,
            lngRecarga:         msg['lng_recarga'] != null
                ? (msg['lng_recarga'] as num).toDouble() : null,
            direccionRecarga:   msg['direccion_recarga'],
            notasAdmin:         msg['notas_admin'],
            recargasUsadas:     state.recargasUsadas,
            recargasMax:        state.recargasMax,
          );
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  MÉTODO SOLICITAR RECARGA ACTUALIZADO
  // ══════════════════════════════════════════════════════════
  Future<RecargaAccionState> solicitarRecarga({
    List<ProductoStockRestante>? productos,
    String? notas,
  }) async {
    if (_sesionId == null) {
      return const RecargaAccionState(
          error: 'Sesión no activa');
    }
    try {
      final r = await ApiClient.post(
        '/ruta-activa/solicitar-recarga',
        data: {
          'sesion_id': _sesionId,
          'productos': [
            for (var p in (productos ?? []))
              {
                'producto_id': p.productoId,
                'nombre':      p.nombre,
                'cantidad':    p.cantidad ?? 0,
                'precio':      p.precio,
              }
          ],
          'notas': notas,
        },
      );
      if (mounted) {
        state = RecargaStock(
          tieneRecargaActiva: true,
          recargaId:          r.data['recarga_id'],
          estado:             'pendiente',
          recargasUsadas:     r.data['recargas_usadas'],
          recargasMax:        r.data['recargas_max'],
        );
      }
      return const RecargaAccionState(exitoso: true);
    } catch (e) {
      final msg = RegExp(r'"detail":"([^"]+)"')
          .firstMatch(e.toString())?.group(1)
          ?? 'Error al solicitar recarga';
      return RecargaAccionState(error: msg);
    }
  }

  Future<RecargaAccionState> completarRecarga() async {
    if (state.recargaId == null) {
      return const RecargaAccionState(error: 'Sin recarga activa');
    }
    try {
      await ApiClient.post(
        '/ruta-activa/completar-recarga',
        data: {'recarga_id': state.recargaId},
      );
      if (mounted) {
        state = RecargaStock(
          tieneRecargaActiva: false,
          recargasUsadas:     state.recargasUsadas,
          recargasMax:        state.recargasMax,
        );
      }
      return const RecargaAccionState(exitoso: true);
    } catch (e) {
      final msg = RegExp(r'"detail":"([^"]+)"')
          .firstMatch(e.toString())?.group(1)
          ?? 'Error al completar recarga';
      return RecargaAccionState(error: msg);
    }
  }

  void detener() {
    _wsSub?.cancel();
    _sesionId = null;
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

final recargaStockProvider =
    StateNotifierProvider<RecargaStockNotifier, RecargaStock>(
  (ref) => RecargaStockNotifier(),
);