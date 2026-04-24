import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/pedidos_cliente_provider.dart';
import '../screens/tracking_pedido_screen.dart';

// ══════════════════════════════════════════════════════════
//  PANTALLA MIS PEDIDOS
// ══════════════════════════════════════════════════════════
class PedidosClienteScreen extends ConsumerWidget {
  const PedidosClienteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misPedidosProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Mis Pedidos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(misPedidosProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Error al cargar pedidos',
                style: TextStyle(color: AppColores.textSecond)),
            ElevatedButton(
              onPressed: () => ref.invalidate(misPedidosProvider),
              child: const Text('Reintentar'),
            ),
          ],
        )),
        data: (pedidos) => pedidos.isEmpty
            ? const _SinPedidos()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(misPedidosProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: pedidos.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _CardPedido(pedido: pedidos[i]),
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD PEDIDO
// ══════════════════════════════════════════════════════════
class _CardPedido extends StatelessWidget {
  final PedidoCliente pedido;
  const _CardPedido({required this.pedido});

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'pendiente': return AppColores.warning;
      case 'aceptado':  return AppColores.primary;
      case 'en_camino': return AppColores.accent;
      case 'entregado': return AppColores.success;
      case 'cancelado': return AppColores.danger;
      default:          return AppColores.textSecond;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Encabezado: estado + tipo + fecha ──────────
          Row(children: [
            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        _colorEstado.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(pedido.estadoLabel,
                  style: TextStyle(
                      color:      _colorEstado,
                      fontWeight: FontWeight.bold,
                      fontSize:   12)),
            ),
            const SizedBox(width: 8),

            // Badge tipo (reserva / entrega)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: pedido.esReserva
                    ? AppColores.accent.withOpacity(0.10)
                    : AppColores.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(pedido.tipoLabel,
                  style: TextStyle(
                      color: pedido.esReserva
                          ? AppColores.accent
                          : AppColores.primary,
                      fontWeight: FontWeight.w600,
                      fontSize:   11)),
            ),

            const Spacer(),
            Text(_formatFecha(pedido.creadoEn),
                style: const TextStyle(
                    fontSize: 12,
                    color:    AppColores.textSecond)),
          ]),
          const SizedBox(height: 12),

          // ── Items ──────────────────────────────────────
          ...pedido.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.circle,
                  size: 6, color: AppColores.textSecond),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${item['cantidad']}x ${item['nombre']}',
                style: const TextStyle(
                    color: AppColores.textPrimary),
              )),
              Text(
                '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color:      AppColores.textPrimary),
              ),
            ]),
          )),

          const Divider(height: 20),

          // ── Desglose costo envío ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Envío',
                  style: TextStyle(
                      fontSize: 13,
                      color:    AppColores.textSecond)),
              pedido.esReserva
                  // Reserva → siempre gratis
                  ? const Text('Gratis',
                      style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color:      AppColores.success))
                  // Entrega → mostrar costo_envio del backend
                  : Text(
                      '\$${pedido.costoEnvio.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color:    AppColores.textSecond)),
            ],
          ),
          const SizedBox(height: 6),

          // ── Total + método de pago ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Método de pago (oculto en reserva)
              if (!pedido.esReserva)
                Row(children: [
                  Icon(
                    pedido.tipoPago == 'transferencia'
                        ? Icons.account_balance
                        : Icons.delivery_dining,
                    size: 16, color: AppColores.textSecond,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pedido.tipoPago == 'transferencia'
                        ? 'Transferencia' : 'Contraentrega',
                    style: const TextStyle(
                        fontSize: 13,
                        color:    AppColores.textSecond),
                  ),
                ])
              else
                // En reserva mostrar empresa si existe
                Row(children: [
                  const Icon(Icons.store_outlined,
                      size: 16, color: AppColores.accent),
                  const SizedBox(width: 6),
                  Text(
                    pedido.empresaNombre ?? 'Reserva',
                    style: const TextStyle(
                        fontSize:   13,
                        color:      AppColores.accent,
                        fontWeight: FontWeight.w600),
                  ),
                ]),

              // Total
              Text(
                '\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.primary),
              ),
            ],
          ),

          // ── Vendedor asignado ──────────────────────────
          if (pedido.vendedorNombre != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColores.success),
              const SizedBox(width: 6),
              Text('Vendedor: ${pedido.vendedorNombre}',
                  style: const TextStyle(
                      fontSize:   12,
                      color:      AppColores.success,
                      fontWeight: FontWeight.w600)),
            ]),
          ],

          // ── Botón tracking (solo entrega en camino) ────
          if (!pedido.esReserva &&
              (pedido.estado == 'en_camino' ||
               pedido.estado == 'aceptado')) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TrackingPedidoScreen(pedido: pedido),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColores.success,
                  side: const BorderSide(
                      color: AppColores.success),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon:  const Icon(Icons.delivery_dining,
                    size: 18),
                label: const Text('Ver repartidor en mapa',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatFecha(String f) {
    try {
      final dt    = DateTime.parse(f).toLocal();
      const meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May',
                     'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov',
                     'Dic'];
      return '${dt.day} ${meses[dt.month]}, '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return f;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  SIN PEDIDOS
// ══════════════════════════════════════════════════════════
class _SinPedidos extends StatelessWidget {
  const _SinPedidos();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('📦', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text('No tienes pedidos aún',
            style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary)),
        SizedBox(height: 8),
        Text('Ve a Productos y haz tu primer pedido.',
            style: TextStyle(color: AppColores.textSecond)),
      ],
    ),
  );
}