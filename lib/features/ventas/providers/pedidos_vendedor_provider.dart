import 'dart:async';
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
      // Nueva reserva llegó → recargar lista completa
      if (tipo == 'nueva_reserva') {
        _cargar();
      }
      // Otra reserva fue aceptada → quitarla de la lista local sin recargar
      if (tipo == 'reserva_aceptada_propia') {
        final id = msg['pedido_id'] as String?;
        if (id != null && mounted) {
          state.whenData((lista) {
            state = AsyncValue.data(lista.where((p) => p.id != id).toList());
          });
        }
      }
      // Reserva cancelada → recargar
      if (tipo == 'reserva_cancelada' || tipo == 'reserva_liberada') {
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
//  El backend ahora devuelve una LISTA (puede tener varias)
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
        // El backend devuelve una lista
        final data = r.data;
        if (data is List) {
          state = AsyncValue.data(
            data.map((p) => PedidoVendedor.fromJson(p)).toList(),
          );
        } else if (data != null) {
          // Compatibilidad: si por alguna razón devuelve un objeto solo
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
      // Se aceptó una reserva → recargar para que aparezca en activas
      if (tipo == 'reserva_aceptada_propia') {
        _cargar();
      }
      // Se entregó o liberó → recargar
      if (tipo == 'reserva_entregada' || tipo == 'reserva_liberada') {
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
//  NOTIFIER — Aceptar reserva
// ══════════════════════════════════════════════════════════
class AceptarReservaState {
  final bool cargando;
  final String? error;
  final bool exitoso;

  const AceptarReservaState({
    this.cargando = false,
    this.error,
    this.exitoso = false,
  });

  AceptarReservaState copyWith({
    bool? cargando,
    String? error,
    bool? exitoso,
  }) => AceptarReservaState(
    cargando: cargando ?? this.cargando,
    error:    error,
    exitoso:  exitoso ?? this.exitoso,
  );
}

class AceptarReservaNotifier extends StateNotifier<AceptarReservaState> {
  AceptarReservaNotifier() : super(const AceptarReservaState());

  Future<void> aceptar(String pedidoId) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post('/pedidos/$pedidoId/aceptar-reserva', data: {});
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(cargando: false, error: _parseError(e));
    }
  }

  Future<void> actualizarEstado(String pedidoId, String estado) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.put(
        '/pedidos/$pedidoId/estado-vendedor',
        data: {'estado': estado},
      );
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(cargando: false, error: _parseError(e));
    }
  }

  void resetear() => state = const AceptarReservaState();

  String _parseError(Object e) {
    final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
    return match?.group(1) ?? 'Error inesperado';
  }
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS PRINCIPALES
// ══════════════════════════════════════════════════════════

final reservasDisponiblesProvider = StateNotifierProvider<
    ReservasDisponiblesNotifier, AsyncValue<List<PedidoVendedor>>>(
  (ref) => ReservasDisponiblesNotifier(),
);

// CORREGIDO: ahora es una lista de reservas activas
final reservasActivasProvider = StateNotifierProvider<
    ReservasActivasNotifier, AsyncValue<List<PedidoVendedor>>>(
  (ref) => ReservasActivasNotifier(),
);

final aceptarReservaProvider = StateNotifierProvider.autoDispose<
    AceptarReservaNotifier, AceptarReservaState>(
  (ref) => AceptarReservaNotifier(),
);

// ══════════════════════════════════════════════════════════
//  ALIASES DE COMPATIBILIDAD
// ══════════════════════════════════════════════════════════

// Para bottom_nav.dart y otras pantallas
final pedidosDisponiblesProvider = reservasDisponiblesProvider;

// Para historial
final pedidosHistorialProvider = reservasHistorialProvider;

// DEPRECATED: el anterior era Optional<PedidoVendedor?>, ahora es lista.
// Las pantallas que usaban reservaActivaProvider deben migrar a reservasActivasProvider.
// Se mantiene como alias que devuelve el primero de la lista (o null).
final reservaActivaProvider = Provider<AsyncValue<PedidoVendedor?>>((ref) {
  final lista = ref.watch(reservasActivasProvider);
  return lista.whenData((l) => l.isEmpty ? null : l.first);
});

// Para compatibilidad con mapa_ruta_screen que usa pedidoActivoProvider
final pedidoActivoProvider = reservaActivaProvider;

// Historial
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
//  RESERVAS POR EMPRESA (para el panel del mapa)
//  UNA SOLA DEFINICIÓN — devuelve List<PedidoVendedor>
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
//  NOTIFIER WS — invalida stock y reservas en tiempo real
// ══════════════════════════════════════════════════════════
class ReservasMapaNotifier extends StateNotifier<void> {
  final Ref _ref;
  ReservasMapaNotifier(this._ref) : super(null) {
    _escucharWs();
  }

  StreamSubscription? _wsSub;

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      final tipo      = msg['tipo']       as String?;
      final empresaId = msg['empresa_id'] as String?;

      switch (tipo) {
        // Vendedor aceptó una reserva → stock baja, badge de empresa sube
        case 'reserva_aceptada_propia':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _ref.invalidate(reservasDisponiblesProvider);
          if (empresaId != null) {
            _ref.invalidate(reservasEmpresaProvider(empresaId));
          }
          break;

        // Vendedor liberó una reserva → stock sube, badge de empresa baja
        case 'reserva_liberada':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          if (empresaId != null) {
            _ref.invalidate(reservasEmpresaProvider(empresaId));
          }
          break;

        // Reserva entregada como venta → stock baja definitivamente
        case 'reserva_entregada':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          if (empresaId != null) {
            _ref.invalidate(reservasEmpresaProvider(empresaId));
          }
          break;

        // Nueva reserva de cliente → lista de disponibles debe actualizarse
        case 'nueva_reserva':
          _ref.invalidate(reservasDisponiblesProvider);
          if (empresaId != null) {
            // Si el panel de esa empresa está abierto, refrescar su badge
            _ref.invalidate(reservasEmpresaProvider(empresaId));
          }
          break;

        case 'reserva_cancelada':
          _ref.invalidate(stockRestanteProvider);
          _ref.invalidate(reservasActivasProvider);
          _ref.invalidate(reservasDisponiblesProvider);
          if (empresaId != null) {
            _ref.invalidate(reservasEmpresaProvider(empresaId));
          }
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