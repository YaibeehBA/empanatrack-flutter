// lib/features/ventas/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/ventas_provider.dart';
import '../../../shared/widgets/resumen_card.dart';
import '../../../shared/widgets/venta_item.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion      = ref.watch(authProvider).sesion;
    final resumenAsync = ref.watch(resumenDiaProvider);
    final ventasAsync  = ref.watch(ventasHoyProvider);

    return Scaffold(
      backgroundColor: AppColores.background,

      // ── AppBar ──────────────────────────────────────────────
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
                fontSize:   16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _fechaHoy(),
              style: const TextStyle(
                fontSize: 12,
                color:    Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:  'Cerrar sesión',
            icon:     const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),

      // ── FAB: nueva venta ────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed:        () => context.push('/nueva-venta'),
        backgroundColor:  AppColores.accent,
        foregroundColor:  Colors.white,
        icon:             const Icon(Icons.add),
        label:            const Text(
          'Nueva Venta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ── Body ────────────────────────────────────────────────
      body: RefreshIndicator(
        // Jalar hacia abajo refresca los datos
        onRefresh: () async {
          ref.invalidate(resumenDiaProvider);
          ref.invalidate(ventasHoyProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Sección: Resumen del día ─────────────────────
            const Text(
              'RESUMEN DE HOY',
              style: TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.bold,
                color:         AppColores.textSecond,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            resumenAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child:   CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _errorWidget(
                'No se pudo cargar el resumen',
                () => ref.invalidate(resumenDiaProvider),
              ),
              data: (resumen) => GridView.count(
                crossAxisCount:   2,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12,
                shrinkWrap:       true,
                childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ResumenCard(
                    icono:  '🧾',
                    titulo: 'Ventas del día',
                    valor:  '${resumen.totalVentas}',
                    color:  AppColores.accent,
                  ),
                  ResumenCard(
                    icono:  '💰',
                    titulo: 'Total vendido',
                    valor:  '\$${resumen.totalVendido.toStringAsFixed(2)}',
                    color:  AppColores.primary,
                  ),
                  ResumenCard(
                    icono:  '💳',
                    titulo: 'Total fiado',
                    valor:  '\$${resumen.totalFiado.toStringAsFixed(2)}',
                    color:  AppColores.warning,
                  ),
                  ResumenCard(
                    icono:  '✅',
                    titulo: 'Cobrado',
                    valor:  '\$${resumen.totalCobrado.toStringAsFixed(2)}',
                    color:  AppColores.success,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Botones de acción rápida ─────────────────────
            Row(
              children: [
                Expanded(
                child: _accionBtn(
                  icono:  Icons.people_outline,
                  label:  'Clientes',
                  color:  AppColores.primary,
                  onTap: () async {
                    // Esperar a que vuelva de clientes y refrescar
                    await context.push('/clientes');
                    ref.invalidate(resumenDiaProvider);
                    ref.invalidate(ventasHoyProvider);
                  },
                ),
              ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Últimas ventas del día ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ÚLTIMAS VENTAS',
                  style: TextStyle(
                    fontSize:      12,
                    fontWeight:    FontWeight.bold,
                    color:         AppColores.textSecond,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(ventasHoyProvider),
                  child: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ventasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => _errorWidget(
                'No se pudieron cargar las ventas',
                () => ref.invalidate(ventasHoyProvider),
              ),
              data: (ventas) => ventas.isEmpty
                  ? _emptyWidget('Aún no hay ventas hoy.\nPresiona + para registrar la primera.')
                  : Column(
                      children: ventas
                          .take(10) // Mostrar máximo 10
                          .map((v) => VentaItem(venta: v))
                          .toList(),
                    ),
            ),

            // Espacio para que el FAB no tape la última venta
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  String _fechaHoy() {
    final ahora  = DateTime.now();
    const meses  = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    const dias   = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return '${dias[ahora.weekday % 7]} ${ahora.day} ${meses[ahora.month]} ${ahora.year}';
  }

  Widget _accionBtn({
    required IconData icono,
    required String   label,
    required Color    color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
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

  Widget _errorWidget(String mensaje, VoidCallback onReintentar) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: AppColores.textSecond, size: 40),
          const SizedBox(height: 8),
          Text(mensaje,
              style: const TextStyle(color: AppColores.textSecond)),
          TextButton(
            onPressed: onReintentar,
            child:     const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text('🫓', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:    AppColores.textSecond,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}