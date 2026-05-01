import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';

import '../../auth/providers/auth_provider.dart';
import '../../pedidos/screens/pedidos_repartidor_screen.dart';
import '../../pedidos/providers/pedidos_providers.dart';
import '../screens/historial_repartidor_screen.dart';

// Provider para controlar la pestaña activa
final _tabProvider = StateProvider<int>((ref) => 0);

class RepartidorShell extends ConsumerWidget {
  const RepartidorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_tabProvider);
    final pedidosCount = ref
        .watch(pedidosRepartidorProvider)
        .maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'EmpanaTrack',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Badge pedidos disponibles
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (pedidosCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColores.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$pedidosCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirma = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro que deseas cerrar sesión?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (confirma == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          PedidosRepartidorScreen(),
          HistorialRepartidorScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFE8ECF0)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icono: Icons.shopping_bag_outlined,
                  iconoActivo: Icons.shopping_bag_rounded,
                  label: 'Pedidos',
                  activo: tab == 0,
                  badge: pedidosCount,
                  onTap: () =>
                      ref.read(_tabProvider.notifier).state = 0,
                ),
                _NavItem(
                  icono: Icons.history_rounded,
                  iconoActivo: Icons.history_rounded,
                  label: 'Historial',
                  activo: tab == 1,
                  onTap: () =>
                      ref.read(_tabProvider.notifier).state = 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para cada ítem de la navegación inferior
class _NavItem extends StatelessWidget {
  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final bool activo;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                activo ? iconoActivo : icono,
                color: activo ? AppColores.primary : Colors.grey.shade600,
                size: 26,
              ),
              if (badge > 0 && !activo)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColores.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: activo ? AppColores.primary : Colors.grey.shade600,
              fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}