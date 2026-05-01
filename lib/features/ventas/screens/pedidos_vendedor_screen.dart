import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/services/websocket_service.dart';
import '../providers/pedidos_vendedor_provider.dart';
import '../providers/ruta_activa_provider.dart';

class PedidosVendedorScreen extends ConsumerWidget {
  const PedidosVendedorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponiblesAsync = ref.watch(reservasDisponiblesProvider);
    final activasAsync     = ref.watch(reservasActivasProvider);
    final wsService        = WebSocketService();

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reservas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: wsService.estado == WsEstado.conectado
                  ? 'Tiempo real activo'
                  : 'Reconectando...',
              child: Icon(
                wsService.estado == WsEstado.conectado
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: wsService.estado == WsEstado.conectado
                    ? Colors.greenAccent
                    : Colors.white54,
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () {
              ref.read(reservasDisponiblesProvider.notifier).recargar();
              ref.read(reservasActivasProvider.notifier).recargar();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(reservasDisponiblesProvider.notifier).recargar();
          await ref.read(reservasActivasProvider.notifier).recargar();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Reservas activas (aceptadas) ────────────────────
            activasAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child:   CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _ErrorVista(
                mensaje:      parsearErrorDio(e),
                onReintentar: () =>
                    ref.read(reservasActivasProvider.notifier).recargar(),
              ),
              data: (activas) {
                if (activas.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SecLabel(
                        'MIS RESERVAS ACEPTADAS (${activas.length})'),
                    const SizedBox(height: 8),
                    ...activas.map(
                      (pedido) => _CardReservaActiva(
                        pedido:       pedido,
                        onActualizar: () {
                          ref
                              .read(reservasActivasProvider.notifier)
                              .recargar();
                          ref
                              .read(reservasDisponiblesProvider.notifier)
                              .recargar();
                          // ✅ PUNTO 3: también invalidar stock
                          ref.invalidate(stockRestanteProvider);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // ── Reservas disponibles (pendientes) ───────────────
            _SecLabel('RESERVAS DISPONIBLES'),
            const SizedBox(height: 8),

            disponiblesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child:   CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _ErrorVista(
                mensaje:      parsearErrorDio(e),
                onReintentar: () =>
                    ref.read(reservasDisponiblesProvider.notifier).recargar(),
              ),
              data: (reservas) => reservas.isEmpty
                  ? const _SinReservas()
                  : Column(
                      children: reservas
                          .map((p) => _CardReservaDisponible(
                                pedido:    p,
                                onAceptar: () =>
                                    _confirmarAceptar(context, ref, p),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo confirmar aceptar ─────────────────────────
  void _confirmarAceptar(
    BuildContext context,
    WidgetRef ref,
    PedidoVendedor pedido,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Aceptar reserva'),
        content: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppColores.textPrimary, fontSize: 14),
                children: [
                  const TextSpan(text: '¿Aceptar la reserva de '),
                  TextSpan(
                    text:  pedido.clienteNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                      text:
                          ' por \$${pedido.total.toStringAsFixed(2)}?'),
                ],
              ),
            ),
            if (pedido.empresaNombre != null) ...[
              const SizedBox(height: 8),
              _InfoChip(
                icono: Icons.store_outlined,
                texto: pedido.empresaNombre!,
                color: AppColores.accent,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColores.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColores.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se verificará tu stock antes de aceptar. '
                      'Si no tienes suficientes productos, '
                      'se te indicará cuáles faltan.',
                      style: TextStyle(
                          fontSize: 12, color: AppColores.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:     const Text('Cancelar'),
          ),
          Consumer(
            builder: (ctx, ref2, _) {
              final state = ref2.watch(aceptarReservaProvider);

              ref2.listen<AceptarReservaState>(aceptarReservaProvider,
                  (_, next) {
                if (next.exitoso) {
                  Navigator.pop(ctx);
                  ref.invalidate(reservasDisponiblesProvider);
                  ref.invalidate(reservasActivasProvider);
                  ref.invalidate(stockRestanteProvider);
                  ref2.read(aceptarReservaProvider.notifier).resetear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:         Text('✅ Reserva aceptada'),
                      backgroundColor: AppColores.success,
                    ),
                  );
                }
                if (next.error != null) {
                  Navigator.pop(ctx);
                  // ✅ PUNTO 1: muestra el mensaje real del backend
                  _mostrarErrorDetallado(context, next.error!);
                  ref2.read(aceptarReservaProvider.notifier).resetear();
                }
              });

              return ElevatedButton(
                onPressed: state.cargando
                    ? null
                    : () => ref2
                        .read(aceptarReservaProvider.notifier)
                        .aceptar(pedido.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: state.cargando
                    ? const SizedBox(
                        width:  18,
                        height: 18,
                        child:  CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Aceptar'),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo con el error detallado del backend
  /// en lugar de un simple SnackBar, para que el vendedor entienda qué pasó.
  static void _mostrarErrorDetallado(BuildContext context, String mensaje) {
    // Detectar tipo de error para mostrar ícono y título apropiados
    final esStockInsuficiente = mensaje.toLowerCase().contains('stock') ||
        mensaje.toLowerCase().contains('disponible') ||
        mensaje.toLowerCase().contains('solicitado');
    final esEmpresaVisitada =
        mensaje.toLowerCase().contains('visitaste') ||
        mensaje.toLowerCase().contains('visitada');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(
            esEmpresaVisitada ? '🏢' : esStockInsuficiente ? '📦' : '⚠️',
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              esEmpresaVisitada
                  ? 'Empresa ya visitada'
                  : esStockInsuficiente
                      ? 'Stock insuficiente'
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
              esEmpresaVisitada
                  ? 'Ya marcaste esta empresa como visitada hoy. '
                    'No puedes aceptar más reservas de ella.'
                  : esStockInsuficiente
                      ? 'No tienes suficiente stock para cubrir esta reserva:'
                      : mensaje,
              style: const TextStyle(
                  color: AppColores.textPrimary, fontSize: 14),
            ),
            // Si es stock, mostrar los detalles de cada producto
            if (esStockInsuficiente) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppColores.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColores.danger.withOpacity(0.2)),
                ),
                child: Text(
                  // El backend devuelve los productos que faltan separados por \n
                  mensaje.replaceFirst(
                      RegExp(r'^Stock insuficiente:\n?'), ''),
                  style: const TextStyle(
                      fontSize: 12,
                      color:    AppColores.danger,
                      height:   1.5),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Agrega más stock o acepta una reserva más pequeña.',
                style: TextStyle(
                    fontSize: 12, color: AppColores.textSecond),
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
//  CARD — RESERVA DISPONIBLE
// ══════════════════════════════════════════════════════════
class _CardReservaDisponible extends StatelessWidget {
  final PedidoVendedor pedido;
  final VoidCallback   onAceptar;
  const _CardReservaDisponible(
      {required this.pedido, required this.onAceptar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset:     const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColores.accent.withOpacity(0.12),
              child: Text(
                pedido.clienteNombre.isNotEmpty
                    ? pedido.clienteNombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color:      AppColores.accent,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pedido.clienteNombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   15,
                          color:      AppColores.textPrimary)),
                  if (pedido.empresaNombre != null)
                    Text(pedido.empresaNombre!,
                        style: const TextStyle(
                            fontSize:   12,
                            color:      AppColores.accent,
                            fontWeight: FontWeight.w600)),
                  Text(
                    _formatFecha(DateTime.parse(pedido.creadoEn)),
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond),
                  ),
                ],
              ),
            ),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.primary)),
          ]),
          const SizedBox(height: 12),
          ...pedido.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.circle,
                      size: 5, color: AppColores.textSecond),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${item['cantidad']}x ${item['nombre']}',
                        style: const TextStyle(
                            fontSize: 13,
                            color:    AppColores.textPrimary)),
                  ),
                  Text(
                    '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppColores.textPrimary),
                  ),
                ]),
              )),
          const SizedBox(height: 10),
          const Row(children: [
            _InfoChip(
                icono: Icons.bookmark_outlined,
                texto: 'Reserva',
                color: AppColores.accent),
            SizedBox(width: 8),
            _InfoChip(
                icono: Icons.payments_outlined,
                texto: 'Contado',
                color: AppColores.success),
          ]),
          if (pedido.notas != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:        Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.notes,
                    size: 14, color: AppColores.textSecond),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(pedido.notas!,
                      style: const TextStyle(
                          fontSize: 12,
                          color:    AppColores.textSecond)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width:  double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onAceptar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon:  const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Aceptar reserva',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD — RESERVA ACTIVA
// ══════════════════════════════════════════════════════════
class _CardReservaActiva extends ConsumerWidget {
  final PedidoVendedor pedido;
  final VoidCallback   onActualizar;

  const _CardReservaActiva(
      {required this.pedido, required this.onActualizar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.accent,
            AppColores.accent.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      AppColores.accent.withOpacity(0.3),
              blurRadius: 12,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📦', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reserva aceptada — pendiente de entrega',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  Text(pedido.clienteNombre,
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   16,
                          fontWeight: FontWeight.bold)),
                  if (pedido.empresaNombre != null)
                    Text(pedido.empresaNombre!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),

          // Productos
          ...pedido.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.circle,
                      size: 5, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${item['cantidad']}x ${item['nombre']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                ]),
              )),

