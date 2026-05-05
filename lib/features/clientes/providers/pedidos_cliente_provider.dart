import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../screens/cliente_shell.dart';

// ══════════════════════════════════════════════════════════
//  MODELOS 
// ══════════════════════════════════════════════════════════
class ItemCarrito {
  final ProductoDisponible producto;
  final int                cantidad;
  const ItemCarrito({required this.producto, required this.cantidad});

  double get subtotal => producto.precio * cantidad;

  ItemCarrito copyWith({int? cantidad}) => ItemCarrito(
    producto: producto,
    cantidad: cantidad ?? this.cantidad,
  );
}

class ConfiguracionPago {
  final String whatsappNumero;
  final String cuentaBanco;
  final String cuentaTitular;
  final String costoEnvio;

  const ConfiguracionPago({
    required this.whatsappNumero,
    required this.cuentaBanco,
    required this.cuentaTitular,
    required this.costoEnvio,
  });

  factory ConfiguracionPago.fromJson(Map<String, dynamic> j) =>
      ConfiguracionPago(
        whatsappNumero: j['whatsapp_numero'] ?? '',
        cuentaBanco:    j['cuenta_banco']    ?? '',
        cuentaTitular:  j['cuenta_titular']  ?? '',
        costoEnvio:     j['costo_envio']     ?? '',
      );
}

class PedidoCliente {
  final String  id;
  final String  tipo;
  final String  estado;
  final String  tipoPago;
  final double  total;
  final double  costoEnvio;
  final String? vendedorNombre;
  final String? empresaNombre;
  final String? empresaId;
  final String? direccionEntrega;
  final String? aceptadoEn;
  final String  creadoEn;
  final double? latitudEntrega;
  final double? longitudEntrega;
  final List<Map<String, dynamic>> items;

  const PedidoCliente({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.tipoPago,
    required this.total,
    required this.costoEnvio,
    this.vendedorNombre,
    this.empresaNombre,
    this.empresaId,
    this.direccionEntrega,
    this.aceptadoEn,
    required this.creadoEn,
    required this.items,
    this.latitudEntrega,
    this.longitudEntrega,
  });

  bool get esReserva => tipo == 'reserva';
  String get tipoLabel => esReserva ? '📦 Reserva' : '🚚 Entrega';

  factory PedidoCliente.fromJson(Map<String, dynamic> j) =>
      PedidoCliente(
        id:               j['id'],
        tipo:             j['tipo']      ?? 'normal',
        estado:           j['estado'],
        tipoPago:         j['tipo_pago'],
        total:            (j['total']    as num).toDouble(),
        costoEnvio:       (j['costo_envio'] as num?)?.toDouble() ?? 0.0,
        vendedorNombre:   j['vendedor_nombre'],
        empresaNombre:    j['empresa_nombre'],
        empresaId:        j['empresa_id'],
        direccionEntrega: j['direccion_entrega'],
        latitudEntrega:   j['latitud_entrega'] != null
            ? (j['latitud_entrega']  as num).toDouble() : null,
        longitudEntrega:  j['longitud_entrega'] != null
            ? (j['longitud_entrega'] as num).toDouble() : null,
        aceptadoEn:       j['aceptado_en'],
        creadoEn:         j['creado_en'],
        items: (j['items'] as List)
            .map((i) => i as Map<String, dynamic>)
            .toList(),
      );

