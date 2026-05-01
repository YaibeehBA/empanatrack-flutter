import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/producto_model.dart';
import '../../../shared/models/cliente_model.dart';

class ItemCarrito {
  final ProductoModel producto;
  final int           cantidad;

  const ItemCarrito({required this.producto, required this.cantidad});

  double get subtotal => producto.precio * cantidad;

  ItemCarrito copyWith({int? cantidad}) =>
      ItemCarrito(producto: producto, cantidad: cantidad ?? this.cantidad);
}

class NuevaVentaState {
  final String            tipo;
  final ClienteModel?     clienteSelec;
  final List<ItemCarrito> carrito;
  final String            notas;
  final bool              cargando;
  final String?           error;
  final bool              exitoso;
  final String?           reservaId;     // ← NUEVO: si viene de una reserva

  const NuevaVentaState({
    this.tipo          = 'credito',
    this.clienteSelec,
    this.carrito       = const [],
    this.notas         = '',
    this.cargando      = false,
    this.error,
    this.exitoso       = false,
    this.reservaId,                      // ← NUEVO
  });

  double get total => carrito.fold(0, (sum, i) => sum + i.subtotal);

  bool get esDesdeReserva => reservaId != null;

  NuevaVentaState copyWith({
    String?            tipo,
    ClienteModel?      clienteSelec,
    bool               limpiarCliente = false,
    List<ItemCarrito>? carrito,
    String?            notas,
    bool?              cargando,
    String?            error,
    bool?              exitoso,
    String?            reservaId,
  }) => NuevaVentaState(
    tipo:         tipo          ?? this.tipo,
    clienteSelec: limpiarCliente ? null
        : (clienteSelec ?? this.clienteSelec),
    carrito:      carrito       ?? this.carrito,
    notas:        notas         ?? this.notas,
    cargando:     cargando      ?? this.cargando,
    error:        error,
    exitoso:      exitoso       ?? this.exitoso,
    reservaId:    reservaId     ?? this.reservaId,
  );
}

class NuevaVentaNotifier extends StateNotifier<NuevaVentaState> {
  NuevaVentaNotifier([NuevaVentaState? inicial])
      : super(inicial ?? const NuevaVentaState());

  void cambiarTipo(String tipo) {
    // No permitir cambiar tipo si viene de reserva
    if (state.esDesdeReserva) return;
    state = state.copyWith(
      tipo:           tipo,
      limpiarCliente: tipo == 'contado',
    );
  }

  void seleccionarCliente(ClienteModel cliente) {
    state = state.copyWith(clienteSelec: cliente);
  }

  void agregarProducto(ProductoModel producto) {
    final carrito = List<ItemCarrito>.from(state.carrito);
    final index   = carrito
        .indexWhere((i) => i.producto.id == producto.id);
    if (index >= 0) {
      carrito[index] =
          carrito[index].copyWith(cantidad: carrito[index].cantidad + 1);
    } else {
      carrito.add(ItemCarrito(producto: producto, cantidad: 1));
    }
    state = state.copyWith(carrito: carrito);
  }

  void cambiarCantidad(String productoId, int delta) {
    final carrito = List<ItemCarrito>.from(state.carrito);
    final index   =
        carrito.indexWhere((i) => i.producto.id == productoId);
    if (index < 0) return;
    final nueva = carrito[index].cantidad + delta;
    if (nueva <= 0) {
      carrito.removeAt(index);
    } else {
      carrito[index] = carrito[index].copyWith(cantidad: nueva);
    }
    state = state.copyWith(carrito: carrito);
  }

  void actualizarNotas(String notas) =>
      state = state.copyWith(notas: notas);

  Future<void> registrarVenta() async {
    if (state.carrito.isEmpty) {
      state = state.copyWith(error: 'Agrega al menos un producto.');
      return;
    }
    if (state.tipo == 'credito' && state.clienteSelec == null) {
      state = state.copyWith(
          error: 'Selecciona un cliente para el fiado.');
      return;
    }

    state = state.copyWith(cargando: true);
    try {
      await ApiClient.post('/ventas/', data: {
        'tipo':       state.tipo,
        'cliente_id': state.clienteSelec?.id,
        'notas':      state.notas,
        'reserva_id': state.reservaId,   // ← NUEVO: backend marca entregada
        'detalle': state.carrito.map((item) => {
          'producto_id':    item.producto.id,
          'cantidad':       item.cantidad,
          'precio_unitario': item.producto.precio,
        }).toList(),
      });
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      final match =
          RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      state = state.copyWith(
        cargando: false,
        error:    match?.group(1) ?? 'Error al registrar la venta.',
      );
    }
  }

  void resetear() => state = const NuevaVentaState();
}

// Provider base (sin estado inicial)
final nuevaVentaProvider =
    StateNotifierProvider.autoDispose<NuevaVentaNotifier, NuevaVentaState>(
  (ref) => NuevaVentaNotifier(),
);

// Provider con estado inicial — para abrir desde una reserva
final nuevaVentaInicialProvider = StateNotifierProvider.autoDispose
    .family<NuevaVentaNotifier, NuevaVentaState, NuevaVentaState>(
  (ref, inicial) => NuevaVentaNotifier(inicial),
);