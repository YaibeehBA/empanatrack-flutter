import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/pedidos_vendedor_provider.dart';
import 'shell_providers.dart';

class BottomNav extends ConsumerWidget {
  final int               tabActivo;
  final ValueChanged<int> onTabChange;

  const BottomNav({
    super.key,
    required this.tabActivo,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosCount = ref
        .watch(pedidosDisponiblesProvider)
        .maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColores.surface,
        border: Border(
          top: BorderSide(color: Color(0xFFE8ECF0), width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icono:       Icons.map_outlined,
                iconoActivo: Icons.map_rounded,
                label:       'Ruta',
                activo:      tabActivo == Tabs.ruta,
                onTap:       () => onTabChange(Tabs.ruta),
              ),
              _NavItemBadge(
                icono:       Icons.shopping_bag_outlined,
                iconoActivo: Icons.shopping_bag_rounded,
                label:       'Pedidos',
                activo:      tabActivo == Tabs.pedidos,
                badge:       pedidosCount,
                onTap:       () => onTabChange(Tabs.pedidos),
              ),
              _NavItem(
                icono:       Icons.people_outline,
                iconoActivo: Icons.people_rounded,
                label:       'Clientes',
                activo:      tabActivo == Tabs.clientes,
                onTap:       () => onTabChange(Tabs.clientes),
              ),
              _NavItem(
                icono:       Icons.settings_outlined,
                iconoActivo: Icons.settings_rounded,
                label:       'Config.',
                activo:      tabActivo == Tabs.config,
                onTap:       () => onTabChange(Tabs.config),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item base ─────────────────────────────────────────
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
  Widget build(BuildContext context) => GestureDetector(
    onTap:    onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:  const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: activo
            ? AppColores.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          activo ? iconoActivo : icono,
          color: activo ? AppColores.primary : AppColores.textSecond,
          size:  24,
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          fontSize:   10,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          color: activo ? AppColores.primary : AppColores.textSecond,
        )),
      ]),
    ),
  );
}

// ── Nav item con badge ────────────────────────────────────
class _NavItemBadge extends StatelessWidget {
  final IconData     icono;
  final IconData     iconoActivo;
  final String       label;
  final bool         activo;
  final int          badge;
  final VoidCallback onTap;

  const _NavItemBadge({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap:    onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:  const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: activo
            ? AppColores.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(
            activo ? iconoActivo : icono,
            color: activo
                ? AppColores.primary : AppColores.textSecond,
            size: 24,
          ),
          if (badge > 0)
            Positioned(
              top: -4, right: -8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: AppColores.danger,
                    shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   9,
                    fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          fontSize:   10,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          color: activo ? AppColores.primary : AppColores.textSecond,
        )),
      ]),
    ),
  );
}