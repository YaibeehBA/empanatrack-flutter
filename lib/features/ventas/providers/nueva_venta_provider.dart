import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/producto_model.dart';
import '../../../shared/models/cliente_model.dart';

// Representa una línea del carrito
class ItemCarrito {
  final ProductoModel producto;
  final int           cantidad;

  const ItemCarrito({required this.producto, required this.cantidad});

  double get subtotal => producto.precio * cantidad;

  ItemCarrito copyWith({int? cantidad}) =>
      ItemCarrito(producto: producto, cantidad: cantidad ?? this.cantidad);
}

// Estado completo del formulario de nueva venta
class NuevaVentaState {
  final String            tipo;           // 'contado' o 'credito'
  final ClienteModel?     clienteSelec;
  final List<ItemCarrito> carrito;
  final String            notas;
  final bool              cargando;
  final String?           error;
  final bool              exitoso;

  const NuevaVentaState({
    this.tipo          = 'credito',
    this.clienteSelec,
    this.carrito       = const [],
    this.notas         = '',
    this.cargando      = false,
    this.error,
    this.exitoso       = false,
  });

  double get total => carrito.fold(0, (sum, i) => sum + i.subtotal);

  NuevaVentaState copyWith({
    String?            tipo,
    ClienteModel?      clienteSelec,
    bool               limpiarCliente = false,
    List<ItemCarrito>? carrito,
    String?            notas,
    bool?              cargando,
    String?            error,
    bool?              exitoso,
  }) {
    return NuevaVentaState(
      tipo:          tipo          ?? this.tipo,
      clienteSelec:  limpiarCliente ? null : (clienteSelec ?? this.clienteSelec),
      carrito:       carrito       ?? this.carrito,
      notas:         notas         ?? this.notas,
      cargando:      cargando      ?? this.cargando,
      error:         error,
      exitoso:       exitoso       ?? this.exitoso,
    );
  }
}

class NuevaVentaNotifier extends StateNotifier<NuevaVentaState> {
  NuevaVentaNotifier() : super(const NuevaVentaState());

  void cambiarTipo(String tipo) {
    state = state.copyWith(
      tipo:           tipo,
      limpiarCliente: tipo == 'contado', // Si es contado, quitar cliente
    );
  }

  void seleccionarCliente(ClienteModel cliente) {
    state = state.copyWith(clienteSelec: cliente);
  }

  void agregarProducto(ProductoModel producto) {
    final carrito  = List<ItemCarrito>.from(state.carrito);
    final index    = carrito.indexWhere((i) => i.producto.id == producto.id);

    if (index >= 0) {
      // Si ya está en el carrito, aumentar cantidad
      carrito[index] = carrito[index].copyWith(
        cantidad: carrito[index].cantidad + 1,
      );
    } else {
      carrito.add(ItemCarrito(producto: producto, cantidad: 1));
    }
    state = state.copyWith(carrito: carrito);
  }

  void cambiarCantidad(String productoId, int delta) {
    final carrito = List<ItemCarrito>.from(state.carrito);
    final index   = carrito.indexWhere((i) => i.producto.id == productoId);
    if (index < 0) return;

    final nuevaCantidad = carrito[index].cantidad + delta;
    if (nuevaCantidad <= 0) {
      carrito.removeAt(index); // Quitar del carrito si llega a 0
    } else {
      carrito[index] = carrito[index].copyWith(cantidad: nuevaCantidad);
    }
    state = state.copyWith(carrito: carrito);
  }

  void actualizarNotas(String notas) {
    state = state.copyWith(notas: notas);
  }

  Future<void> registrarVenta() async {
  if (state.carrito.isEmpty) {
    state = state.copyWith(error: 'Agrega al menos un producto.');
    return;
  }
  if (state.tipo == 'credito' && state.clienteSelec == null) {
    state = state.copyWith(error: 'Selecciona un cliente para el fiado.');
    return;
  }

  state = state.copyWith(cargando: true);
  try {
    await ApiClient.post('/ventas/', data: {
      'tipo':       state.tipo,
      'cliente_id': state.clienteSelec?.id,
      'notas':      state.notas,
      'detalle': state.carrito.map((item) => {
        'producto_id': item.producto.id,
        'cantidad':    item.cantidad,
        'precio_unitario': item.producto.precio,
      }).toList(),
    });

    state = state.copyWith(cargando: false, exitoso: true);
  } catch (e) {
    String msg = 'Error al registrar la venta.';
    final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
    if (match != null) msg = match.group(1)!;
    state = state.copyWith(cargando: false, error: msg);
  }
}

  void resetear() {
    state = const NuevaVentaState();
  }
}

final nuevaVentaProvider =
    StateNotifierProvider.autoDispose<NuevaVentaNotifier, NuevaVentaState>(
  (ref) => NuevaVentaNotifier(),
);