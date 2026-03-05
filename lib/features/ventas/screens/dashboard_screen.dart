import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';
import '../../../shared/widgets/venta_item.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion  = ref.watch(authProvider).sesion;
    final periodo = ref.watch(periodoSeleccionadoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        elevation:                 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${sesion?.nombre ?? ''} 👋',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _fechaHoy(),
              style: const TextStyle(
                fontSize: 12, color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:      const Icon(Icons.logout),
            tooltip:   'Cerrar sesión',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(resumenDiaProvider(periodo));
          ref.invalidate(historialVentasProvider(periodo));
        },
        child: CustomScrollView(
          slivers: [

            // ── Selector de periodo ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SelectorPeriodo(
                  seleccionado: periodo,
                  onChange: (p) =>
                      ref.read(periodoSeleccionadoProvider.notifier).state = p,
                ),
              ),
            ),

            // ── Bloque de resumen ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _BloqueResumen(periodo: periodo),
              ),
            ),

            // ── Título últimas ventas ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _labelHistorial(periodo),
                      style: const TextStyle(
                        fontSize:      12,
                        fontWeight:    FontWeight.bold,
                        color:         AppColores.textSecond,
                        letterSpacing: 1.1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.invalidate(historialVentasProvider(periodo)),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh,
                              size: 14, color: AppColores.accent),
                          SizedBox(width: 4),
                          Text(
                            'Actualizar',
                            style: TextStyle(
                              fontSize: 12, color: AppColores.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Lista resumida (máx 5 ventas) ────────────
            _SliverListaVentasResumida(periodo: periodo),

            // Espacio para el FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  String _fechaHoy() {
    final now    = DateTime.now();
    const meses  = ['','Ene','Feb','Mar','Abr','May','Jun',
                    'Jul','Ago','Sep','Oct','Nov','Dic'];
    const dias   = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    return '${dias[now.weekday % 7]} ${now.day} '
        '${meses[now.month]} ${now.year}';
  }

  static String _labelHistorial(String p) {
    switch (p) {
      case 'ayer':   return 'VENTAS DE AYER';
      case 'semana': return 'VENTAS DE ESTA SEMANA';
      case 'mes':    return 'VENTAS DE ESTE MES';
      default:       return 'ÚLTIMAS VENTAS DE HOY';
    }
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTOR DE PERIODO
// ══════════════════════════════════════════════════════════
class _SelectorPeriodo extends StatelessWidget {
  final String           seleccionado;
  final Function(String) onChange;
  const _SelectorPeriodo({
    required this.seleccionado, required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final ops = [
      {'v': 'hoy',    'l': 'Hoy'},
      {'v': 'ayer',   'l': 'Ayer'},
      {'v': 'semana', 'l': 'Semana'},
      {'v': 'mes',    'l': 'Mes'},
    ];
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ops.map((o) {
          final activo = seleccionado == o['v'];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(o['v']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:  const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color:        activo
                      ? AppColores.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    o['l']!,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.bold,
                      color: activo
                          ? Colors.white
                          : AppColores.textSecond,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BLOQUE DE RESUMEN
// ══════════════════════════════════════════════════════════
class _BloqueResumen extends ConsumerWidget {
  final String periodo;
  const _BloqueResumen({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(resumenDiaProvider(periodo));
    return async.when(
      loading: () => const _ResumenSkeleton(),
      error:   (e, _) => const SizedBox.shrink(),
      data: (r) => Column(
        children: [

          // ── Fila 1: Contado | Fiado ──────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  color:     AppColores.success,
                  icono:     '💵',
                  etiqueta:  'Al contado',
                  valor:     '\$${r.totalContado.toStringAsFixed(2)}',
                  subtitulo: 'Cobrado al momento',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  color:     AppColores.warning,
                  icono:     '📋',
                  etiqueta:  'Fiado',
                  valor:     '\$${r.totalFiado.toStringAsFixed(2)}',
                  subtitulo: 'Pendiente de cobro',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Fila 2: Total vendido ────────────────────
          _TotalVendidoCard(
            totalVendido: r.totalVendido,
            totalContado: r.totalContado,
            totalFiado:   r.totalFiado,
            totalVentas:  r.totalVentas,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  STAT CARD (Contado / Fiado)
// ══════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final Color  color;
  final String icono;
  final String etiqueta;
  final String valor;
  final String subtitulo;
  const _StatCard({
    required this.color,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icono, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize:   12,
                  color:      AppColores.textSecond,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(
              fontSize: 11,
              color:    AppColores.textSecond,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TOTAL VENDIDO CARD
// ══════════════════════════════════════════════════════════
class _TotalVendidoCard extends StatelessWidget {
  final double totalVendido;
  final double totalContado;
  final double totalFiado;
  final int    totalVentas;
  const _TotalVendidoCard({
    required this.totalVendido,
    required this.totalContado,
    required this.totalFiado,
    required this.totalVentas,
  });

  @override
  Widget build(BuildContext context) {
    final porcentajeContado = totalVendido > 0
        ? (totalContado / totalVendido).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Encabezado
          Row(
            children: [
              const Text(
                'TOTAL VENDIDO',
                style: TextStyle(
                  color:         AppColores.textSecond,
                  fontSize:      11,
                  letterSpacing: 1.2,
                  fontWeight:    FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColores.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalVentas '
                  '${totalVentas == 1 ? "venta" : "ventas"}',
                  style: const TextStyle(
                    color:      AppColores.primary,
                    fontSize:   11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Monto grande
          Text(
            '\$${totalVendido.toStringAsFixed(2)}',
            style: const TextStyle(
              color:      AppColores.primary,
              fontSize:   34,
              fontWeight: FontWeight.bold,
              height:     1.1,
            ),
          ),

          const SizedBox(height: 16),

          // Barra contado vs fiado
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Contado vs Fiado',
                    style: TextStyle(
                      color:   AppColores.textSecond,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(porcentajeContado * 100).toStringAsFixed(0)}% contado',
                    style: const TextStyle(
                      color:   AppColores.textSecond,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    // Fondo = fiado
                    Container(
                      height: 10,
                      color:  AppColores.warning.withOpacity(0.25),
                    ),
                    // Encima = contado
                    FractionallySizedBox(
                      widthFactor: porcentajeContado,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color:        AppColores.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Leyenda
              Row(
                children: [
                  _PillLeyenda(
                    color: AppColores.success,
                    texto: 'Contado '
                        '\$${totalContado.toStringAsFixed(2)}',
                  ),
                  const SizedBox(width: 16),
                  _PillLeyenda(
                    color: AppColores.warning,
                    texto: 'Fiado '
                        '\$${totalFiado.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillLeyenda extends StatelessWidget {
  final Color  color;
  final String texto;
  const _PillLeyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color:        color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            color:   AppColores.textSecond,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SKELETON MIENTRAS CARGA
// ══════════════════════════════════════════════════════════
class _ResumenSkeleton extends StatelessWidget {
  const _ResumenSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonBox(height: 90)),
            const SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 90)),
          ],
        ),
        const SizedBox(height: 12),
        _SkeletonBox(height: 160),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     height,
      decoration: BoxDecoration(
        color:        Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LISTA RESUMIDA (máx 5 ventas en dashboard)
// ══════════════════════════════════════════════════════════
class _SliverListaVentasResumida extends ConsumerWidget {
  final String periodo;
  const _SliverListaVentasResumida({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historialVentasProvider(periodo));
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child:   CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (ventas) => ventas.isEmpty
          ? SliverToBoxAdapter(
              child: _EmptyVentas(periodo: periodo),
            )
          : SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => VentaItem(venta: ventas[i]),
                  childCount: ventas.length > 5 ? 5 : ventas.length,
                ),
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════
class _EmptyVentas extends StatelessWidget {
  final String periodo;
  const _EmptyVentas({required this.periodo});

  @override
  Widget build(BuildContext context) {
    final msgs = {
      'hoy':    'Aún no hay ventas hoy.\nPresiona + para registrar la primera.',
      'ayer':   'No hubo ventas ayer.',
      'semana': 'No hay ventas esta semana.',
      'mes':    'No hay ventas este mes.',
    };
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('🫓', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(
            msgs[periodo] ?? 'Sin ventas.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:    AppColores.textSecond,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}