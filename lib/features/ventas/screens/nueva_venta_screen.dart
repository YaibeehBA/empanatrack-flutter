import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/nueva_venta_provider.dart';
import '../providers/productos_provider.dart';
import '../providers/ruta_activa_provider.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../../shared/models/producto_model.dart';
import '../../../shared/models/cliente_model.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';

// ══════════════════════════════════════════════════════════
//  SCREEN PRINCIPAL
// ══════════════════════════════════════════════════════════

class NuevaVentaScreen extends ConsumerStatefulWidget {
  final String?       reservaId;
  final ClienteModel? clienteInicial;
  final List<({String productoId, String nombre,
               double precio, int cantidad})> productosIniciales;

  const NuevaVentaScreen({
    super.key,
    this.reservaId,
    this.clienteInicial,
    this.productosIniciales = const [],
  });

  @override
  ConsumerState<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

// ══════════════════════════════════════════════════════════
//  STATE
// ══════════════════════════════════════════════════════════

class _NuevaVentaScreenState extends ConsumerState<NuevaVentaScreen> {
  final _notasCtrl         = TextEditingController();
  final _buscarClienteCtrl = TextEditingController();

  // ✅ FIX CLAVE: el estado inicial se calcula UNA SOLA VEZ en initState
  // y se guarda aquí. De esta forma nuevaVentaInicialProvider recibe
  // siempre la MISMA instancia de NuevaVentaState como clave del family,
  // evitando que cada rebuild cree una instancia nueva y rompa el ref.listen.
  late final NuevaVentaState? _estadoInicialFijo;

  bool get _esDesdeReserva => widget.reservaId != null;

