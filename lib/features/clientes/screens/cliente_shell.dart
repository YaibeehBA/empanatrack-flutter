import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../providers/pedidos_cliente_provider.dart';
import 'mi_cuenta_screen.dart';
import 'pedidos_cliente_screen.dart';
import 'productos_screen.dart';

// ══════════════════════════════════════════════════════════
//  PROVIDERS COMPARTIDOS DEL MÓDULO CLIENTE
// ══════════════════════════════════════════════════════════

/// Tab activo del shell
final tabActivoClienteProvider = StateProvider<int>((ref) => 0);

/// Empresa asignada al cliente (null = sin empresa)
final clienteEmpresaProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final r = await ApiClient.get('/clientes/mi-empresa');
    return r.data as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

/// Catálogo de productos disponibles para comprar
final productosDisponiblesProvider =
    FutureProvider.autoDispose<List<ProductoDisponible>>((ref) async {
  final r = await ApiClient.get('/productos/disponibles');
  return (r.data as List)
      .map((p) => ProductoDisponible.fromJson(p))
      .toList();
});

// ══════════════════════════════════════════════════════════
//  MODELO — Producto disponible para el cliente
// ══════════════════════════════════════════════════════════
class ProductoDisponible {
  final String  id;
  final String  nombre;
  final double  precio;
  final String? descripcion;
  final bool    estaActivo;
  final String? imagenUrl;

  const ProductoDisponible({
    required this.id,
    required this.nombre,
    required this.precio,
    this.descripcion,
    required this.estaActivo,
    this.imagenUrl,
  });

  factory ProductoDisponible.fromJson(Map<String, dynamic> j) =>
      ProductoDisponible(
        id:          j['id'].toString(),
        nombre:      j['nombre'].toString(),
        precio:      (j['precio'] as num).toDouble(),
        descripcion: null,
        estaActivo:  j['esta_activo'] as bool? ?? true,
        imagenUrl:   j['imagen_url'] as String?,
      );
}

// ══════════════════════════════════════════════════════════
//  SHELL — navegación por tabs
// ══════════════════════════════════════════════════════════
class ClienteShell extends ConsumerWidget {
  const ClienteShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab     = ref.watch(tabActivoClienteProvider);
    final carrito = ref.watch(carritoProvider);

    const pantallas = [
      MiCuentaScreen(),
      ProductosScreen(),
      PedidosClienteScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: tab, children: pantallas),
      bottomNavigationBar: _BottomNav(
        tabActivo:    tab,
        badgeCarrito: carrito.cantidadTotal > 0
            ? carrito.cantidadTotal : null,
        onTabChange: (i) =>
            ref.read(tabActivoClienteProvider.notifier).state = i,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BOTTOM NAV
// ══════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int                tabActivo;
  final int?               badgeCarrito;
  final void Function(int) onTabChange;

  const _BottomNav({
    required this.tabActivo,
    required this.onTabChange,
    this.badgeCarrito,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, -4))],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icono:       Icons.account_circle_outlined,
              iconoActivo: Icons.account_circle_rounded,
              label:       'Mi Cuenta',
              activo:      tabActivo == 0,
              onTap:       () => onTabChange(0),
            ),
            _NavItem(
              icono:       Icons.storefront_outlined,
              iconoActivo: Icons.storefront_rounded,
              label:       'Productos',
              activo:      tabActivo == 1,
              badge:       badgeCarrito,
              onTap:       () => onTabChange(1),
            ),
            _NavItem(
              icono:       Icons.receipt_long_outlined,
              iconoActivo: Icons.receipt_long_rounded,
              label:       'Mis Pedidos',
              activo:      tabActivo == 2,
              onTap:       () => onTabChange(2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData     icono;
  final IconData     iconoActivo;
  final String       label;
  final bool         activo;
  final VoidCallback onTap;
  final int?         badge;

  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap:    onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: activo
            ? AppColores.primary.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(
              activo ? iconoActivo : icono,
              color: activo
                  ? AppColores.primary
                  : AppColores.textSecond,
              size: 26,
            ),
            if (badge != null && badge! > 0)
              Positioned(
                top: -4, right: -8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColores.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize:   10,
            fontWeight: activo
                ? FontWeight.bold : FontWeight.normal,
            color: activo
                ? AppColores.primary : AppColores.textSecond,
          )),
        ],
      ),
    ),
  );
}