import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import 'ruta_activa_provider.dart';
import 'ventas_provider.dart' show RangoFechas;

// ══════════════════════════════════════════════════════════
//  MODELO
// ══════════════════════════════════════════════════════════
class PedidoVendedor {
  final String id;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? vendedorId;
  final String? vendedorNombre;
  final String? empresaId;
  final String? empresaNombre;
  final String estado;
  final String tipoPago;
  final double total;
  final String? direccionEntrega;
  final double? latitudEntrega;
  final double? longitudEntrega;
  final String? notas;
  final String? aceptadoEn;
  final String creadoEn;
  final List<Map<String, dynamic>> items;

  const PedidoVendedor({
    required this.id,
    required this.clienteNombre,
    this.clienteTelefono,
    this.vendedorId,
    this.vendedorNombre,
    this.empresaId,
    this.empresaNombre,
    required this.estado,
    required this.tipoPago,
    required this.total,
    this.direccionEntrega,
    this.latitudEntrega,
    this.longitudEntrega,
    this.notas,
    this.aceptadoEn,
    required this.creadoEn,
    required this.items,
  });

  factory PedidoVendedor.fromJson(Map<String, dynamic> j) => PedidoVendedor(
        id:               j['id'],
        clienteNombre:    j['cliente_nombre'] ?? '',
        clienteTelefono:  j['cliente_telefono'],
        vendedorId:       j['vendedor_id'],
        vendedorNombre:   j['vendedor_nombre'],
        empresaId:        j['empresa_id'],
        empresaNombre:    j['empresa_nombre'],
        estado:           j['estado'],
        tipoPago:         j['tipo_pago'],
        total:            (j['total'] as num).toDouble(),
        direccionEntrega: j['direccion_entrega'],
        latitudEntrega:   j['latitud_entrega'] != null
            ? (j['latitud_entrega'] as num).toDouble()
            : null,
        longitudEntrega:  j['longitud_entrega'] != null
            ? (j['longitud_entrega'] as num).toDouble()
            : null,
        notas:            j['notas'],
        aceptadoEn:       j['aceptado_en'],
        creadoEn:         j['creado_en'],
        items:            (j['items'] as List)
            .map((i) => i as Map<String, dynamic>)
            .toList(),
      );

  bool get tieneCoordenadas =>
      latitudEntrega != null && longitudEntrega != null;

  String get tipoPagoLabel =>
      tipoPago == 'transferencia' ? '🏦 Transferencia' : '🚚 Contraentrega';

