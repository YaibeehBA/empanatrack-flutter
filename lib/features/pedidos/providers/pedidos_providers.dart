import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import '../models/pedido_models.dart';

// ══════════════════════════════════════════════════════════
//  HELPER — parsear errores Dio con mensajes amigables
// ══════════════════════════════════════════════════════════
String _parsearError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is String && detail.isNotEmpty) {
        // Traducir mensajes técnicos del backend a mensajes que
        // el repartidor/vendedor pueda entender
        return _mensajeAmigable(detail);
      }

      if (detail is List && detail.isNotEmpty) {
        final primer = detail.first;
        if (primer is Map && primer['msg'] is String) {
          return _mensajeAmigable(primer['msg'] as String);
        }
      }
    }

    switch (e.response?.statusCode) {
      case 400: return _mensajeAmigable(data?.toString() ?? '');
      case 403: return 'No tienes permiso para realizar esta acción.';
      case 404: return 'El pedido no fue encontrado.';
      case 409: return 'Este pedido ya fue tomado por otro repartidor.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Sin conexión con el servidor. Verifica tu red.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar al servidor.';
    }
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}

/// Convierte mensajes técnicos del backend en texto claro para el usuario.
String _mensajeAmigable(String detalle) {
  final d = detalle.toLowerCase();

  // Repartidor con pedido activo
  if (d.contains('ya tienes un pedido activo')) {
    return '⚠️ Tienes un pedido en curso.\n\n'
        'Debes entregar o cancelar tu pedido actual '
        'antes de poder aceptar uno nuevo.';
  }

  // Pedido ya tomado por otro
  if (d.contains('ya fue aceptado')) {
    return 'Este pedido ya fue tomado por otro repartidor.';
  }

  // Stock insuficiente
  if (d.contains('stock insuficiente') || d.contains('disponible')) {
    return 'No tienes suficiente stock para este pedido.';
  }

  // Empresa visitada
  if (d.contains('visitaste') || d.contains('visitada')) {
    return 'Ya visitaste esta empresa hoy. '
        'No puedes aceptar más reservas de ella.';
  }

  // Devolver el mensaje original si no hay traducción
  return detalle;
}

// ══════════════════════════════════════════════════════════
//  PROVIDER GENÉRICO — lista de pedidos disponibles
// ══════════════════════════════════════════════════════════
class PedidosDisponiblesNotifier
    extends StateNotifier<AsyncValue<List<PedidoBase>>> {

  PedidosDisponiblesNotifier({
    required this.endpoint,
    required this.tipoWs,
  }) : super(const AsyncValue.loading()) {
    _cargar();
    Future.delayed(const Duration(milliseconds: 500), _escucharWs);
  }

  final String endpoint;
  final String tipoWs;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get(endpoint);
      if (mounted) {
        state = AsyncValue.data(
          (r.data as List).map((p) => PedidoBase.fromJson(p)).toList(),
        );
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      if (msg['tipo'] == tipoWs     ||
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
final pedidosRepartidorProvider = StateNotifierProvider<
    PedidosDisponiblesNotifier, AsyncValue<List<PedidoBase>>>(
  (ref) => PedidosDisponiblesNotifier(
    endpoint: '/pedidos/repartidor/disponibles',
    tipoWs:   'nuevo_pedido',
  ),
);

// ── Vendedor: reservas disponibles ────────────────────────
final reservasVendedorProvider = StateNotifierProvider<
    PedidosDisponiblesNotifier, AsyncValue<List<PedidoBase>>>(
  (ref) => PedidosDisponiblesNotifier(
    endpoint: '/pedidos/vendedor/reservas',
    tipoWs:   'nueva_reserva',
  ),
);

// ══════════════════════════════════════════════════════════
//  PEDIDO ACTIVO GENÉRICO
// ══════════════════════════════════════════════════════════
class PedidoActivoNotifier
    extends StateNotifier<AsyncValue<PedidoBase?>> {

  PedidoActivoNotifier(this.endpoint)
      : super(const AsyncValue.loading()) {
    _cargar();
    Future.delayed(const Duration(milliseconds: 500), _escucharWs);
  }

  final String endpoint;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get(endpoint);
      if (mounted) {
        state = AsyncValue.data(
          r.data != null ? PedidoBase.fromJson(r.data) : null,
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
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

final pedidoActivoRepartidorProvider = StateNotifierProvider<
    PedidoActivoNotifier, AsyncValue<PedidoBase?>>(
  (ref) => PedidoActivoNotifier('/pedidos/repartidor/activo'),
);

// ══════════════════════════════════════════════════════════
//  ACCIÓN ACEPTAR / CAMBIAR ESTADO
// ══════════════════════════════════════════════════════════
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

class AccionPedidoNotifier extends StateNotifier<AccionPedidoState> {

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
      // ✅ CORREGIDO: usa _parsearError con Dio en lugar de regex
      state = AccionPedidoState(error: _parsearError(e));
    }
  }

  Future<void> actualizarEstado(String pedidoId, String nuevoEstado) async {
    state = const AccionPedidoState(cargando: true);
    try {
      await ApiClient.put(
        endpointEstado.replaceAll('{id}', pedidoId),
        data: {'estado': nuevoEstado},
      );
      state = const AccionPedidoState(exitoso: true);
    } catch (e) {
      state = AccionPedidoState(error: _parsearError(e));
    }
  }

  void resetear() => state = const AccionPedidoState();
}

// ── Repartidor — ACEPTAR pedido de la lista ───────────────
// Solo se usa para aceptar pedidos disponibles.
// Tiene su propio listener en la pantalla que muestra el
// diálogo amigable cuando hay error (ej: ya tienes activo).
final accionRepartidorProvider = StateNotifierProvider.autoDispose<
    AccionPedidoNotifier, AccionPedidoState>(
  (ref) => AccionPedidoNotifier(
    endpointAceptar: '/pedidos/{id}/aceptar-repartidor',
    endpointEstado:  '/pedidos/{id}/estado-repartidor',
  ),
);

// ── Repartidor — ESTADO del pedido activo ─────────────────
// Provider separado para "en camino" / "entregado".
// Así el listener de aceptar NO se dispara cuando el
// repartidor cambia el estado de su pedido activo,
// evitando que aparezcan dos ventanas de error.
final estadoRepartidorProvider = StateNotifierProvider.autoDispose<
    AccionPedidoNotifier, AccionPedidoState>(
  (ref) => AccionPedidoNotifier(
    endpointAceptar: '/pedidos/{id}/aceptar-repartidor',
    endpointEstado:  '/pedidos/{id}/estado-repartidor',
  ),
);

// ── Vendedor (reservas) ───────────────────────────────────
final accionReservaProvider = StateNotifierProvider.autoDispose<
    AccionPedidoNotifier, AccionPedidoState>(
  (ref) => AccionPedidoNotifier(
    endpointAceptar: '/pedidos/{id}/aceptar-reserva',
    endpointEstado:  '/pedidos/{id}/estado-vendedor',
  ),
);

// ══════════════════════════════════════════════════════════
//  TIEMPO ESTIMADO
// ══════════════════════════════════════════════════════════
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
    if (minutos! < 1)    return '< 1 min';
    return '${minutos!.round()} min';
  }
}

final tiempoEstimadoProvider = FutureProvider.family<TiempoEstimado,
    ({String pedidoId, double lat, double lng})>(
  (ref, args) async {
    final r = await ApiClient.get(
      '/pedidos/${args.pedidoId}/tiempo-estimado',
      params: {'lat_rep': args.lat, 'lng_rep': args.lng},
    );
    return TiempoEstimado.fromJson(r.data);
  },
);