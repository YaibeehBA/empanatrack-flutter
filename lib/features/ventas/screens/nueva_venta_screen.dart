// lib/features/ventas/screens/nueva_venta_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/nueva_venta_provider.dart';
import '../providers/productos_provider.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../../shared/models/producto_model.dart';
import '../../../shared/models/cliente_model.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';

class NuevaVentaScreen extends ConsumerStatefulWidget {
  const NuevaVentaScreen({super.key});

  @override
  ConsumerState<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends ConsumerState<NuevaVentaScreen> {
  final _notasCtrl       = TextEditingController();
  final _buscarClienteCtrl = TextEditingController();

  @override
  void dispose() {
    _notasCtrl.dispose();
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state           = ref.watch(nuevaVentaProvider);
    final productosAsync  = ref.watch(productosProvider);
    final clientesAsync   = ref.watch(clientesProvider);

    // Escuchar éxito o error
   ref.listen<NuevaVentaState>(nuevaVentaProvider, (prev, next) {
        if (next.exitoso) {
          // Refrescar dashboard al volver
          ref.invalidate(resumenDiaProvider);
          ref.invalidate(ventasHoyProvider);
          ref.invalidate(clientesProvider);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Venta registrada correctamente'),
              backgroundColor: AppColores.success,
            ),
          );
          
          context.pop();  // 
        }
        
        if (next.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
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
        title:           const Text('Nueva Venta',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),

      // ── Botón registrar fijo abajo ───────────────────────
      bottomNavigationBar: _BottomBar(
        total:    state.total,
        cargando: state.cargando,
        onTap:    () => ref.read(nuevaVentaProvider.notifier).registrarVenta(),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Selector tipo de venta ───────────────────────
          _SeccionTitulo(titulo: '1. Tipo de venta'),
          const SizedBox(height: 10),
          _SelectorTipo(
            seleccionado: state.tipo,
            onChange: (tipo) =>
                ref.read(nuevaVentaProvider.notifier).cambiarTipo(tipo),
          ),
          const SizedBox(height: 24),

          // ── Selector de cliente (solo si es crédito) ─────
          if (state.tipo == 'credito') ...[
            _SeccionTitulo(titulo: '2. Cliente'),
            const SizedBox(height: 10),
            clientesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Text('Error cargando clientes'),
              data: (clientes) => _SelectorCliente(
                clientes:         clientes,
                seleccionado:     state.clienteSelec,
                buscarCtrl:       _buscarClienteCtrl,
                onSeleccionar: (c) => ref
                    .read(nuevaVentaProvider.notifier)
                    .seleccionarCliente(c),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Productos ────────────────────────────────────
          _SeccionTitulo(
            titulo: state.tipo == 'credito' ? '3. Productos' : '2. Productos',
          ),
          const SizedBox(height: 10),
          productosAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                const Text('Error cargando productos'),
            data: (productos) => _ListaProductos(
              productos: productos,
              carrito:   state.carrito,
              onChange: (id, delta) => ref
                  .read(nuevaVentaProvider.notifier)
                  .cambiarCantidad(id, delta),
              onAgregar: (p) => ref
                  .read(nuevaVentaProvider.notifier)
                  .agregarProducto(p),
            ),
          ),
          const SizedBox(height: 24),

          // ── Carrito (resumen) ─────────────────────────────
          if (state.carrito.isNotEmpty) ...[
            _SeccionTitulo(
              titulo: state.tipo == 'credito' ? '4. Resumen' : '3. Resumen',
            ),
            const SizedBox(height: 10),
            _ResumenCarrito(carrito: state.carrito, total: state.total),
            const SizedBox(height: 24),
          ],

          // ── Notas ─────────────────────────────────────────
          _SeccionTitulo(titulo: 'Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller:  _notasCtrl,
            maxLines:    2,
            onChanged: (v) =>
                ref.read(nuevaVentaProvider.notifier).actualizarNotas(v),
            decoration: InputDecoration(
              hintText:     'Ej: Entrega a las 10am...',
              border:       OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled:      true,
              fillColor:   Colors.white,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Widgets internos ───────────────────────────────────────

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo.toUpperCase(),
      style: const TextStyle(
        fontSize:      12,
        fontWeight:    FontWeight.bold,
        color:         AppColores.textSecond,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SelectorTipo extends StatelessWidget {
  final String   seleccionado;
  final Function(String) onChange;
  const _SelectorTipo({required this.seleccionado, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TipoBtn(
          label:      '💳  Fiado (Crédito)',
          valor:      'credito',
          activo:     seleccionado == 'credito',
          color:      AppColores.warning,
          onTap:      () => onChange('credito'),
        ),
        const SizedBox(width: 12),
        _TipoBtn(
          label:      '💵  Contado',
          valor:      'contado',
          activo:     seleccionado == 'contado',
          color:      AppColores.success,
          onTap:      () => onChange('contado'),
        ),
      ],
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String  label;
  final String  valor;
  final bool    activo;
  final Color   color;
  final VoidCallback onTap;
  const _TipoBtn({
    required this.label, required this.valor, required this.activo,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:  const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:        activo ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
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
}

class _SelectorCliente extends StatefulWidget {
  final List<ClienteModel>    clientes;
  final ClienteModel?         seleccionado;
  final TextEditingController buscarCtrl;
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
    return widget.clientes.where((c) =>
      c.nombre.toLowerCase().contains(q) ||
      c.cedula.contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Campo de búsqueda / cliente seleccionado
        GestureDetector(
          onTap: () => setState(() => _mostrarLista = !_mostrarLista),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(
                color: widget.seleccionado != null
                    ? AppColores.accent
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: AppColores.textSecond),
                const SizedBox(width: 12),
                Expanded(
                  child: widget.seleccionado != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.seleccionado!.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color:      AppColores.textPrimary,
                              ),
                            ),
                            Text(
                              'CI: ${widget.seleccionado!.cedula}  •  ${widget.seleccionado!.empresa ?? 'Independiente'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color:    AppColores.textSecond,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Seleccionar cliente...',
                          style: TextStyle(color: AppColores.textSecond),
                        ),
                ),
                Icon(
                  _mostrarLista
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColores.textSecond,
                ),
              ],
            ),
          ),
        ),

        // Lista desplegable
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
            child: Column(
              children: [
                // Buscador interno
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller:  widget.buscarCtrl,
                    autofocus:   true,
                    onChanged:   (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:    'Buscar por nombre o cédula...',
                      prefixIcon:  const Icon(Icons.search),
                      border:      OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense:     true,
                      filled:      true,
                      fillColor:   AppColores.background,
                    ),
                  ),
                ),
                // Lista de resultados
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap:  true,
                    itemCount:   _filtrados.length,
                    itemBuilder: (ctx, i) {
                      final c = _filtrados[i];
                      return ListTile(
                        title: Text(
                          c.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                           '${c.empresa ?? 'Independiente'}  •  CI: ${c.cedula}',
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColores.accent.withOpacity(0.15),
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
                // ── NUEVO: Botón para crear cliente ─────────────
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColores.success.withOpacity(0.15),
                    child: const Icon(
                      Icons.person_add_outlined,
                      color: AppColores.success,
                    ),
                  ),
                  title: const Text(
                    '+ Registrar nuevo cliente',
                    style: TextStyle(
                      color: AppColores.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('El cliente no está en la lista'),
                  onTap: () async {
                    setState(() => _mostrarLista = false);
                    // Navegar y esperar el cliente creado
                    final nuevoCliente = await context.push<ClienteModel>(
                      '/nuevo-cliente',
                      extra: true, // desdeNuevaVenta = true
                    );
                    if (nuevoCliente != null) {
                      widget.onSeleccionar(nuevoCliente);
                    }
                  },
                ),
                // ────────────────────────────────────────────────
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ListaProductos extends StatelessWidget {
  final List<ProductoModel>  productos;
  final List<ItemCarrito>    carrito;
  final Function(String, int) onChange;
  final Function(ProductoModel) onAgregar;

  const _ListaProductos({
    required this.productos,
    required this.carrito,
    required this.onChange,
    required this.onAgregar,
  });

  int _cantidadEn(String productoId) {
    final item = carrito.where((i) => i.producto.id == productoId);
    return item.isEmpty ? 0 : item.first.cantidad;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: productos.map((p) {
        final cantidad = _cantidadEn(p.id);
        return Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cantidad > 0
                  ? AppColores.accent
                  : Colors.grey.shade200,
              width: cantidad > 0 ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Ícono producto
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color:        AppColores.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🫓', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),

              // Nombre y precio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color:      AppColores.textPrimary,
                      ),
                    ),
                    Text(
                      '\$${p.precio.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        color:   AppColores.accent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Controles cantidad
              if (cantidad == 0)
                GestureDetector(
                  onTap: () => onAgregar(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:        AppColores.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '+ Agregar',
                      style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize:   13,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    _CantidadBtn(
                      icono:  Icons.remove,
                      onTap:  () => onChange(p.id, -1),
                      color:  AppColores.danger,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$cantidad',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   16,
                        ),
                      ),
                    ),
                    _CantidadBtn(
                      icono:  Icons.add,
                      onTap:  () => onChange(p.id, 1),
                      color:  AppColores.success,
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CantidadBtn extends StatelessWidget {
  final IconData     icono;
  final VoidCallback onTap;
  final Color        color;
  const _CantidadBtn({required this.icono, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icono, size: 18, color: color),
      ),
    );
  }
}

class _ResumenCarrito extends StatelessWidget {
  final List<ItemCarrito> carrito;
  final double            total;
  const _ResumenCarrito({required this.carrito, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:     const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColores.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColores.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          ...carrito.map((i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '${i.cantidad}x  ${i.producto.nombre}',
                  style: const TextStyle(color: AppColores.textPrimary),
                ),
                const Spacer(),
                Text(
                  '\$${i.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                  color:      AppColores.primary,
                ),
              ),
              const Spacer(),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   20,
                  color:      AppColores.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double       total;
  final bool         cargando;
  final VoidCallback onTap;
  const _BottomBar({required this.total, required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 16,
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
      child: Row(
        children: [
          Column(
            mainAxisSize:        MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total a registrar',
                  style: TextStyle(color: AppColores.textSecond, fontSize: 12)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:  cargando ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: cargando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Registrar Venta',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}