  String get estadoLabel {
    switch (estado) {
      case 'entregado': return '✅ Entregado';
      case 'cancelado': return '❌ Cancelado';
      case 'aceptado':  return '📦 En curso';
      case 'pendiente': return '⏳ Pendiente';
      default:          return estado;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  HELPER GLOBAL — parsear errores Dio
// ══════════════════════════════════════════════════════════

/// Extrae el mensaje legible desde excepciones de Dio / FastAPI.
/// FastAPI devuelve: {"detail": "texto"} o {"detail": [{"msg": "..."}]}
String parsearErrorDio(Object e) {
  if (e is DioException) {
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];

      // Caso más común: {"detail": "Stock insuficiente: ..."}
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      // Validación pydantic: {"detail": [{"msg": "field required", ...}]}
      if (detail is List && detail.isNotEmpty) {
        final primer = detail.first;
        if (primer is Map && primer['msg'] is String) {
          return primer['msg'] as String;
        }
        return detail.map((d) => d.toString()).join('\n');
      }
    }

    // Mensajes por código HTTP cuando no hay body útil
    switch (e.response?.statusCode) {
      case 400: return data?.toString() ?? 'Solicitud inválida.';
      case 403: return 'No tienes permiso para esta acción.';
      case 404: return 'Reserva no encontrada.';
      case 409: return 'Esta reserva ya fue aceptada por otro vendedor.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Sin conexión con el servidor. Verifica tu red.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar al servidor.';
    }
  }
  return 'Error inesperado. Intenta de nuevo.';
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — Reservas disponibles (pendientes)
// ══════════════════════════════════════════════════════════
class ReservasDisponiblesNotifier
    extends StateNotifier<AsyncValue<List<PedidoVendedor>>> {
  ReservasDisponiblesNotifier() : super(const AsyncValue.loading()) {
    _cargar();
    _escucharWs();
  }

  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get('/pedidos/vendedor/reservas');
      if (mounted) {
        state = AsyncValue.data(
          (r.data as List).map((p) => PedidoVendedor.fromJson(p)).toList(),
        );
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      final tipo = msg['tipo'] as String?;
      
      if (tipo == 'nueva_reserva') {
        _cargar();
      }
      
      if (tipo == 'reserva_aceptada_propia') {
        final id = msg['pedido_id'] as String?;
        if (id != null && mounted) {
          state.whenData((lista) {
            state = AsyncValue.data(lista.where((p) => p.id != id).toList());
          });
        }
      }
      
      // ✅ NUEVO: Manejar cancelación en tiempo real
      if (tipo == 'reserva_cancelada') {
        final id = msg['pedido_id'] as String?;
        if (id != null && mounted) {
          state.whenData((lista) {
            // Remover la reserva cancelada de la lista disponible
            state = AsyncValue.data(lista.where((p) => p.id != id).toList());
          });
        }
      }
      
      if (tipo == 'reserva_liberada') {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> recargar() => _cargar();
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — Reservas activas (aceptadas por este vendedor)
// ══════════════════════════════════════════════════════════
class ReservasActivasNotifier
    extends StateNotifier<AsyncValue<List<PedidoVendedor>>> {
  ReservasActivasNotifier() : super(const AsyncValue.loading()) {
    _cargar();
    _escucharWs();
  }

  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get('/pedidos/vendedor/reserva-activa');
      if (mounted) {
        final data = r.data;
        if (data is List) {
          state = AsyncValue.data(
            data.map((p) => PedidoVendedor.fromJson(p)).toList(),
          );
        } else if (data != null) {
          state = AsyncValue.data([PedidoVendedor.fromJson(data)]);
        } else {
          state = const AsyncValue.data([]);
        }
      }
    } catch (e, st) {
      if (e.toString().contains('404')) {
        if (mounted) state = const AsyncValue.data([]);
      } else {
        if (mounted) state = AsyncValue.error(e, st);
      }
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      final tipo = msg['tipo'] as String?;
      if (tipo == 'reserva_aceptada_propia' ||
          tipo == 'reserva_entregada'        ||
          tipo == 'reserva_liberada') {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> recargar() => _cargar();
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — Aceptar / cancelar / entregar reserva
// ══════════════════════════════════════════════════════════
class AceptarReservaState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;

  const AceptarReservaState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
  });

  AceptarReservaState copyWith({
    bool?   cargando,
    String? error,
    bool?   exitoso,
  }) => AceptarReservaState(
    cargando: cargando ?? this.cargando,
    error:    error,
    exitoso:  exitoso ?? this.exitoso,
  );
}

class AceptarReservaNotifier extends StateNotifier<AceptarReservaState> {
  AceptarReservaNotifier() : super(const AceptarReservaState());

  /// Aceptar una reserva pendiente (valida stock en el backend).
  Future<void> aceptar(String pedidoId) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post('/pedidos/$pedidoId/aceptar-reserva', data: {});
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(cargando: false, error: parsearErrorDio(e));
    }
  }

  /// Actualizar estado de una reserva aceptada.
  /// Si el nuevo estado es 'cancelado' se llama a /liberar-reserva
  /// para que el backend también devuelva el stock.
  Future<void> actualizarEstado(String pedidoId, String nuevoEstado) async {
    state = state.copyWith(cargando: true);
    try {
      if (nuevoEstado == 'cancelado') {
        // ✅ liberar-reserva cancela Y libera stock
        await ApiClient.post('/pedidos/$pedidoId/liberar-reserva');
      } else {
        await ApiClient.put(
          '/pedidos/$pedidoId/estado-vendedor',
          data: {'estado': nuevoEstado},
        );
      }
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(cargando: false, error: parsearErrorDio(e));
    }
  }

  void resetear() => state = const AceptarReservaState();
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — Cancelar reserva disponible (sin aceptar) ✅ NUEVO
// ══════════════════════════════════════════════════════════
class CancelarReservaState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;

  const CancelarReservaState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
  });

  CancelarReservaState copyWith({
    bool?   cargando,
    String? error,
    bool?   exitoso,
  }) => CancelarReservaState(
    cargando: cargando ?? this.cargando,
    error:    error,
    exitoso:  exitoso ?? this.exitoso,
  );
}

class CancelarReservaNotifier extends StateNotifier<CancelarReservaState> {
  CancelarReservaNotifier() : super(const CancelarReservaState());

  /// Cancela una reserva disponible (pendiente, sin aceptarla).
  /// Solo descarta la reserva de la lista del vendedor.
  Future<void> cancelar(String pedidoId) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post(
        '/pedidos/$pedidoId/cancelar-reserva-disponible',
        data: {},
      );
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        error: parsearErrorDio(e),
      );
    }
  }

  void resetear() => state = const CancelarReservaState();
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════════

