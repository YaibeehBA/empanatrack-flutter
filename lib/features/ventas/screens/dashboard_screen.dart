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
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        elevation:       0,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       () => context.push('/nueva-venta'),
        backgroundColor: AppColores.accent,
        foregroundColor: Colors.white,
        icon:            const Icon(Icons.add),
        label:           const Text(
          'Nueva Venta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  onChange: (p) {
                    ref.read(periodoSeleccionadoProvider.notifier).state = p;
                  },
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

            // ── Botón clientes ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BotonClientes(periodo: periodo),
              ),
            ),

            // ── Título historial ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
                          Text('Actualizar',
                              style: TextStyle(
                                fontSize: 12, color: AppColores.accent,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Lista de ventas ──────────────────────────
            _SliverListaVentas(periodo: periodo),

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
    return '${dias[now.weekday % 7]} ${now.day} ${meses[now.month]} ${now.year}';
  }

  String _labelHistorial(String p) {
    switch (p) {
      case 'ayer':   return 'VENTAS DE AYER';
      case 'semana': return 'VENTAS DE ESTA SEMANA';
      case 'mes':    return 'VENTAS DE ESTE MES';
      default:       return 'VENTAS DE HOY';
    }
  }
}

// ── Selector de periodo ────────────────────────────────────
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
            blurRadius: 8, offset: const Offset(0, 2),
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
                  color:        activo ? AppColores.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    o['l']!,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.bold,
                      color: activo ? Colors.white : AppColores.textSecond,
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

// ── Bloque de resumen ──────────────────────────────────────
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

          // ── Fila 2: Total vendido (ancho completo) ───
          _TotalVendidoCard(
            totalVendido: r.totalVendido,
            totalContado: r.totalContado,
            totalFiado:   r.totalFiado,
            totalVentas:  r.totalVentas,
          ),

          const SizedBox(height: 12),

          // ── Fila 3: Cobrado ──────────────────────────
          _CobradoCard(cobrado: r.totalCobrado),
        ],
      ),
    );
  }
}

// ── Tarjeta estadística pequeña ────────────────────────────
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
            blurRadius: 8, offset: const Offset(0, 2),
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
                  fontSize: 12, color: AppColores.textSecond,
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
              fontSize: 11, color: AppColores.textSecond,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card total vendido ─────────────────────────────────────
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
        ? totalContado / totalVendido
        : 0.0;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.primary,
            AppColores.primary.withBlue(120),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      AppColores.primary.withOpacity(0.3),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOTAL VENDIDO',
                style: TextStyle(
                  color:         Colors.white70,
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
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalVentas ${totalVentas == 1 ? "venta" : "ventas"}',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$${totalVendido.toStringAsFixed(2)}',
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   34,
              fontWeight: FontWeight.bold,
              height:     1.1,
            ),
          ),
          const SizedBox(height: 14),

          // Barra contado vs fiado
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Contado vs Fiado',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  Text(
                    '${(porcentajeContado * 100).toStringAsFixed(0)}% contado',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    // Fondo (fiado)
                    Container(
                      height: 10,
                      color:  Colors.orangeAccent.withOpacity(0.5),
                    ),
                    // Contado encima
                    FractionallySizedBox(
                      widthFactor: porcentajeContado,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PillLeyenda(
                    color: Colors.greenAccent.shade400,
                    texto: 'Contado \$${totalContado.toStringAsFixed(2)}',
                  ),
                  const SizedBox(width: 10),
                  _PillLeyenda(
                    color: Colors.orangeAccent,
                    texto: 'Fiado \$${totalFiado.toStringAsFixed(2)}',
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
          width: 8, height: 8,
          decoration: BoxDecoration(
            color:        color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(texto,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Card cobrado ───────────────────────────────────────────
class _CobradoCard extends StatelessWidget {
  final double cobrado;
  const _CobradoCard({required this.cobrado});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        cobrado > 0
            ? AppColores.success.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cobrado > 0
              ? AppColores.success.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        AppColores.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('💸', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cobrado en el periodo',
                style: TextStyle(
                  fontSize: 12, color: AppColores.textSecond,
                ),
              ),
              Text(
                '\$${cobrado.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color: cobrado > 0
                      ? AppColores.success
                      : AppColores.textSecond,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (cobrado > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColores.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✓ Pagos\nrecibidos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      AppColores.success,
                  fontSize:   10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Skeleton mientras carga ────────────────────────────────
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
        _SkeletonBox(height: 140),
        const SizedBox(height: 12),
        _SkeletonBox(height: 72),
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

// ── Botón clientes ─────────────────────────────────────────
class _BotonClientes extends ConsumerWidget {
  final String periodo;
  const _BotonClientes({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await context.push('/clientes');
        ref.invalidate(resumenDiaProvider(periodo));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        AppColores.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Ver Clientes y Deudas',
              style: TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold,
                fontSize:   14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de ventas ────────────────────────────────────────
class _SliverListaVentas extends ConsumerWidget {
  final String periodo;
  const _SliverListaVentas({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historialVentasProvider(periodo));
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child:   CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.wifi_off,
                    color: AppColores.textSecond, size: 40),
                const SizedBox(height: 8),
                const Text('No se pudieron cargar las ventas',
                    style: TextStyle(color: AppColores.textSecond)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(historialVentasProvider(periodo)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (ventas) => ventas.isEmpty
          ? SliverToBoxAdapter(child: _EmptyVentas(periodo: periodo))
          : SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => VentaItem(venta: ventas[i]),
                  childCount: ventas.length,
                ),
              ),
            ),
    );
  }
}

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
              color: AppColores.textSecond, fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}