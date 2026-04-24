import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import '../models/pedido_models.dart';

// ══════════════════════════════════════════════════════════
//  PROVIDER GENÉRICO — lista de pedidos disponibles
//  Reutilizado por repartidor y vendedor (reservas)
// ══════════════════════════════════════════════════════════
class PedidosDisponiblesNotifier
    extends StateNotifier<AsyncValue<List<PedidoBase>>> {

  PedidosDisponiblesNotifier({
    required this.endpoint,
    required this.tipoWs,
  }) : super(const AsyncValue.loading()) {
    _cargar();
    Future.delayed(
        const Duration(milliseconds: 500), _escucharWs);
  }

  final String endpoint;
  final String tipoWs;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get(endpoint);
      if (mounted) {
        state = AsyncValue.data(
          (r.data as List)
              .map((p) => PedidoBase.fromJson(p))
              .toList(),
        );
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      if (msg['tipo'] == tipoWs ||
          msg['tipo'] == 'nuevo_pedido' ||
          msg['tipo'] == 'nueva_reserva') {
        _cargar();
      }
    });
  }

  Future<void> recargar() => _cargar();

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

// ── Repartidor: pedidos normales disponibles ──────────────
final pedidosRepartidorProvider =
    StateNotifierProvider<PedidosDisponiblesNotifier,
        AsyncValue<List<PedidoBase>>>(
  (ref) => PedidosDisponiblesNotifier(
    endpoint: '/pedidos/repartidor/disponibles',
    tipoWs:   'nuevo_pedido',
  ),
);

// ── Vendedor: reservas disponibles ────────────────────────
final reservasVendedorProvider =
    StateNotifierProvider<PedidosDisponiblesNotifier,
        AsyncValue<List<PedidoBase>>>(
  (ref) => PedidosDisponiblesNotifier(
    endpoint: '/pedidos/vendedor/reservas',
    tipoWs:   'nueva_reserva',
  ),
);

// ── Pedido activo genérico ─────────────────────────────────
class PedidoActivoNotifier
    extends StateNotifier<AsyncValue<PedidoBase?>> {

  PedidoActivoNotifier(this.endpoint)
      : super(const AsyncValue.loading()) {
    _cargar();
    Future.delayed(
        const Duration(milliseconds: 500), _escucharWs);
  }

  final String endpoint;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get(endpoint);
      if (mounted) {
        state = AsyncValue.data(
          r.data != null
              ? PedidoBase.fromJson(r.data) : null,
        );
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      if (msg['tipo'] == 'pedido_asignado') _cargar();
    });
  }

  Future<void> recargar() => _cargar();

  @override
  void dispose() { _wsSub?.cancel(); super.dispose(); }
}

final pedidoActivoRepartidorProvider =
    StateNotifierProvider<PedidoActivoNotifier,
        AsyncValue<PedidoBase?>>(
  (ref) => PedidoActivoNotifier('/pedidos/repartidor/activo'),
);

// ── Acción aceptar/estado — genérica ─────────────────────
class AccionPedidoState {
  final bool    cargando;
  final bool    exitoso;
  final String? error;
  const AccionPedidoState({
    this.cargando = false,
    this.exitoso  = false,
    this.error,
  });
}

class AccionPedidoNotifier
    extends StateNotifier<AccionPedidoState> {

  AccionPedidoNotifier({
    required this.endpointAceptar,
    required this.endpointEstado,
  }) : super(const AccionPedidoState());

  final String endpointAceptar;
  final String endpointEstado;

  Future<void> aceptar(String pedidoId) async {
    state = const AccionPedidoState(cargando: true);
    try {
      await ApiClient.post(
          endpointAceptar.replaceAll('{id}', pedidoId));
      state = const AccionPedidoState(exitoso: true);
    } catch (e) {
      state = AccionPedidoState(error: _parseError(e));
    }
  }

  Future<void> actualizarEstado(
      String pedidoId, String estado) async {
    state = const AccionPedidoState(cargando: true);
    try {
      await ApiClient.put(
        endpointEstado.replaceAll('{id}', pedidoId),
        data: {'estado': estado},
      );
      state = const AccionPedidoState(exitoso: true);
    } catch (e) {
      state = AccionPedidoState(error: _parseError(e));
    }
  }

  void resetear() => state = const AccionPedidoState();

  String _parseError(Object e) {
    final m = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
    return m?.group(1) ?? 'Error inesperado';
  }
}

// Repartidor
final accionRepartidorProvider =
    StateNotifierProvider.autoDispose<AccionPedidoNotifier,
        AccionPedidoState>(
  (ref) => AccionPedidoNotifier(
    endpointAceptar: '/pedidos/{id}/aceptar-repartidor',
    endpointEstado:  '/pedidos/{id}/estado-repartidor',
  ),
);

// Vendedor (reservas)
final accionReservaProvider =
    StateNotifierProvider.autoDispose<AccionPedidoNotifier,
        AccionPedidoState>(
  (ref) => AccionPedidoNotifier(
    endpointAceptar: '/pedidos/{id}/aceptar-reserva',
    endpointEstado:  '/pedidos/{id}/estado-vendedor',
  ),
);

// ── Tiempo estimado ───────────────────────────────────────
class TiempoEstimado {
  final double? minutos;
  final int?    distanciaMetros;
  const TiempoEstimado({this.minutos, this.distanciaMetros});

  factory TiempoEstimado.fromJson(Map<String, dynamic> j) =>
      TiempoEstimado(
        minutos:         j['minutos'] != null
            ? (j['minutos'] as num).toDouble() : null,
        distanciaMetros: j['distancia_metros'],
      );

  String get label {
    if (minutos == null) return '';
    if (minutos! < 1) return '< 1 min';
    return '${minutos!.round()} min';
  }
}

final tiempoEstimadoProvider =
    FutureProvider.family<TiempoEstimado,
        ({String pedidoId, double lat, double lng})>(
  (ref, args) async {
    final r = await ApiClient.get(
      '/pedidos/${args.pedidoId}/tiempo-estimado',
      params: {
        'lat_rep': args.lat,
        'lng_rep': args.lng,
      },
    );
    return TiempoEstimado.fromJson(r.data);
  },
);