final reservasDisponiblesProvider = StateNotifierProvider<
    ReservasDisponiblesNotifier, AsyncValue<List<PedidoVendedor>>>(
  (ref) => ReservasDisponiblesNotifier(),
);

final reservasActivasProvider = StateNotifierProvider<
    ReservasActivasNotifier, AsyncValue<List<PedidoVendedor>>>(
  (ref) => ReservasActivasNotifier(),
);

final aceptarReservaProvider = StateNotifierProvider.autoDispose<
    AceptarReservaNotifier, AceptarReservaState>(
  (ref) => AceptarReservaNotifier(),
);

// ✅ NUEVO: Provider para cancelar reserva disponible
final cancelarReservaDisponibleProvider = StateNotifierProvider.autoDispose<
    CancelarReservaNotifier, CancelarReservaState>(
  (ref) => CancelarReservaNotifier(),
);

// ── Aliases de compatibilidad ─────────────────────────────
final pedidosDisponiblesProvider = reservasDisponiblesProvider;
final pedidosHistorialProvider   = reservasHistorialProvider;

/// Alias de compatibilidad: devuelve la primera reserva activa (o null).
final reservaActivaProvider = Provider<AsyncValue<PedidoVendedor?>>((ref) {
  final lista = ref.watch(reservasActivasProvider);
  return lista.whenData((l) => l.isEmpty ? null : l.first);
});

final pedidoActivoProvider = reservaActivaProvider;

// ── Historial ─────────────────────────────────────────────
final reservasHistorialProvider =
    FutureProvider.family<List<PedidoVendedor>, RangoFechas>(
  (ref, rango) async {
    final r = await ApiClient.get(
      '/pedidos/historial-vendedor',
      params: {'desde': rango.desde, 'hasta': rango.hasta},
    );
    return (r.data as List).map((p) => PedidoVendedor.fromJson(p)).toList();
  },
);

// ══════════════════════════════════════════════════════════
//  RESERVAS POR EMPRESA — única definición en todo el proyecto
// ══════════════════════════════════════════════════════════
final reservasEmpresaProvider =
    FutureProvider.autoDispose.family<List<PedidoVendedor>, String>(
  (ref, empresaId) async {
    final r = await ApiClient.get('/pedidos/reservas-empresa/$empresaId');
    return (r.data as List)
        .map((p) => PedidoVendedor.fromJson(p as Map<String, dynamic>))
        .toList();
  },
);

// ══════════════════════════════════════════════════════════
//  NOTIFIER WS — escucha mensajes y actualiza providers
// ══════════════════════════════════════════════════════════
class ReservasMapaNotifier extends StateNotifier<void> {
  final Ref _ref;
  ReservasMapaNotifier(this._ref) : super(null) {
    _escucharWs();
  }

  StreamSubscription? _wsSub;

  // ── Helper: invalida reservasEmpresaProvider para un empresaId
  // concreto, o toda la family si no se conoce el ID.
  // Esto cubre el caso en que el backend omite empresa_id en el
  // evento (p.ej. reserva_entregada disparado por el vendedor mismo).
  void _invalidarEmpresa(String? empresaId) {
    if (empresaId != null) {
      _ref.invalidate(reservasEmpresaProvider(empresaId));
    } else {
      // ✅ FIX: fallback — invalida TODA la family para que cualquier
      // instancia activa (p.ej. la que tiene abierta EntregarReservaScreen)
      // recargue aunque el mensaje WS no traiga empresa_id.
      _ref.invalidate(reservasEmpresaProvider);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      final tipo      = msg['tipo']       as String?;
      final empresaId = msg['empresa_id'] as String?;

      switch (tipo) {

        case 'reserva_aceptada_propia':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _ref.invalidate(reservasDisponiblesProvider);
          _invalidarEmpresa(empresaId); // ✅ usa helper con fallback
          break;

        case 'reserva_liberada':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _ref.invalidate(reservasDisponiblesProvider);
          _invalidarEmpresa(empresaId); // ✅
          break;

        case 'reserva_entregada':
          // Este evento es el más crítico para EntregarReservaScreen:
          // la reserva debe desaparecer de la lista en tiempo real.
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _invalidarEmpresa(empresaId); // ✅ si empresa_id es null, invalida toda la family
          break;

        case 'nueva_reserva':
          _ref.invalidate(reservasDisponiblesProvider);
          _invalidarEmpresa(empresaId); // ✅
          break;

        case 'reserva_cancelada':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _ref.invalidate(reservasDisponiblesProvider);
          _invalidarEmpresa(empresaId); // ✅
          break;
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

final reservasMapaProvider =
    StateNotifierProvider<ReservasMapaNotifier, void>(
  (ref) => ReservasMapaNotifier(ref),
);