  String get estadoLabel {
    switch (estado) {
      case 'pendiente': return '⏳ Pendiente';
      case 'aceptado':  return '✅ Aceptado';
      case 'en_camino': return '🚚 En camino';
      case 'entregado': return '🎉 Entregado';
      case 'cancelado': return '❌ Cancelado';
      default:          return estado;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  CARRITO (sin cambios)
// ══════════════════════════════════════════════════════════
class CarritoState {
  final List<ItemCarrito> items;
  const CarritoState({this.items = const []});

  double get total      => items.fold(0, (s, i) => s + i.subtotal);
  int    get cantidadTotal => items.fold(0, (s, i) => s + i.cantidad);

  int cantidadDeProducto(String productoId) =>
      items.firstWhere(
        (i) => i.producto.id == productoId,
        orElse: () => ItemCarrito(
          producto: ProductoDisponible(
              id: '', nombre: '', precio: 0, estaActivo: false),
          cantidad: 0,
        ),
      ).cantidad;
}

class CarritoNotifier extends StateNotifier<CarritoState> {
  CarritoNotifier() : super(const CarritoState());

  void agregar(ProductoDisponible producto) {
    final items = [...state.items];
    final idx   = items.indexWhere(
        (i) => i.producto.id == producto.id);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(
          cantidad: items[idx].cantidad + 1);
    } else {
      items.add(ItemCarrito(producto: producto, cantidad: 1));
    }
    state = CarritoState(items: items);
  }

  void quitar(String productoId) {
    final items = [...state.items];
    final idx   = items.indexWhere(
        (i) => i.producto.id == productoId);
    if (idx < 0) return;
    if (items[idx].cantidad > 1) {
      items[idx] = items[idx].copyWith(
          cantidad: items[idx].cantidad - 1);
    } else {
      items.removeAt(idx);
    }
    state = CarritoState(items: items);
  }

  void eliminar(String productoId) {
    state = CarritoState(
      items: state.items
          .where((i) => i.producto.id != productoId)
          .toList(),
    );
  }

  void limpiar() => state = const CarritoState();
}

final carritoProvider =
    StateNotifierProvider<CarritoNotifier, CarritoState>(
  (ref) => CarritoNotifier(),
);

// ══════════════════════════════════════════════════════════
//  CONFIGURACIÓN DE PAGO (sin cambios)
// ══════════════════════════════════════════════════════════
final configuracionPagoProvider =
    FutureProvider<ConfiguracionPago>((ref) async {
  final r = await ApiClient.get('/pedidos/configuracion');
  return ConfiguracionPago.fromJson(r.data);
});

// ══════════════════════════════════════════════════════════
//  MIS PEDIDOS — PAGINADO
//  Reemplaza el anterior FutureProvider simple
// ══════════════════════════════════════════════════════════
class MisPedidosNotifier
    extends StateNotifier<AsyncValue<List<PedidoCliente>>> {

  MisPedidosNotifier() : super(const AsyncValue.loading()) {
    _cargarPagina(1);
  }

  int  _paginaActual = 1;
  bool _tieneMas     = false;
  bool _cargandoMas  = false;
  int  _total        = 0;

  bool get tieneMas    => _tieneMas;
  bool get cargandoMas => _cargandoMas;
  int  get total       => _total;

  Future<void> _cargarPagina(int pagina) async {
    try {
      final r = await ApiClient.get(
        '/pedidos/mis-pedidos',
        params: {'pagina': pagina, 'por_pagina': 10},
      );

      final data    = r.data as Map<String, dynamic>;
      final nuevos  = (data['datos'] as List)
          .map((p) => PedidoCliente.fromJson(p))
          .toList();

      _paginaActual = data['pagina']    as int;
      _total        = data['total']     as int;
      _tieneMas     = data['tiene_mas'] as bool;

      if (pagina == 1) {
        if (mounted) state = AsyncValue.data(nuevos);
      } else {
        state.whenData((existentes) {
          if (mounted) {
            state = AsyncValue.data([...existentes, ...nuevos]);
          }
        });
      }
    } catch (e, st) {
      if (pagina == 1 && mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> cargarMas() async {
    if (!_tieneMas || _cargandoMas) return;
    _cargandoMas = true;
    await _cargarPagina(_paginaActual + 1);
    _cargandoMas = false;
  }

  Future<void> recargar() async {
    if (mounted) state = const AsyncValue.loading();
    _paginaActual = 1;
    _tieneMas     = false;
    _total        = 0;
    await _cargarPagina(1);
  }
}

final misPedidosProvider =
    StateNotifierProvider.autoDispose<MisPedidosNotifier,
        AsyncValue<List<PedidoCliente>>>(
  (ref) => MisPedidosNotifier(),
);

// ══════════════════════════════════════════════════════════
//  CREAR PEDIDO (sin cambios)
// ══════════════════════════════════════════════════════════
class CrearPedidoState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;
  final String? pedidoId;

  const CrearPedidoState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
    this.pedidoId,
  });

  CrearPedidoState copyWith({
    bool?   cargando,
    String? error,
    bool?   exitoso,
    String? pedidoId,
  }) => CrearPedidoState(
    cargando: cargando ?? this.cargando,
    error:    error,
    exitoso:  exitoso  ?? this.exitoso,
    pedidoId: pedidoId ?? this.pedidoId,
  );
}

class CrearPedidoNotifier
    extends StateNotifier<CrearPedidoState> {
  CrearPedidoNotifier() : super(const CrearPedidoState());

  Future<void> crear({
    required List<ItemCarrito> items,
    required String            tipoPago,
    required String            tipoPedido,
    String?                    empresaId,
    double?                    latitud,
    double?                    longitud,
    String?                    notas,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      final body = <String, dynamic>{
        'items': items.map((i) => {
          'producto_id': i.producto.id,
          'cantidad':    i.cantidad,
        }).toList(),
        'tipo':             tipoPedido,
        'tipo_pago':        tipoPago,
        'latitud_entrega':  latitud,
        'longitud_entrega': longitud,
        'notas':            notas,
      };
      if (tipoPedido == 'reserva' && empresaId != null) {
        body['empresa_id'] = empresaId;
      }
      final r = await ApiClient.post('/pedidos/', data: body);
      state = state.copyWith(
        cargando: false,
        exitoso:  true,
        pedidoId: r.data['id'],
      );
    } catch (e) {
      String msg = 'Error al crear el pedido.';
      final match =
          RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  void resetear() => state = const CrearPedidoState();
}

final crearPedidoProvider =
    StateNotifierProvider.autoDispose<CrearPedidoNotifier,
        CrearPedidoState>(
  (ref) => CrearPedidoNotifier(),
);