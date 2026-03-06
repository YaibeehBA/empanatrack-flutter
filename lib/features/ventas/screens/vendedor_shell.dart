// lib/features/ventas/screens/vendedor_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import 'dashboard_screen.dart';
import 'historial_screen.dart';
import '../../clientes/screens/clientes_screen.dart';

// Provider del tab activo — accesible desde cualquier pantalla
final tabActivoProvider = StateProvider<int>((ref) => 0);

class VendedorShell extends ConsumerWidget {
  const VendedorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabActivoProvider);

    final pantallas = const [
      DashboardScreen(),
      ClientesScreen(),
      HistorialScreen(),
      _ConfiguracionScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: pantallas,
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed:       () => context.push('/nueva-venta'),
              backgroundColor: AppColores.accent,
              foregroundColor: Colors.white,
              icon:            const Icon(Icons.add),
              label:           const Text(
                'Nueva Venta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset:     const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icono:       Icons.home_outlined,
                  iconoActivo: Icons.home_rounded,
                  label:       'Inicio',
                  activo:      tab == 0,
                  onTap:       () => ref
                      .read(tabActivoProvider.notifier).state = 0,
                ),
                _NavItem(
                  icono:       Icons.people_outline,
                  iconoActivo: Icons.people_rounded,
                  label:       'Clientes',
                  activo:      tab == 1,
                  onTap:       () => ref
                      .read(tabActivoProvider.notifier).state = 1,
                ),
                _NavItem(
                  icono:       Icons.receipt_long_outlined,
                  iconoActivo: Icons.receipt_long_rounded,
                  label:       'Historial',
                  activo:      tab == 2,
                  onTap:       () => ref
                      .read(tabActivoProvider.notifier).state = 2,
                ),
                _NavItem(
                  icono:       Icons.settings_outlined,
                  iconoActivo: Icons.settings_rounded,
                  label:       'Config.',
                  activo:      tab == 3,
                  onTap:       () => ref
                      .read(tabActivoProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icono;
  final IconData     iconoActivo;
  final String       label;
  final bool         activo;
  final VoidCallback onTap;
  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:     onTap,
      behavior:  HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:        activo
              ? AppColores.primary.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activo ? iconoActivo : icono,
              color: activo
                  ? AppColores.primary
                  : AppColores.textSecond,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize:   10,
                fontWeight: activo
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: activo
                    ? AppColores.primary
                    : AppColores.textSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfiguracionScreen extends StatelessWidget {
  const _ConfiguracionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Configuración',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⚙️', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text(
              'Configuración',
              style: TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Esta sección está en desarrollo.',
              style: TextStyle(color: AppColores.textSecond),
            ),
          ],
        ),
      ),
    );
  }
}