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
  final String  estado;
  final String  tipoPago;
  final double  total;
  final String? vendedorNombre;
  final String? direccionEntrega;
  final String? aceptadoEn;
  final String  creadoEn;
  final double? latitudEntrega;   
  final double? longitudEntrega;  
  final List<Map<String, dynamic>> items;

  const PedidoCliente({
    required this.id,
    required this.estado,
    required this.tipoPago,
    required this.total,
    this.vendedorNombre,
    this.direccionEntrega,
    this.aceptadoEn,
    required this.creadoEn,
    required this.items,
    this.latitudEntrega,
    this.longitudEntrega,
  });

  factory PedidoCliente.fromJson(Map<String, dynamic> j) => PedidoCliente(
    id:               j['id'],
    estado:           j['estado'],
    tipoPago:         j['tipo_pago'],
    total:            (j['total'] as num).toDouble(),
    vendedorNombre:   j['vendedor_nombre'],
    direccionEntrega: j['direccion_entrega'],
    latitudEntrega:  j['latitud_entrega']  != null
      ? (j['latitud_entrega']  as num).toDouble() : null,
    longitudEntrega: j['longitud_entrega'] != null
      ? (j['longitud_entrega'] as num).toDouble() : null,
    aceptadoEn:       j['aceptado_en'],
    creadoEn:         j['creado_en'],
    items: (j['items'] as List)
        .map((i) => i as Map<String, dynamic>)
        .toList(),
  );

  String get estadoLabel {
    switch (estado) {
      case 'pendiente':   return '⏳ Pendiente';
      case 'aceptado':    return '✅ Aceptado';
      case 'en_camino':   return '🚚 En camino';
      case 'entregado':   return '🎉 Entregado';
      case 'cancelado':   return '❌ Cancelado';
      default:            return estado;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  CARRITO — StateNotifier
// ══════════════════════════════════════════════════════════
class CarritoState {
  final List<ItemCarrito> items;
  const CarritoState({this.items = const []});

  double get total =>
      items.fold(0, (s, i) => s + i.subtotal);

  int get cantidadTotal =>
      items.fold(0, (s, i) => s + i.cantidad);

  bool tieneProducto(String productoId) =>
      items.any((i) => i.producto.id == productoId);

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
    final idx = items.indexWhere((i) => i.producto.id == producto.id);
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
    final idx = items.indexWhere((i) => i.producto.id == productoId);
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
//  CONFIGURACIÓN DE PAGO
// ══════════════════════════════════════════════════════════
final configuracionPagoProvider =
    FutureProvider<ConfiguracionPago>((ref) async {
  final r = await ApiClient.get('/pedidos/configuracion');
  return ConfiguracionPago.fromJson(r.data);
});

// ══════════════════════════════════════════════════════════
//  MIS PEDIDOS
// ══════════════════════════════════════════════════════════
final misPedidosProvider =
    FutureProvider<List<PedidoCliente>>((ref) async {
  final r = await ApiClient.get('/pedidos/mis-pedidos');
  return (r.data as List)
      .map((p) => PedidoCliente.fromJson(p))
      .toList();
});

// ══════════════════════════════════════════════════════════
//  CREAR PEDIDO
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

class CrearPedidoNotifier extends StateNotifier<CrearPedidoState> {
  CrearPedidoNotifier() : super(const CrearPedidoState());

  Future<void> crear({
    required List<ItemCarrito> items,
    required String            tipoPago,
    String?                    direccion,
    double?                    latitud,
    double?                    longitud,
    String?                    notas, required String tipoPedido,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      final r = await ApiClient.post('/pedidos/', data: {
        'items': items.map((i) => {
          'producto_id': i.producto.id,
          'cantidad':    i.cantidad,
        }).toList(),
        'tipo_pago':         tipoPago,
        'direccion_entrega': direccion,
        'latitud_entrega':   latitud,
        'longitud_entrega':  longitud,
        'notas':             notas,
      });
      state = state.copyWith(
        cargando: false,
        exitoso:  true,
        pedidoId: r.data['id'],
      );
    } catch (e) {
      String msg = 'Error al crear el pedido.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  void resetear() => state = const CrearPedidoState();
}

final crearPedidoProvider =
    StateNotifierProvider.autoDispose<CrearPedidoNotifier, CrearPedidoState>(
  (ref) => CrearPedidoNotifier(),
);