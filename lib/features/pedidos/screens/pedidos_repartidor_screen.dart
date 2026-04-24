import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/services/websocket_service.dart';
import '../models/pedido_models.dart';
import '../providers/pedidos_providers.dart';
import '../widgets/pedido_card.dart';
import 'mapa_entrega_screen.dart';

class PedidosRepartidorScreen extends ConsumerWidget {
  const PedidosRepartidorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponiblesAsync = ref.watch(pedidosRepartidorProvider);
    final activoAsync      = ref.watch(pedidoActivoRepartidorProvider);
    final wsEstado         = WebSocketService().estado;

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Pedidos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Indicador WS
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              wsEstado == WsEstado.conectado
                  ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: wsEstado == WsEstado.conectado
                  ? Colors.greenAccent : Colors.white54,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(pedidosRepartidorProvider.notifier).recargar();
              ref.read(pedidoActivoRepartidorProvider.notifier).recargar();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(pedidosRepartidorProvider.notifier).recargar();
          ref.read(pedidoActivoRepartidorProvider.notifier).recargar();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // Pedido activo
            activoAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (activo) => activo == null
                  ? const SizedBox.shrink()
                  : Column(children: [
                      _SecLabel('MI PEDIDO ACTIVO'),
                      const SizedBox(height: 8),
                      _CardPedidoActivo(
                        pedido: activo,
                        onVerMapa: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MapaEntregaScreen(pedido: activo),
                          ),
                        ),
                        onActualizar: () {
                          ref.read(pedidoActivoRepartidorProvider
                              .notifier).recargar();
                          ref.read(pedidosRepartidorProvider
                              .notifier).recargar();
                        },
                      ),
                      const SizedBox(height: 20),
                    ]),
            ),

            // Disponibles
            _SecLabel('PEDIDOS DISPONIBLES'),
            const SizedBox(height: 8),
            disponiblesAsync.when(
              loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Column(children: [
                const Text('⚠️', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                const Text('Error al cargar pedidos'),
                TextButton(
                  onPressed: () => ref.read(
                      pedidosRepartidorProvider.notifier).recargar(),
                  child: const Text('Reintentar'),
                ),
              ])),
              data: (pedidos) => pedidos.isEmpty
                  ? const _SinPedidos()
                  : Column(
                      children: pedidos.map((p) =>
                        Consumer(builder: (ctx, ref2, _) {
                          final accion =
                              ref2.watch(accionRepartidorProvider);
                          ref2.listen<AccionPedidoState>(
                              accionRepartidorProvider, (_, next) {
                            if (next.exitoso) {
                              ref.read(pedidosRepartidorProvider
                                  .notifier).recargar();
                              ref.read(pedidoActivoRepartidorProvider
                                  .notifier).recargar();
                              ref2.read(accionRepartidorProvider
                                  .notifier).resetear();
                            }
                            if (next.error != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(next.error!),
                                backgroundColor: AppColores.danger,
                              ));
                              ref2.read(accionRepartidorProvider
                                  .notifier).resetear();
                            }
                          });
                          return PedidoCard(
                            pedido:   p,
                            cargando: accion.cargando,
                            onAceptar: () => _confirmarAceptar(
                                context, ref2, p),
                          );
                        }),
                      ).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarAceptar(
      BuildContext context, WidgetRef ref, PedidoBase pedido) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Aceptar pedido'),
        content: Text(
            'Pedido de ${pedido.clienteNombre} '
            'por \$${pedido.total.toStringAsFixed(2)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(accionRepartidorProvider.notifier)
                  .aceptar(pedido.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

// ── Card pedido activo ─────────────────────────────────────
class _CardPedidoActivo extends ConsumerWidget {
  final PedidoBase   pedido;
  final VoidCallback onVerMapa;
  final VoidCallback onActualizar;

  const _CardPedidoActivo({
    required this.pedido,
    required this.onVerMapa,
    required this.onActualizar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColores.primary,
                 AppColores.primary.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('📦', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pedido en curso',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              Text(pedido.clienteNombre,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          )),
          Text('\$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),

        // Dirección
        if (pedido.direccionEntrega != null)
          Row(children: [
            const Icon(Icons.location_on,
                color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
                pedido.direccionEntrega!,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12))),
          ]),

        const SizedBox(height: 14),
        Row(children: [
          // Ver mapa
          Expanded(child: OutlinedButton.icon(
            onPressed: pedido.tieneCoordenadas ? onVerMapa : null,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54)),
            icon:  const Icon(Icons.map_outlined, size: 16),
            label: const Text('Ver ruta'),
          )),
          const SizedBox(width: 10),
          // Cambiar estado
          Expanded(child: Consumer(
            builder: (ctx, ref2, _) {
              final accion = ref2.watch(accionRepartidorProvider);
              return ElevatedButton.icon(
                onPressed: accion.cargando ? null :
                    () => ref2
                        .read(accionRepartidorProvider.notifier)
                        .actualizarEstado(
                          pedido.id,
                          pedido.estado == 'aceptado'
                              ? 'en_camino' : 'entregado',
                        ).then((_) => onActualizar()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pedido.estado == 'aceptado'
                      ? AppColores.warning : AppColores.success,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(pedido.estado == 'aceptado'
                    ? Icons.directions_bike : Icons.check_circle,
                    size: 16),
                label: Text(pedido.estado == 'aceptado'
                    ? 'En camino' : 'Entregado'),
              );
            },
          )),
        ]),
      ],
    ),
  );
}

class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);
  @override
  Widget build(BuildContext context) => Text(texto,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: AppColores.textSecond, letterSpacing: 1.0));
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: Column(children: [
      Text('📭', style: TextStyle(fontSize: 52)),
      SizedBox(height: 16),
      Text('Sin pedidos disponibles',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColores.textPrimary)),
      SizedBox(height: 8),
      Text('Cuando llegue un pedido aparecerá aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColores.textSecond)),
    ])),
  );
}