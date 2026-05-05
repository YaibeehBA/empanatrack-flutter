import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colores.dart';
import '../../../core/services/websocket_service.dart';
import '../models/pedido_models.dart';
import '../providers/pedidos_providers.dart';
import '../widgets/pedido_card.dart';
import 'mapa_entrega_screen.dart';

class PedidosRepartidorScreen extends ConsumerWidget {
  const PedidosRepartidorScreen({super.key});

  void _confirmarCancelar(BuildContext context, WidgetRef ref, String pedidoId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Text('⚠️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Cancelar pedido'),
        ]),
        content: const Text('¿Estás seguro de cancelar este pedido? El cliente será notificado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          Consumer(
            builder: (ctx, ref2, _) {
              final state = ref2.watch(cancelarPedidoDisponibleProvider);

              ref2.listen<CancelarPedidoState>(
                  cancelarPedidoDisponibleProvider, (_, next) {
                if (next.exitoso) {
                  Navigator.pop(ctx);
                  ref.invalidate(pedidosRepartidorProvider);
                  ref.invalidate(pedidoActivoRepartidorProvider);
                  ref2.read(cancelarPedidoDisponibleProvider.notifier).resetear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Pedido cancelado'),
                      backgroundColor: AppColores.warning,
                    ),
                  );
                }
                if (next.error != null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(next.error!),
                      backgroundColor: AppColores.danger,
                    ),
                  );
                  ref2.read(cancelarPedidoDisponibleProvider.notifier).resetear();
                }
              });

              return ElevatedButton(
                onPressed: state.cargando
                    ? null
                    : () => ref2
                        .read(cancelarPedidoDisponibleProvider.notifier)
                        .cancelar(pedidoId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: state.cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Sí, cancelar'),
              );
            },
          ),
        ],
      ),
    );
  }

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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              wsEstado == WsEstado.conectado
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              color: wsEstado == WsEstado.conectado
                  ? Colors.greenAccent
                  : Colors.white54,
              size: 20,
            ),
          ),
          IconButton(
            icon:      const Icon(Icons.refresh),
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

            // ── Pedido activo ───────────────────────────
            activoAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (activo) => activo == null
                  ? const SizedBox.shrink()
                  : Column(children: [
                      _SecLabel('MI PEDIDO ACTIVO'),
                      const SizedBox(height: 8),
                      _CardPedidoActivo(
                        pedido:   activo,
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
                        onCancelar: _confirmarCancelar, // 👈 AQUÍ
                      ),
                      const SizedBox(height: 20),
                    ]),
            ),

            // ── Pedidos disponibles ─────────────────────
            _SecLabel('PEDIDOS DISPONIBLES'),
            const SizedBox(height: 8),

            disponiblesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child:   CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Column(children: [
                const Text('⚠️', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                const Text('Error al cargar pedidos'),
                TextButton(
                  onPressed: () => ref
                      .read(pedidosRepartidorProvider.notifier)
                      .recargar(),
                  child: const Text('Reintentar'),
                ),
              ])),
              data: (pedidos) => pedidos.isEmpty
                  ? const _SinPedidos()
                  // ✅ UN solo Consumer fuera del loop — el listen
                  // se registra una sola vez sin importar cuántos
                  // pedidos haya en la lista
                  : Consumer(builder: (ctx, ref2, _) {
                      final accion = ref2.watch(accionRepartidorProvider);

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
                          _mostrarErrorAceptar(ctx, next.error!);
                          ref2.read(accionRepartidorProvider
                              .notifier).resetear();
                        }
                      });

                      return Column(
                        children: pedidos.map((p) => PedidoCard(
                          pedido:   p,
                          cargando: accion.cargando,
                          onAceptar: () => _confirmarAceptar(
                              context, ref2, p),
                         onCancelar: () => _confirmarCancelar(context, ref2, p.id),
                        )).toList(),
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo confirmar aceptar ─────────────────────────
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
          'por \$${pedido.total.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:     const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(accionRepartidorProvider.notifier)
                  .aceptar(pedido.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ── Diálogo de error amigable ─────────────────────────
  static void _mostrarErrorAceptar(BuildContext context, String mensaje) {
    final esPedidoActivo = mensaje.contains('pedido en curso') ||
        mensaje.contains('pedido activo');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(esPedidoActivo ? '🛵' : '⚠️',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              esPedidoActivo
                  ? 'Pedido en curso'
                  : 'No se pudo aceptar',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje,
              style: const TextStyle(
                  fontSize: 14,
                  color:    AppColores.textPrimary,
                  height:   1.5),
            ),
            if (esPedidoActivo) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        AppColores.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColores.warning.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColores.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ve a "Mi pedido activo" y márcalo '
                      'como entregado para poder aceptar uno nuevo.',
                      style: TextStyle(
                          fontSize: 12,
                          color:    AppColores.warning,
                          height:   1.4),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD — PEDIDO ACTIVO
// ══════════════════════════════════════════════════════════
class _CardPedidoActivo extends ConsumerWidget {
  final PedidoBase   pedido;
  final VoidCallback onVerMapa;
  final VoidCallback onActualizar;
  final void Function(BuildContext, WidgetRef, String) onCancelar; // 👈 AÑADIDO

  const _CardPedidoActivo({
    required this.pedido,
    required this.onVerMapa,
    required this.onActualizar,
    required this.onCancelar, // 👈 AÑADIDO
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColores.primary,
          AppColores.primary.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color:      AppColores.primary.withOpacity(0.3),
            blurRadius: 12,
            offset:     const Offset(0, 4)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('🛵', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pedido en curso',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              Text(pedido.clienteNombre,
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.bold)),
            ],
          )),
          Text('\$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),

        if (pedido.direccionEntrega != null)
          Row(children: [
            const Icon(Icons.location_on,
                color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              pedido.direccionEntrega!,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12),
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
            )),
          ]),

        const SizedBox(height: 6),

        // Badge estado
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            pedido.estado == 'aceptado'
                ? '📦 Aceptado'
                : '🚴 En camino',
            style: const TextStyle(
                color:      Colors.white,
                fontSize:   11,
                fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 14),

        // Botón principal (en camino / entregado)
        Row(children: [
          // Ver mapa
          Expanded(child: OutlinedButton.icon(
            onPressed: pedido.tieneCoordenadas ? onVerMapa : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon:  const Icon(Icons.map_outlined, size: 16),
            label: const Text('Ver ruta'),
          )),
          const SizedBox(width: 10),

          // Cambiar estado — usa estadoRepartidorProvider (separado)
          Expanded(child: Consumer(
            builder: (ctx, ref2, _) {
              final accion = ref2.watch(estadoRepartidorProvider);

              ref2.listen<AccionPedidoState>(
                  estadoRepartidorProvider, (_, next) {
                if (next.exitoso) {
                  onActualizar();
                  ref2.read(estadoRepartidorProvider
                      .notifier).resetear();
                }
                if (next.error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content:         Text(next.error!),
                    backgroundColor: AppColores.danger,
                  ));
                  ref2.read(estadoRepartidorProvider
                      .notifier).resetear();
                }
              });

              final siguienteEstado = pedido.estado == 'aceptado'
                  ? 'en_camino' : 'entregado';
              final esEntregado = siguienteEstado == 'entregado';

              return ElevatedButton.icon(
                onPressed: accion.cargando
                    ? null
                    : () => ref2
                        .read(estadoRepartidorProvider.notifier)
                        .actualizarEstado(pedido.id, siguienteEstado),
                style: ElevatedButton.styleFrom(
                  backgroundColor: esEntregado
                      ? AppColores.success : AppColores.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: accion.cargando
                    ? const SizedBox(
                        width:  14, height: 14,
                        child:  CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        esEntregado
                            ? Icons.check_circle_rounded
                            : Icons.directions_bike_rounded,
                        size: 16),
                label: Text(
                  esEntregado ? 'Entregado' : 'En camino',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          )),
        ]),

        const SizedBox(height: 8),

        // ── Botón cancelar ────────────────────────────
        Consumer(builder: (ctx, ref2, _) {
          final accion = ref2.watch(estadoRepartidorProvider);
          return SizedBox(
            width:  double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: accion.cargando
                  ? null
                  : () => onCancelar(ctx, ref2, pedido.id), // 👈 MODIFICADO
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white60,
                side: const BorderSide(
                    color: Colors.white30, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon:  const Icon(Icons.cancel_outlined, size: 15),
              label: const Text('Cancelar pedido',
                  style: TextStyle(fontSize: 12)),
            ),
          );
        }),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════
class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);
  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.bold,
            color:         AppColores.textSecond,
            letterSpacing: 1.0),
      );
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(children: [
            Text('📭', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('Sin pedidos disponibles',
                style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary)),
            SizedBox(height: 8),
            Text(
              'Cuando llegue un pedido aparecerá aquí.',
              textAlign: TextAlign.center,
              style:     TextStyle(color: AppColores.textSecond),
            ),
          ]),
        ),
      );
}