  @override
  void initState() {
    super.initState();
    // Calcular estado inicial una sola vez
    if (_esDesdeReserva) {
      final carrito = widget.productosIniciales.map((p) {
        final producto = ProductoModel(
          id:     p.productoId,
          nombre: p.nombre,
          precio: p.precio,
        );
        return ItemCarrito(producto: producto, cantidad: p.cantidad);
      }).toList();

      _estadoInicialFijo = NuevaVentaState(
        tipo:         'contado',
        clienteSelec: widget.clienteInicial,
        carrito:      carrito,
        reservaId:    widget.reservaId,
      );
    } else {
      _estadoInicialFijo = null;
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: usa _estadoInicialFijo (calculado en initState, estable)
    // en lugar de _estadoInicial() (llamado en cada build → clave nueva
    // en cada rebuild → instancia distinta del family → listener roto)
    final provider = _esDesdeReserva
        ? nuevaVentaInicialProvider(_estadoInicialFijo!)
        : nuevaVentaProvider;

    final state          = ref.watch(provider);
    final productosAsync = ref.watch(productosProvider);
    final clientesAsync  = ref.watch(clientesProvider);
    final stockAsync     = ref.watch(stockRestanteProvider);

    final stockMap = stockAsync.maybeWhen(
      data: (s) => Map<String, int>.fromEntries(
          s.productos.map((p) => MapEntry(p.productoId, p.cantidadRestante))),
      orElse: () => <String, int>{},
    );

    ref.listen<NuevaVentaState>(provider, (prev, next) {
      if (next.exitoso) {
        ref.invalidate(stockRestanteProvider);
        ref.invalidate(historialVentasProvider('hoy'));
        ref.invalidate(historialVentasProvider('ayer'));
        ref.invalidate(historialVentasProvider('semana'));
        ref.invalidate(historialVentasProvider('mes'));
        ref.invalidate(ventasHoyProvider);
        ref.invalidate(resumenDiaProvider('hoy'));
        ref.invalidate(resumenDiaProvider('ayer'));
        ref.invalidate(resumenDiaProvider('semana'));
        ref.invalidate(resumenDiaProvider('mes'));
        ref.invalidate(clientesProvider);
        ref.read(clientesPaginadosProvider.notifier).cargarPrimera();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Venta registrada correctamente'),
            backgroundColor: AppColores.success,
            duration:        Duration(milliseconds: 600),
          ),
        );

        // ✅ FIX: Navigator.of imperativo, sin delay, sin go_router.
        // Funciona correctamente tanto si la pantalla fue empujada con
        // Navigator.push (desde reserva) como con context.push (go_router).
        if (context.mounted) Navigator.of(context).pop(true);
      }

      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(next.error!),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: Text(
          _esDesdeReserva ? 'Entregar Reserva' : 'Nueva Venta',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        total:    state.total,
        cargando: state.cargando,
        label:    _esDesdeReserva ? 'Confirmar Entrega' : 'Registrar Venta',
        onTap:    () => ref.read(provider.notifier).registrarVenta(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Banner reserva ───────────────────────────────
          if (_esDesdeReserva) ...[
            _BannerReserva(
                cliente: widget.clienteInicial?.nombre ?? 'Cliente'),
            const SizedBox(height: 20),
          ],

          // ── Tipo de venta (solo si NO es reserva) ────────
          if (!_esDesdeReserva) ...[
            const _SeccionTitulo(titulo: '1. Tipo de venta'),
            const SizedBox(height: 10),
            _SelectorTipo(
              seleccionado: state.tipo,
              onChange: (tipo) =>
                  ref.read(provider.notifier).cambiarTipo(tipo),
            ),
            const SizedBox(height: 24),
          ],

          // ── Cliente (solo crédito y NO reserva) ──────────
          if (state.tipo == 'credito' && !_esDesdeReserva) ...[
            const _SeccionTitulo(titulo: '2. Cliente'),
            const SizedBox(height: 10),
            clientesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Text('Error cargando clientes'),
              data: (clientes) => _SelectorCliente(
                clientes:      clientes,
                seleccionado:  state.clienteSelec,
                buscarCtrl:    _buscarClienteCtrl,
                onSeleccionar: (c) => ref
                    .read(provider.notifier)
                    .seleccionarCliente(c),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Productos ────────────────────────────────────
          _SeccionTitulo(
            titulo: _esDesdeReserva
                ? 'Productos de la reserva'
                : state.tipo == 'credito'
                    ? '3. Productos'
                    : '2. Productos',
          ),
          const SizedBox(height: 10),

          if (_esDesdeReserva)
            _ListaProductosReserva(carrito: state.carrito)
          else
            productosAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Text('Error cargando productos'),
              data: (productos) => _ListaProductos(
                productos:       productos,
                carrito:         state.carrito,
                stockDisponible: stockMap,
                onChange: (id, delta) => ref
                    .read(provider.notifier)
                    .cambiarCantidad(id, delta),
                onAgregar: (p) => ref
                    .read(provider.notifier)
                    .agregarProducto(p),
              ),
            ),
          const SizedBox(height: 24),

          // ── Resumen carrito ──────────────────────────────
          if (state.carrito.isNotEmpty) ...[
            _SeccionTitulo(
              titulo: state.tipo == 'credito'
                  ? '4. Resumen'
                  : '3. Resumen',
            ),
            const SizedBox(height: 10),
            _ResumenCarrito(
                carrito: state.carrito, total: state.total),
            const SizedBox(height: 24),
          ],

          // ── Notas ────────────────────────────────────────
          const _SeccionTitulo(titulo: 'Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            onChanged:  (v) => ref
                .read(provider.notifier)
                .actualizarNotas(v),
            decoration: InputDecoration(
              hintText:  'Ej: Entrega a las 10am...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled:    true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) => Text(
    titulo.toUpperCase(),
    style: const TextStyle(
      fontSize:      12,
      fontWeight:    FontWeight.bold,
      color:         AppColores.textSecond,
      letterSpacing: 1.2,
    ),
  );
}

// ── Selector tipo ─────────────────────────────────────────
class _SelectorTipo extends StatelessWidget {
  final String           seleccionado;
  final Function(String) onChange;
  const _SelectorTipo(
      {required this.seleccionado, required this.onChange});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TipoBtn(
        label:  '💳  Fiado (Crédito)',
        valor:  'credito',
        activo: seleccionado == 'credito',
        color:  AppColores.warning,
        onTap:  () => onChange('credito'),
      ),
      const SizedBox(width: 12),
      _TipoBtn(
        label:  '💵  Contado',
        valor:  'contado',
        activo: seleccionado == 'contado',
        color:  AppColores.success,
        onTap:  () => onChange('contado'),
      ),
    ],
  );
}

class _TipoBtn extends StatelessWidget {
  final String       label;
  final String       valor;
  final bool         activo;
  final Color        color;
  final VoidCallback onTap;
  const _TipoBtn({
    required this.label,
    required this.valor,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        activo ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:      activo ? Colors.white : AppColores.textSecond,
              fontSize:   13,
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Selector cliente ──────────────────────────────────────
class _SelectorCliente extends StatefulWidget {
  final List<ClienteModel>     clientes;
  final ClienteModel?          seleccionado;
  final TextEditingController  buscarCtrl;
  final Function(ClienteModel) onSeleccionar;

  const _SelectorCliente({
    required this.clientes,
    required this.seleccionado,
    required this.buscarCtrl,
    required this.onSeleccionar,
  });

  @override
  State<_SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends State<_SelectorCliente> {
  bool _mostrarLista = false;

  List<ClienteModel> get _filtrados {
    final q = widget.buscarCtrl.text.toLowerCase();
    if (q.isEmpty) return widget.clientes;
    return widget.clientes
        .where((c) =>
            c.nombre.toLowerCase().contains(q) ||
            c.cedula.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GestureDetector(
        onTap: () =>
            setState(() => _mostrarLista = !_mostrarLista),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.seleccionado != null
                  ? AppColores.accent
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.person_outline,
                color: AppColores.textSecond),
            const SizedBox(width: 12),
            Expanded(
              child: widget.seleccionado != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.seleccionado!.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color:      AppColores.textPrimary,
                            )),
                        Text(
                          'CI: ${widget.seleccionado!.cedula}  •  '
                          '${widget.seleccionado!.empresa ?? 'Independiente'}',
                          style: const TextStyle(
                              fontSize: 12,
                              color:    AppColores.textSecond),
                        ),
                      ],
                    )
                  : const Text('Seleccionar cliente...',
                      style: TextStyle(color: AppColores.textSecond)),
            ),
            Icon(
              _mostrarLista
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppColores.textSecond,
            ),
          ]),
        ),
      ),

      if (_mostrarLista) ...[
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: widget.buscarCtrl,
                autofocus:  true,
                onChanged:  (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:   'Buscar por nombre o cédula...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense:   true,
                  filled:    true,
                  fillColor: AppColores.background,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap:  true,
                itemCount:   _filtrados.length,
                itemBuilder: (ctx, i) {
                  final c = _filtrados[i];
                  return ListTile(
                    title: Text(c.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${c.empresa ?? 'Independiente'}  •  CI: ${c.cedula}',
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColores.accent.withOpacity(0.15),
                      child: Text(
                        c.nombre[0].toUpperCase(),
                        style: const TextStyle(
                          color:      AppColores.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      widget.onSeleccionar(c);
                      widget.buscarCtrl.clear();
                      setState(() => _mostrarLista = false);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColores.success.withOpacity(0.15),
                child: const Icon(Icons.person_add_outlined,
                    color: AppColores.success),
              ),
              title: const Text(
                '+ Registrar nuevo cliente',
                style: TextStyle(
                  color:      AppColores.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('El cliente no está en la lista'),
              onTap: () async {
                setState(() => _mostrarLista = false);
                final nuevoCliente =
                    await context.push<ClienteModel>(
                  '/nuevo-cliente',
                  extra: true,
                );
                if (nuevoCliente != null) {
                  widget.onSeleccionar(nuevoCliente);
                }
              },
            ),
          ]),
        ),
      ],
    ],
  );
}

// ── Lista productos ───────────────────────────────────────
class _ListaProductos extends StatelessWidget {
  final List<ProductoModel>     productos;
  final List<ItemCarrito>       carrito;
  final Map<String, int>        stockDisponible;
  final Function(String, int)   onChange;
  final Function(ProductoModel) onAgregar;

  const _ListaProductos({
    required this.productos,
    required this.carrito,
    required this.stockDisponible,
    required this.onChange,
    required this.onAgregar,
  });

  int _stockRestante(String productoId) {
    if (stockDisponible.isEmpty) return 999;
    return stockDisponible[productoId] ?? 0;
  }

  int _cantidadEn(String productoId) {
    final item = carrito.where((i) => i.producto.id == productoId);
    return item.isEmpty ? 0 : item.first.cantidad;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: productos.map((p) {
        final cantidad = _cantidadEn(p.id);
        final restante = _stockRestante(p.id);
        final agotado  = stockDisponible.isNotEmpty && restante <= 0;
        final enLimite = !agotado && cantidad >= restante;

        return Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: agotado ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: agotado
                  ? Colors.grey.shade300
                  : cantidad > 0
                      ? AppColores.accent
                      : Colors.grey.shade200,
              width: cantidad > 0 ? 2 : 1,
            ),
          ),
          child: Row(children: [

            Opacity(
              opacity: agotado ? 0.4 : 1.0,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color:        AppColores.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(p.imagenUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Text('🫓',
                                    style: TextStyle(fontSize: 22)))))
                    : const Center(child: Text('🫓',
                        style: TextStyle(fontSize: 22))),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: agotado
                        ? AppColores.textSecond
                        : AppColores.textPrimary)),
                Text('\$${p.precio.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                        color: AppColores.accent, fontSize: 13)),
                if (stockDisponible.isNotEmpty)
                  Text(
                    agotado
                        ? 'Sin stock'
                        : 'Disponible: $restante uds',
                    style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color: agotado
                            ? AppColores.danger
                            : enLimite
                                ? AppColores.warning
                                : AppColores.success),
                  ),
              ],
            )),

