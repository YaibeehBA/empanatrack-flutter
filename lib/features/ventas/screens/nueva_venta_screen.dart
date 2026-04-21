import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/nueva_venta_provider.dart';
import '../providers/productos_provider.dart';
import '../providers/ruta_activa_provider.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';
import '../widgets/index.dart';

class NuevaVentaScreen extends ConsumerStatefulWidget {
  const NuevaVentaScreen({super.key});

  @override
  ConsumerState<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends ConsumerState<NuevaVentaScreen> {
  final _notasCtrl         = TextEditingController();
  final _buscarClienteCtrl = TextEditingController();

  @override
  void dispose() {
    _notasCtrl.dispose();
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state          = ref.watch(nuevaVentaProvider);
    final productosAsync = ref.watch(productosProvider);
    final clientesAsync  = ref.watch(clientesProvider);

    final stockAsync = ref.watch(stockRestanteProvider);
    final stockMap   = stockAsync.maybeWhen(
      data: (s) => Map<String, int>.fromEntries(
          s.productos.map((p) => MapEntry(p.productoId, p.cantidadRestante))),
      orElse: () => <String, int>{},
    );

    ref.listen<NuevaVentaState>(nuevaVentaProvider, (prev, next) {
      if (next.exitoso) {
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
          ),
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) context.pop();
        });
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
        title: const Text('Nueva Venta',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: BottomBar(
        total:    state.total,
        cargando: state.cargando,
        onTap:    () =>
            ref.read(nuevaVentaProvider.notifier).registrarVenta(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Tipo de venta ────────────────────────────────
          const SeccionTitulo(titulo: '1. Tipo de venta'),
          const SizedBox(height: 10),
          SelectorTipo(
            seleccionado: state.tipo,
            onChange: (tipo) =>
                ref.read(nuevaVentaProvider.notifier).cambiarTipo(tipo),
          ),
          const SizedBox(height: 24),

          // ── Cliente (solo crédito) ───────────────────────
          if (state.tipo == 'credito') ...[
            const SeccionTitulo(titulo: '2. Cliente'),
            const SizedBox(height: 10),
            clientesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Text('Error cargando clientes'),
              data: (clientes) => SelectorCliente(
                clientes:      clientes,
                seleccionado:  state.clienteSelec,
                buscarCtrl:    _buscarClienteCtrl,
                onSeleccionar: (c) => ref
                    .read(nuevaVentaProvider.notifier)
                    .seleccionarCliente(c),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Productos ────────────────────────────────────
          SeccionTitulo(
            titulo: state.tipo == 'credito'
                ? '3. Productos'
                : '2. Productos',
          ),
          const SizedBox(height: 10),
          productosAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                const Text('Error cargando productos'),
            data: (productos) => ListaProductos(
              productos:       productos,
              carrito:         state.carrito,
              stockDisponible: stockMap,
              onChange:        (id, delta) => ref
                  .read(nuevaVentaProvider.notifier)
                  .cambiarCantidad(id, delta),
              onAgregar: (p) => ref
                  .read(nuevaVentaProvider.notifier)
                  .agregarProducto(p),
            ),
          ),
          const SizedBox(height: 24),

          // ── Resumen carrito ──────────────────────────────
          if (state.carrito.isNotEmpty) ...[
            SeccionTitulo(
              titulo: state.tipo == 'credito'
                  ? '4. Resumen'
                  : '3. Resumen',
            ),
            const SizedBox(height: 10),
            ResumenCarrito(carrito: state.carrito, total: state.total),
            const SizedBox(height: 24),
          ],

          // ── Notas ────────────────────────────────────────
          const SeccionTitulo(titulo: 'Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            onChanged:  (v) => ref
                .read(nuevaVentaProvider.notifier)
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