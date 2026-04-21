import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import 'ventas_provider.dart' show RangoFechas;

// ══════════════════════════════════════════════════════════
//  MODELOS
// ══════════════════════════════════════════════════════════
class PedidoVendedor {
  final String id;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? vendedorId;
  final String? vendedorNombre;
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
        items: (j['items'] as List)
            .map((i) => i as Map<String, dynamic>)
            .toList(),
      );

  bool get tieneCoordenadas =>
      latitudEntrega != null && longitudEntrega != null;

  String get tipoPagoLabel =>
      tipoPago == 'transferencia' ? '🏦 Transferencia' : '🚚 Contraentrega';
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════════

// ── Provider estado WebSocket ─────────────────────────────
final wsConectadoProvider = StateProvider<bool>((ref) => false);

// ── Pedidos disponibles — se refresca vía WS ─────────────
final pedidosDisponiblesProvider = StateNotifierProvider<
    PedidosDisponiblesNotifier,
    AsyncValue<List<PedidoVendedor>>>(
  (ref) => PedidosDisponiblesNotifier(ref),
);

class PedidosDisponiblesNotifier
    extends StateNotifier<AsyncValue<List<PedidoVendedor>>> {
  PedidosDisponiblesNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _cargar();
    // Pequeño delay para que el WS esté conectado
    Future.delayed(const Duration(milliseconds: 500), _escucharWs);
  }

  final Ref _ref;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final lista = await _fetchPedidosDisponibles();
      if (mounted) state = AsyncValue.data(lista);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      print('📨 [PedidosDisp] WS mensaje: $msg');
      if (msg['tipo'] == 'nuevo_pedido') {
        print('🛒 Nuevo pedido recibido — recargando lista');
        _cargar();
      }
      if (msg['tipo'] == 'pedido_aceptado_otro') {
        final id = msg['pedido_id'] as String?;
        if (id != null && mounted) {
          state.whenData((lista) {
            state = AsyncValue.data(
                lista.where((p) => p.id != id).toList());
          });
        }
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

// ── Pedido activo ─────────────────────────────────────────
final pedidoActivoProvider = StateNotifierProvider<PedidoActivoNotifier,
    AsyncValue<PedidoVendedor?>>(
  (ref) => PedidoActivoNotifier(ref),
);

class PedidoActivoNotifier
    extends StateNotifier<AsyncValue<PedidoVendedor?>> {
  PedidoActivoNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _cargar();
    // Pequeño delay para que el WS esté conectado
    Future.delayed(const Duration(milliseconds: 500), _escucharWs);
  }

  final Ref _ref;
  StreamSubscription? _wsSub;

  Future<void> _cargar() async {
    try {
      final pedido = await _fetchPedidoActivo();
      if (mounted) state = AsyncValue.data(pedido);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      print('📨 [PedidoActivo] WS mensaje: $msg');
      if (msg['tipo'] == 'pedido_asignado') {
        print('📦 Pedido asignado — recargando activo');
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

// ── Historial de pedidos entregados por rango ─────────────
final pedidosHistorialProvider =
    FutureProvider.family<List<PedidoVendedor>, RangoFechas>(
  (ref, rango) async {
    final r = await ApiClient.get(
      '/pedidos/historial-vendedor',
      params: {
        'desde': rango.desde,
        'hasta': rango.hasta,
      },
    );
    return (r.data as List)
        .map((p) => PedidoVendedor.fromJson(p))
        .toList();
  },
);

// ══════════════════════════════════════════════════════════
//  HELPERS FETCH
// ══════════════════════════════════════════════════════════
Future<List<PedidoVendedor>> _fetchPedidosDisponibles() async {
  final r = await ApiClient.get('/pedidos/disponibles');
  return (r.data as List)
      .map((p) => PedidoVendedor.fromJson(p))
      .toList();
}

Future<PedidoVendedor?> _fetchPedidoActivo() async {
  final r = await ApiClient.get('/pedidos/vendedor/activo');
  if (r.data == null) return null;
  return PedidoVendedor.fromJson(r.data);
}

// ══════════════════════════════════════════════════════════
//  ACEPTAR / ACTUALIZAR PEDIDO
// ══════════════════════════════════════════════════════════
class AceptarPedidoState {
  final bool cargando;
  final String? error;
  final bool exitoso;

  const AceptarPedidoState({
    this.cargando = false,
    this.error,
    this.exitoso = false,
  });

  AceptarPedidoState copyWith({
    bool? cargando,
    String? error,
    bool? exitoso,
  }) =>
      AceptarPedidoState(
        cargando: cargando ?? this.cargando,
        error: error,
        exitoso: exitoso ?? this.exitoso,
      );
}

class AceptarPedidoNotifier extends StateNotifier<AceptarPedidoState> {
  AceptarPedidoNotifier() : super(const AceptarPedidoState());

  Future<void> aceptar(String pedidoId) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post('/pedidos/$pedidoId/aceptar', data: {});
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String msg = 'Error al aceptar el pedido.';
      final match =
          RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  Future<void> actualizarEstado(String pedidoId, String estado) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.put(
        '/pedidos/$pedidoId/estado',
        data: {'estado': estado},
      );
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String msg = 'Error al actualizar el estado.';
      final match =
          RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  void resetear() => state = const AceptarPedidoState();
}

final aceptarPedidoProvider = StateNotifierProvider.autoDispose<
    AceptarPedidoNotifier,
    AceptarPedidoState>(
  (ref) => AceptarPedidoNotifier(),
);