            if (agotado)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Agotado',
                    style: TextStyle(
                        color:      AppColores.textSecond,
                        fontSize:   12,
                        fontWeight: FontWeight.bold)),
              )
            else if (cantidad == 0)
              GestureDetector(
                onTap: () => onAgregar(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:        AppColores.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('+ Agregar',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   13)),
                ),
              )
            else
              Row(children: [
                _CantidadBtn(
                    icono: Icons.remove,
                    onTap: () => onChange(p.id, -1),
                    color: AppColores.danger),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$cantidad',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _CantidadBtn(
                  icono:    Icons.add,
                  onTap:    enLimite ? null : () => onChange(p.id, 1),
                  color:    enLimite ? Colors.grey : AppColores.success,
                  disabled: enLimite,
                ),
              ]),
          ]),
        );
      }).toList(),
    );
  }
}

class _CantidadBtn extends StatelessWidget {
  final IconData      icono;
  final VoidCallback? onTap;
  final Color         color;
  final bool          disabled;

  const _CantidadBtn({
    required this.icono,
    required this.onTap,
    required this.color,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color:        color.withOpacity(disabled ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icono, size: 18,
          color: disabled ? Colors.grey.shade300 : color),
    ),
  );
}

// ── Resumen carrito ───────────────────────────────────────
class _ResumenCarrito extends StatelessWidget {
  final List<ItemCarrito> carrito;
  final double            total;
  const _ResumenCarrito(
      {required this.carrito, required this.total});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        AppColores.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: AppColores.primary.withOpacity(0.15)),
    ),
    child: Column(children: [
      ...carrito.map((i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('${i.cantidad}x  ${i.producto.nombre}',
                  style: const TextStyle(
                      color: AppColores.textPrimary)),
              const Spacer(),
              Text('\$${i.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
            ]),
          )),
      const Divider(height: 20),
      Row(children: [
        const Text('TOTAL',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   16,
                color:      AppColores.primary)),
        const Spacer(),
        Text('\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   20,
                color:      AppColores.primary)),
      ]),
    ]),
  );
}

