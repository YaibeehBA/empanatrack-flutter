import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import 'dashboard_screen.dart';
import 'historial_screen.dart';
import '../../clientes/screens/clientes_screen.dart';

class VendedorShell extends StatefulWidget {
  const VendedorShell({super.key});

  @override
  State<VendedorShell> createState() => _VendedorShellState();
}

class _VendedorShellState extends State<VendedorShell> {
  int _tab = 0;

  final _pantallas = const [
    DashboardScreen(),
    ClientesScreen(),
    HistorialScreen(),
    _ConfiguracionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: _pantallas,
      ),
      // FAB solo en dashboard
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed:       () => context.push('/nueva-venta'),
              backgroundColor: AppColores.accent,
              foregroundColor: Colors.white,
              icon:            const Icon(Icons.add),
              label:           const Text('Nueva Venta',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  icono:     Icons.home_outlined,
                  iconoActivo: Icons.home_rounded,
                  label:     'Inicio',
                  activo:    _tab == 0,
                  onTap:     () => setState(() => _tab = 0),
                ),
                _NavItem(
                  icono:     Icons.people_outline,
                  iconoActivo: Icons.people_rounded,
                  label:     'Clientes',
                  activo:    _tab == 1,
                  onTap:     () => setState(() => _tab = 1),
                ),
                _NavItem(
                  icono:     Icons.receipt_long_outlined,
                  iconoActivo: Icons.receipt_long_rounded,
                  label:     'Historial',
                  activo:    _tab == 2,
                  onTap:     () => setState(() => _tab = 2),
                ),
                _NavItem(
                  icono:     Icons.settings_outlined,
                  iconoActivo: Icons.settings_rounded,
                  label:     'Config.',
                  activo:    _tab == 3,
                  onTap:     () => setState(() => _tab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item del navbar ────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icono;
  final IconData iconoActivo;
  final String   label;
  final bool     activo;
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
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
              color:  activo ? AppColores.primary : AppColores.textSecond,
              size:   24,
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

// ── Configuración (en desarrollo) ─────────────────────────
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