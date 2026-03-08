import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';
import '../../../shared/widgets/venta_item.dart';
import 'vendedor_shell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refrescar();
    });
  }

  void _refrescar() {
    final periodo = ref.read(periodoSeleccionadoProvider);
    ref.invalidate(resumenDiaProvider(periodo));
    ref.invalidate(historialVentasProvider(periodo));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabActivoProvider, (prev, next) {
      if (next == 0 && prev != 0) _refrescar();
    });

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
            icon:    const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refrescar(),
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

            // ── Título historial ─────────────────────────
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
                      onTap: _refrescar,
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

            // ── Lista resumida (máx 5) ───────────────────
            _SliverListaVentasResumida(periodo: periodo),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _fechaHoy() {
    final now   = DateTime.now();
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    const dias  = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    return '${dias[now.weekday % 7]} ${now.day} ${meses[now.month]} ${now.year}';
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
    required this.seleccionado,
    required this.onChange,
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
                  color: activo
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
      data:    (r) => Column(
        children: [

          // ── Card principal: Dinero en mano ─────────────
          _DineroEnManoCard(
            dineroEnMano: r.dineroEnMano,
            totalContado: r.totalContado,
            totalCobrado: r.totalCobrado,
            totalVentas:  r.totalVentas,
          ),

          const SizedBox(height: 12),

          // ── Fila inferior: Total vendido | Por cobrar ──
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  color:     AppColores.primary,
                  icono:     '📦',
                  etiqueta:  'Total vendido',
                  valor:     '\$${r.totalVendido.toStringAsFixed(2)}',
                  subtitulo: 'Contado + fiado',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  color:     AppColores.warning,
                  icono:     '📋',
                  etiqueta:  'Por cobrar',
                  valor:     '\$${r.totalFiado.toStringAsFixed(2)}',
                  subtitulo: 'Fiado pendiente',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD PRINCIPAL — Dinero en mano
// ══════════════════════════════════════════════════════════
class _DineroEnManoCard extends StatelessWidget {
  final double dineroEnMano;
  final double totalContado;
  final double totalCobrado;
  final int    totalVentas;

  const _DineroEnManoCard({
    required this.dineroEnMano,
    required this.totalContado,
    required this.totalCobrado,
    required this.totalVentas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
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

          // ── Encabezado ───────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        AppColores.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('💰',
                    style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DINERO EN MANO',
                      style: TextStyle(
                        color:         AppColores.textSecond,
                        fontSize:      11,
                        letterSpacing: 1.2,
                        fontWeight:    FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ventas contado + cobros recibidos',
                      style: TextStyle(
                        color:    AppColores.textSecond,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge número de ventas
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
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

          const SizedBox(height: 16),

          // ── Monto grande ─────────────────────────────
          Text(
            '\$${dineroEnMano.toStringAsFixed(2)}',
            style: const TextStyle(
              color:      AppColores.primary,
              fontSize:   42,
              fontWeight: FontWeight.bold,
              height:     1.0,
            ),
          ),

          const SizedBox(height: 16),

          // ── Divisor ──────────────────────────────────
          Divider(
            color:  Colors.grey.withOpacity(0.20),
            height: 1,
          ),
          const SizedBox(height: 14),

          // ── Desglose: contado | cobros ────────────────
          Row(
            children: [
              Expanded(
                child: _DesglosItem(
                  icono:      '💵',
                  etiqueta:   'Ventas contado',
                  valor:      '\$${totalContado.toStringAsFixed(2)}',
                  colorValor: AppColores.success,
                ),
              ),
              Container(
                width: 1, height: 36,
                color: Colors.grey.withOpacity(0.20),
              ),
              Expanded(
                child: _DesglosItem(
                  icono:      '🤝',
                  etiqueta:   'Cobros recibidos',
                  valor:      '\$${totalCobrado.toStringAsFixed(2)}',
                  colorValor: AppColores.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesglosItem extends StatelessWidget {
  final String icono;
  final String etiqueta;
  final String valor;
  final Color  colorValor;

  const _DesglosItem({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.colorValor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icono, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                etiqueta,
                style: const TextStyle(
                  color:    AppColores.textSecond,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color:      colorValor,
              fontSize:   18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  STAT CARD — Total vendido y Por cobrar
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
              Expanded(
                child: Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize:   12,
                    color:      AppColores.textSecond,
                    fontWeight: FontWeight.w500,
                  ),
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
//  SKELETON
// ══════════════════════════════════════════════════════════
class _ResumenSkeleton extends StatelessWidget {
  const _ResumenSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SkeletonBox(height: 180),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SkeletonBox(height: 90)),
            const SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 90)),
          ],
        ),
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
      height: height,
      decoration: BoxDecoration(
        color:        Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LISTA RESUMIDA (máx 5 ventas)
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
      error: (e, _) => const SliverToBoxAdapter(
        child: SizedBox.shrink(),
      ),
      data: (ventas) => ventas.isEmpty
          ? SliverToBoxAdapter(child: _EmptyVentas(periodo: periodo))
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