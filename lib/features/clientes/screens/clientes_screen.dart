import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/clientes_provider.dart';
import '../../../shared/models/cliente_model.dart';
import '../../admin/providers/admin_provider.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _scrollCtrl   = ScrollController();
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _busquedaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(clientesPaginadosProvider.notifier).cargarMas();
    }
  }

  void _onBusqueda(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(clientesPaginadosProvider.notifier)
          .cargarPrimera(busqueda: v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientesPaginadosProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Clientes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => ref
                .read(clientesPaginadosProvider.notifier)
                .cargarPrimera(busqueda: _busquedaCtrl.text.trim()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/nuevo-cliente');
          ref.read(clientesPaginadosProvider.notifier)
              .cargarPrimera(busqueda: _busquedaCtrl.text.trim());
        },
        backgroundColor: AppColores.accent,
        foregroundColor: Colors.white,
        icon:  const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo Cliente',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [

        // ── Buscador ──────────────────────────────────
        Container(
          color:   AppColores.primary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged:  _onBusqueda,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:  'Buscar por nombre, cédula o empresa...',
              hintStyle: const TextStyle(
                  color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Colors.white54),
              suffixIcon: _busquedaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white54),
                      onPressed: () {
                        _busquedaCtrl.clear();
                        ref.read(clientesPaginadosProvider.notifier)
                            .cargarPrimera();
                      },
                    )
                  : null,
              filled:    true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:   BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 16),
            ),
          ),
        ),

        // ── Contenido ─────────────────────────────────
        if (state.cargando)
          const Expanded(
              child: Center(child: CircularProgressIndicator()))
        else if (state.error != null)
          Expanded(child: _ErrorWidget(
            onReintentar: () => ref
                .read(clientesPaginadosProvider.notifier)
                .cargarPrimera(),
          ))
        else if (state.clientes.isEmpty)
          const Expanded(child: _EmptyWidget())
        else
          Expanded(child: Column(children: [
            _BannerTotal(
              total:    state.clientes.fold(0.0,
                  (s, c) => s + c.saldoActual),
              cantidad: state.clientes.length,
            ),
            Expanded(child: RefreshIndicator(
              onRefresh: () => ref
                  .read(clientesPaginadosProvider.notifier)
                  .cargarPrimera(
                      busqueda: _busquedaCtrl.text.trim()),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                    16, 16, 16, 100),
                itemCount:  state.clientes.length + 1,
                itemBuilder: (_, i) {
                  if (i == state.clientes.length) {
                    return state.cargandoMas
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child:
                                    CircularProgressIndicator()))
                        : state.hayMas
                            ? const SizedBox(height: 8)
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: Text(
                                  '— ${state.clientes.length} clientes —',
                                  style: const TextStyle(
                                      color: AppColores.textSecond,
                                      fontSize: 12),
                                )),
                              );
                  }
                  return _ClienteCard(
                      cliente: state.clientes[i]);
                },
              ),
            )),
          ])),
      ]),
    );
  }
}

// ── Banner total ───────────────────────────────────────────
class _BannerTotal extends StatelessWidget {
  final double total;
  final int    cantidad;
  const _BannerTotal({required this.total, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: AppColores.primary),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Total en deudas',
              style: TextStyle(
                  color: Colors.white70, fontSize: 13)),
          Text('\$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   28,
                fontWeight: FontWeight.bold,
              )),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$cantidad clientes',
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold,
              )),
        ),
      ]),
    );
  }
}

// ── Card cliente ───────────────────────────────────────────
class _ClienteCard extends ConsumerWidget {
  final ClienteModel cliente;
  const _ClienteCard({required this.cliente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tieneDeuda = cliente.saldoActual > 0;
    final colorSaldo = tieneDeuda
        ? AppColores.danger : AppColores.success;

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius:          24,
            backgroundColor: AppColores.accent.withOpacity(0.12),
            child: Text(
              cliente.nombre[0].toUpperCase(),
              style: const TextStyle(
                color:      AppColores.accent,
                fontWeight: FontWeight.bold,
                fontSize:   18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cliente.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                    color:      AppColores.textPrimary,
                  )),
              if (cliente.empresa != null)
                Row(children: [
                  const Icon(Icons.business_outlined,
                      size: 13, color: AppColores.textSecond),
                  const SizedBox(width: 4),
                  Text(cliente.empresa!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textSecond)),
                ]),
              Row(children: [
                const Icon(Icons.badge_outlined,
                    size: 13, color: AppColores.textSecond),
                const SizedBox(width: 4),
                Text('CI: ${cliente.cedula}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textSecond)),
              ]),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Text(
              '\$${cliente.saldoActual.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   16,
                color:      colorSaldo,
              ),
            ),
            Text(tieneDeuda ? 'Debe' : 'Al día ✓',
                style: TextStyle(
                    fontSize: 11, color: colorSaldo)),
          ]),
        ]),

        // Botón cobrar
        if (tieneDeuda) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('/registrar-pago/${cliente.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColores.success,
                side: const BorderSide(color: AppColores.success),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon:  const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Registrar cobro',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],

        // Botón eliminar
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                _confirmarEliminar(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.danger,
              side: const BorderSide(color: AppColores.danger),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon:  const Icon(Icons.delete_outline, size: 18),
            label: const Text('Eliminar cliente',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColores.danger),
          SizedBox(width: 8),
          Text('Eliminar cliente'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(
                  color: AppColores.textPrimary, fontSize: 14),
              children: [
                const TextSpan(text: '¿Eliminar a '),
                TextSpan(
                  text: cliente.nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?'),
              ],
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColores.warning.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: AppColores.warning, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Si tiene ventas registradas no se podrá '
                  'eliminar.',
                  style: TextStyle(
                      fontSize: 12, color: AppColores.warning),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:     const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(adminOpProvider.notifier)
                  .eliminarCliente(cliente.id.toString());
              final state = ref.read(adminOpProvider);
              if (state.error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:         Text(state.error!),
                    backgroundColor: AppColores.danger,
                  ),
                );
                ref.read(adminOpProvider.notifier).resetear();
                return;
              }
              ref.read(clientesPaginadosProvider.notifier)
                  .cargarPrimera();
              ref.read(adminOpProvider.notifier).resetear();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets de estado ──────────────────────────────────────
class _ErrorWidget extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorWidget({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off,
            size: 60, color: AppColores.textSecond),
        const SizedBox(height: 16),
        const Text('No se pudieron cargar los clientes',
            style: TextStyle(color: AppColores.textSecond)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onReintentar,
          child:     const Text('Reintentar'),
        ),
      ],
    ),
  );
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🏪', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('No hay clientes registrados aún.',
            style: TextStyle(
                color: AppColores.textSecond, fontSize: 15)),
      ],
    ),
  );
}
