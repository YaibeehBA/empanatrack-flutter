// lib/features/pedidos/providers/pedidos_vendedor_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import 'ventas_provider.dart' show RangoFechas;

// ══════════════════════════════════════════════════════════
//  MODELO — Pedido/Reserva del vendedor
// ══════════════════════════════════════════════════════════
class PedidoVendedor {
  final String id;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? vendedorId;
  final String? vendedorNombre;
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
    id: j['id'],
    clienteNombre: j['cliente_nombre'] ?? '',
    clienteTelefono: j['cliente_telefono'],
    vendedorId: j['vendedor_id'],
    vendedorNombre: j['vendedor_nombre'],
    empresaNombre: j['empresa_nombre'],
    estado: j['estado'],
    tipoPago: j['tipo_pago'],
    total: (j['total'] as num).toDouble(),
    direccionEntrega: j['direccion_entrega'],
    latitudEntrega: j['latitud_entrega'] != null
        ? (j['latitud_entrega'] as num).toDouble()
        : null,
    longitudEntrega: j['longitud_entrega'] != null
        ? (j['longitud_entrega'] as num).toDouble()
        : null,
    notas: j['notas'],
    aceptadoEn: j['aceptado_en'],
    creadoEn: j['creado_en'],
    items: (j['items'] as List).map((i) => i as Map<String, dynamic>).toList(),
  );

  bool get tieneCoordenadas =>
      latitudEntrega != null && longitudEntrega != null;

  String get tipoPagoLabel =>
      tipoPago == 'transferencia' ? '🏦 Transferencia' : '🚚 Contraentrega';

  String get estadoLabel {
    switch (estado) {
      case 'entregado':
        return '✅ Entregado';
      case 'cancelado':
        return '❌ Cancelado';
      case 'aceptado':
        return '📦 En curso';
      case 'pendiente':
        return '⏳ Pendiente';
      default:
        return estado;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — Reservas disponibles (pendientes)
// ══════════════════════════════════════════════════════════
class ReservasDisponiblesNotifier extends StateNotifier<AsyncValue<List<PedidoVendedor>>> {
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
      if (msg['tipo'] == 'nueva_reserva') {
        _cargar();
      }
      if (msg['tipo'] == 'reserva_aceptada_otro') {
        final id = msg['pedido_id'] as String?;
        if (id != null && mounted) {
          state.whenData((lista) {
            state = AsyncValue.data(lista.where((p) => p.id != id).toList());
          });
        }
      }
      if (msg['tipo'] == 'reserva_cancelada') {
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
//  NOTIFIER — Reserva activa (aceptada por este vendedor)
// ══════════════════════════════════════════════════════════
class ReservaActivaNotifier extends StateNotifier<AsyncValue<PedidoVendedor?>> {
  ReservaActivaNotifier() : super(const AsyncValue.loading()) {
    _cargar();
    _escucharWs();
  }

  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get('/pedidos/vendedor/reserva-activa');
      if (mounted) {
        state = AsyncValue.data(r.data != null ? PedidoVendedor.fromJson(r.data) : null);
      }
    } catch (e, st) {
      if (e.toString().contains('404')) {
        if (mounted) state = const AsyncValue.data(null);
      } else {
        if (mounted) state = AsyncValue.error(e, st);
      }
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      if (msg['tipo'] == 'reserva_aceptada' && msg['vendedor_id'] != null) {
        _cargar();
      }
      if (msg['tipo'] == 'reserva_entregada' || msg['tipo'] == 'reserva_cancelada_por_vendedor') {
        if (mounted) state = const AsyncValue.data(null);
      }
      if (msg['tipo'] == 'reserva_asignada') {
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
//  NOTIFIER — Aceptar / Actualizar reserva
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

  AceptarReservaState copyWith({bool? cargando, String? error, bool? exitoso}) =>
      AceptarReservaState(
        cargando: cargando ?? this.cargando,
        error: error,
        exitoso: exitoso ?? this.exitoso,
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
//  PROVIDERS — CON NOMBRES ACTUALIZADOS
// ══════════════════════════════════════════════════════════
final reservasDisponiblesProvider = StateNotifierProvider<ReservasDisponiblesNotifier, AsyncValue<List<PedidoVendedor>>>(
  (ref) => ReservasDisponiblesNotifier(),
);

final reservaActivaProvider = StateNotifierProvider<ReservaActivaNotifier, AsyncValue<PedidoVendedor?>>(
  (ref) => ReservaActivaNotifier(),
);

final aceptarReservaProvider = StateNotifierProvider.autoDispose<AceptarReservaNotifier, AceptarReservaState>(
  (ref) => AceptarReservaNotifier(),
);

// ══════════════════════════════════════════════════════════
//  PROVIDERS — CON NOMBRES ANTIGUOS (PARA COMPATIBILIDAD)
//  ¡NO ROMPER OTRAS PANTALLAS!
// ══════════════════════════════════════════════════════════

// Para bottom_nav.dart y otras pantallas que usan pedidosDisponiblesProvider
final pedidosDisponiblesProvider = reservasDisponiblesProvider;

// Para dashboard_screen, historial_screen, mapa_ruta_screen
final pedidosHistorialProvider = reservasHistorialProvider;

// Para compatibilidad con el nombre anterior
final pedidoActivoProvider = reservaActivaProvider;

// Historial de reservas (necesario para las otras pantallas)
final reservasHistorialProvider = FutureProvider.family<List<PedidoVendedor>, RangoFechas>(
  (ref, rango) async {
    final r = await ApiClient.get(
      '/pedidos/historial-vendedor',
      params: {'desde': rango.desde, 'hasta': rango.hasta},
    );
    return (r.data as List).map((p) => PedidoVendedor.fromJson(p)).toList();
  },
);