// ── Bottom bar ────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final double       total;
  final bool         cargando;
  final String       label;
  final VoidCallback onTap;

  const _BottomBar({
    required this.total,
    required this.cargando,
    required this.onTap,
    this.label = 'Registrar Venta',
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20, 16, 20,
      MediaQuery.of(context).padding.bottom + 16,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset:     const Offset(0, -4),
        ),
      ],
    ),
    child: Row(children: [
      Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total a registrar',
              style: TextStyle(
                  color: AppColores.textSecond, fontSize: 12)),
          Text('\$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary)),
        ],
      ),
      const SizedBox(width: 20),
      Expanded(
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: cargando ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: cargando
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ]),
  );
}

// ── Banner reserva ─────────────────────────────────────────
class _BannerReserva extends StatelessWidget {
  final String cliente;
  const _BannerReserva({required this.cliente});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppColores.accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColores.accent.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Text('📋', style: TextStyle(fontSize: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entregando reserva',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.accent,
                  fontSize:   14)),
          Text('Cliente: $cliente',
              style: const TextStyle(
                  fontSize: 12,
                  color:    AppColores.textSecond)),
        ],
      )),
    ]),
  );
}

// ── Lista fija para reservas (no editable) ────────────────
class _ListaProductosReserva extends StatelessWidget {
  final List<ItemCarrito> carrito;
  const _ListaProductosReserva({required this.carrito});

  @override
  Widget build(BuildContext context) => Column(
    children: carrito.map((item) => Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.accent.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        AppColores.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(
            item.producto.nombre[0].toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color:      AppColores.accent,
                fontSize:   18),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.producto.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary)),
            Text('\$${item.producto.precio.toStringAsFixed(2)} c/u',
                style: const TextStyle(
                    fontSize: 12, color: AppColores.textSecond)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        AppColores.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${item.cantidad} uds',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.accent)),
        ),
      ]),
    )).toList(),
  );
}