import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colores.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';
import '../providers/pedidos_vendedor_provider.dart';
import '../providers/ruta_activa_provider.dart';
import '../shell/shell_providers.dart';
import 'historial_screen.dart';
import '../../../shared/models/venta_model.dart';

class DashboardScreen extends ConsumerWidget {
  /// [sesionId] si viene de finalizar ruta, muestra métricas del día.
  /// Si es null, solo muestra acceso rápido al historial.
  final String? sesionId;
  final VoidCallback? onVolverAlMapa;
  const DashboardScreen({super.key, this.sesionId, this.onVolverAlMapa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = _fmtHoy();
    final rango = RangoFechas(desde: hoy, hasta: hoy);

    final ventasAsync = ref.watch(historialPorFechasProvider(rango));
    final resumenAsync = ref.watch(resumenPorFechasProvider(rango));
    final pedidosAsync = ref.watch(pedidosHistorialProvider(rango));

    // Cuando viene de completar ruta, tiene su propio AppBar
    // con botón de volver al mapa
    final esResumenRuta = sesionId != null;

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: esResumenRuta
          ? AppBar(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              title: const Text(
                'Resumen del día',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                // Volver al mapa (nueva ruta)
                TextButton.icon(
                  onPressed: () {
                    if (onVolverAlMapa != null) {
                      onVolverAlMapa!();
                    } else {
                      // Fallback: intentar cambiar tab
                      ref.read(tabActivoProvider.notifier).state = 0;
                    }
                  },
                  icon: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Ir al mapa',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : null, // Cuando es tab normal, sin AppBar propio
      body: SafeArea(
        child: Column(
          children: [
            // Header solo cuando NO es resumen de ruta
            // (cuando es resumen ya tiene AppBar)
            if (!esResumenRuta) _Header(),

            // ── Contenido scrolleable ───────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(resumenPorFechasProvider(rango));
                  ref.invalidate(historialPorFechasProvider(rango));
                  ref.invalidate(pedidosHistorialProvider(rango));
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // Banner especial si viene de completar ruta
                    if (esResumenRuta) ...[
                      _BannerRutaCompletada(),
                      const SizedBox(height: 16),
                    ],

                    // Resumen métricas
                    resumenAsync.when(
                      loading: () => const _SkeletonResumen(),
                      error: (e, st) {
                        debugPrint('❌ Error resumen: $e');
                        return const SizedBox.shrink();
                      },
                      data: (r) {
                        debugPrint(
                          '✅ Resumen: ventas=${r.totalVentas} vendido=${r.totalVendido}',
                        );
                        return _BloqueMetricas(resumen: r);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Acciones rápidas
                    _AccionesRapidas(
                      onVerHistorial: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistorialScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Últimas actividades
                    const _SecLabel('ÚLTIMAS ACTIVIDADES DE HOY'),
                    const SizedBox(height: 8),

                    // Mezcla ventas + pedidos
                    _ListaActividades(
                      ventasAsync: ventasAsync,
                      pedidosAsync: pedidosAsync,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtHoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }
}

// ── Header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const meses = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final fecha =
        '${dias[now.weekday % 7]} ${now.day} '
        '${meses[now.month]} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppColores.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del día',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fecha,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bloque métricas ───────────────────────────────────────
class _BloqueMetricas extends StatelessWidget {
  final ResumenDia resumen;
  const _BloqueMetricas({required this.resumen});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Card dinero en mano
      _CardDestacada(
        icono: Icons.account_balance_wallet_rounded,
        titulo: 'Dinero en mano',
        valor: '\$${resumen.dineroEnMano.toStringAsFixed(2)}',
        subtitulo: 'Contado + cobros + pedidos',
        color: AppColores.primary,
      ),
      const SizedBox(height: 12),

      // Grid 2x2
      Row(
        children: [
          Expanded(
            child: _MiniCard(
              icono: Icons.trending_up_rounded,
              titulo: 'Total vendido',
              valor: '\$${resumen.totalVendido.toStringAsFixed(2)}',
              color: AppColores.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniCard(
              icono: Icons.receipt_long_outlined,
              titulo: 'Ventas a fiado',
              valor: '\$${resumen.totalFiado.toStringAsFixed(2)}',
              color: AppColores.warning,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MiniCard(
              icono: Icons.handshake_outlined,
              titulo: 'Cobros',
              valor: '\$${resumen.totalCobrado.toStringAsFixed(2)}',
              color: AppColores.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniCard(
              icono: Icons.shopping_bag_outlined,
              titulo: 'Pedidos',
              valor: '\$${resumen.totalPedidosContado.toStringAsFixed(2)}',
              color: AppColores.primary,
            ),
          ),
        ],
      ),
    ],
  );
}

class _CardDestacada extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final String subtitulo;
  final Color color;

  const _CardDestacada({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icono, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                subtitulo,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _MiniCard({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColores.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: AppColores.textSecond),
        ),
      ],
    ),
  );
}

// ── Acciones rápidas ──────────────────────────────────────
class _AccionesRapidas extends StatelessWidget {
  final VoidCallback onVerHistorial;
  const _AccionesRapidas({required this.onVerHistorial});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _AccionBtn(
          icono: Icons.history_rounded,
          label: 'Ver historial completo',
          color: AppColores.accent,
          onTap: onVerHistorial,
        ),
      ),
    ],
  );
}

class _AccionBtn extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccionBtn({
    required this.icono,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Lista actividades (ventas + pedidos mezclados) ────────
class _ListaActividades extends StatelessWidget {
  final AsyncValue<List<VentaModel>> ventasAsync;
  final AsyncValue<List<PedidoVendedor>> pedidosAsync;

  const _ListaActividades({
    required this.ventasAsync,
    required this.pedidosAsync,
  });

  @override
  Widget build(BuildContext context) {
    final ventas = ventasAsync.asData?.value ?? [];
    final pedidos = pedidosAsync.asData?.value ?? [];

    if (ventasAsync.isLoading || pedidosAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Mezclar y ordenar por fecha desc
    final items = <_ItemActividad>[];
    for (final v in ventas) {
      items.add(
        _ItemActividad(
          fecha: DateTime.tryParse(v.fechaVenta) ?? DateTime.now(),
          venta: v,
          pedido: null,
        ),
      );
    }
    for (final p in pedidos) {
      items.add(
        _ItemActividad(
          fecha:
              DateTime.tryParse(p.aceptadoEn ?? p.creadoEn) ?? DateTime.now(),
          venta: null,
          pedido: p,
        ),
      );
    }
    items.sort((a, b) => b.fecha.compareTo(a.fecha));

    final ultimos = items.take(8).toList();

    if (ultimos.isEmpty) {
      return _EmptyActividades();
    }

    return Column(
      children: ultimos
          .map(
            (item) => item.venta != null
                ? _VentaItem(venta: item.venta!)
                : _PedidoItem(pedido: item.pedido!),
          )
          .toList(),
    );
  }
}

class _ItemActividad {
  final DateTime fecha;
  final VentaModel? venta;
  final PedidoVendedor? pedido;
  const _ItemActividad({
    required this.fecha,
    required this.venta,
    required this.pedido,
  });
}

class _EmptyActividades extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: AppColores.textSecond.withOpacity(0.4),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sin actividad registrada hoy',
          style: TextStyle(color: AppColores.textSecond, fontSize: 14),
        ),
      ],
    ),
  );
}

// ── Item venta ────────────────────────────────────────────
class _VentaItem extends StatelessWidget {
  final VentaModel venta;
  const _VentaItem({required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito = venta.tipo == 'credito';
    final color = esCredito ? AppColores.warning : AppColores.success;
    final icono = esCredito
        ? Icons.receipt_long_outlined
        : Icons.payments_outlined;

    return _ActivityCard(
      icono: icono,
      color: color,
      titulo: venta.cliente ?? 'Venta al contado',
      subtitulo: _fmt(venta.fechaVenta),
      valor: '\$${venta.montoTotal.toStringAsFixed(2)}',
      badge: esCredito ? 'FIADO' : 'CONTADO',
    );
  }

  String _fmt(String f) {
    try {
      final dt = DateTime.parse(f).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return f;
    }
  }
}

// ── Item pedido ───────────────────────────────────────────
class _PedidoItem extends StatelessWidget {
  final PedidoVendedor pedido;
  const _PedidoItem({required this.pedido});

  @override
  Widget build(BuildContext context) => _ActivityCard(
    icono: Icons.delivery_dining_rounded,
    color: AppColores.primary,
    titulo: pedido.clienteNombre,
    subtitulo: _fmt(pedido.aceptadoEn ?? pedido.creadoEn),
    valor: '\$${pedido.total.toStringAsFixed(2)}',
    badge: 'PEDIDO',
  );

  String _fmt(String f) {
    try {
      final dt = DateTime.parse(f).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return f;
    }
  }
}

// ── Card actividad reutilizable ───────────────────────────
class _ActivityCard extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final String valor;
  final String badge;

  const _ActivityCard({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColores.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColores.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColores.textSecond,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Skeleton ──────────────────────────────────────────────
class _SkeletonResumen extends StatelessWidget {
  const _SkeletonResumen();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _SkeletonBox(height: 88),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 80)),
          const SizedBox(width: 12),
          Expanded(child: _SkeletonBox(height: 80)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 80)),
          const SizedBox(width: 12),
          Expanded(child: _SkeletonBox(height: 80)),
        ],
      ),
    ],
  );
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);
  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: AppColores.textSecond,
      letterSpacing: 1.1,
    ),
  );
}

// ── Banner ruta completada ────────────────────────────────
class _BannerRutaCompletada extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColores.success, AppColores.success.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Ruta completada!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Aquí está el resumen de tu día.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