          const SizedBox(height: 10),

          // Chip de estado
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('📦 En curso',
                style: TextStyle(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          ),

          if (pedido.notas != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.notes, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(pedido.notas!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ),
            ]),
          ],
          const SizedBox(height: 14),

          Consumer(builder: (ctx, ref2, _) {
            final state = ref2.watch(aceptarReservaProvider);

            // Escuchar resultado
            ref2.listen<AceptarReservaState>(aceptarReservaProvider,
                (_, next) {
              if (next.exitoso) {
                onActualizar();
                ref2.read(aceptarReservaProvider.notifier).resetear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:         Text('✅ Hecho'),
                    backgroundColor: AppColores.success,
                  ),
                );
              }
              if (next.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    // ✅ PUNTO 1: muestra error real
                    content:         Text(next.error!),
                    backgroundColor: AppColores.danger,
                  ),
                );
                ref2.read(aceptarReservaProvider.notifier).resetear();
              }
            });

            return Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: state.cargando
                      ? null
                      : () => _confirmarEstado(ctx, ref2, 'entregado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon:  const Icon(Icons.check_circle, size: 15),
                  label: const Text(
                    'Entregado',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.cargando
                      ? null
                      : () => _confirmarEstado(ctx, ref2, 'cancelado'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon:  const Icon(Icons.lock_open_rounded, size: 15),
                  label: const Text(
                    'Liberar',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  void _confirmarEstado(
      BuildContext context, WidgetRef ref, String nuevoEstado) {
    final esCancelar = nuevoEstado == 'cancelado';
    final color      = esCancelar ? AppColores.warning : AppColores.success;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(esCancelar ? '🔓' : '✅',
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(esCancelar
              ? 'Cancelar y liberar'
              : 'Marcar como entregado'),
        ]),
        content: Text(
          esCancelar
              ? 'Se cancelará la reserva de ${pedido.clienteNombre} '
                'y los productos volverán a tu stock disponible.'
              : '¿Confirmas que entregaste la reserva de '
                '${pedido.clienteNombre}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:     const Text('Volver')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // ✅ actualizarEstado ya redirige cancelado → liberar-reserva
              await ref
                  .read(aceptarReservaProvider.notifier)
                  .actualizarEstado(pedido.id, nuevoEstado);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text(esCancelar ? 'Sí, liberar' : 'Confirmar'),
          ),
        ],
      ),
    );
  }
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

class _InfoChip extends StatelessWidget {
  final IconData icono;
  final String   texto;
  final Color    color;
  const _InfoChip(
      {required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(
                  fontSize:   11,
                  color:      color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SinReservas extends StatelessWidget {
  const _SinReservas();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Text('📭', style: TextStyle(fontSize: 52)),
              SizedBox(height: 16),
              Text('Sin reservas disponibles',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      AppColores.textPrimary)),
              SizedBox(height: 8),
              Text(
                'Cuando un cliente haga una reserva\nde tu ruta aparecerá aquí.',
                textAlign: TextAlign.center,
                style:     TextStyle(color: AppColores.textSecond),
              ),
            ],
          ),
        ),
      );
}

class _ErrorVista extends StatelessWidget {
  final String       mensaje;
  final VoidCallback onReintentar;
  const _ErrorVista(
      {required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColores.textSecond)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onReintentar,
                child:     const Text('Reintentar')),
          ],
        ),
      );
}

String _formatFecha(DateTime fecha) {
  final diff = DateTime.now().difference(fecha);
  if (diff.inMinutes < 1)  return 'Justo ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24)   return 'Hace ${diff.inHours} h';
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';
}