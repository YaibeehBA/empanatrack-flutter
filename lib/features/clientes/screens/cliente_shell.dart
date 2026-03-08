// lib/features/clientes/screens/cliente_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import 'mi_cuenta_screen.dart';

// ── Provider tab activo cliente ───────────────────────────
final tabActivoClienteProvider = StateProvider<int>((ref) => 0);

// ── Modelo producto ───────────────────────────────────────
class ProductoDisponible {
  final String  id;
  final String  nombre;
  final double  precio;
  final String? descripcion;
  final bool    estaActivo;

  const ProductoDisponible({
    required this.id,
    required this.nombre,
    required this.precio,
    this.descripcion,
    required this.estaActivo,
  });

  factory ProductoDisponible.fromJson(Map<String, dynamic> j) =>
      ProductoDisponible(
        id:          j['id'].toString(),
        nombre:      j['nombre'].toString(),
        precio:      (j['precio'] as num).toDouble(),
        descripcion: null, 
        estaActivo:  j['esta_activo'] as bool? ?? true,
      );
}

// ── Provider productos disponibles ───────────────────────
final productosDisponiblesProvider =
    FutureProvider.autoDispose<List<ProductoDisponible>>((ref) async {
  final response = await ApiClient.get('/productos/disponibles');
  final lista    = response.data as List;
  return lista.map((p) => ProductoDisponible.fromJson(p)).toList();
});

// ══════════════════════════════════════════════════════════
//  SHELL DEL CLIENTE
// ══════════════════════════════════════════════════════════
class ClienteShell extends ConsumerWidget {
  const ClienteShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabActivoClienteProvider);

    final pantallas = const [
      MiCuentaScreen(),
      _ProductosScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index:    tab,
        children: pantallas,
      ),
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
                  icono:       Icons.account_circle_outlined,
                  iconoActivo: Icons.account_circle_rounded,
                  label:       'Mi Cuenta',
                  activo:      tab == 0,
                  onTap: () => ref
                      .read(tabActivoClienteProvider.notifier).state = 0,
                ),
                _NavItem(
                  icono:       Icons.storefront_outlined,
                  iconoActivo: Icons.storefront_rounded,
                  label:       'Productos',
                  activo:      tab == 1,
                  onTap: () => ref
                      .read(tabActivoClienteProvider.notifier).state = 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NAV ITEM
// ══════════════════════════════════════════════════════════
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
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: activo
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
              size: 26,
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

// ══════════════════════════════════════════════════════════
//  PANTALLA PRODUCTOS
// ══════════════════════════════════════════════════════════
class _ProductosScreen extends ConsumerWidget {
  const _ProductosScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosDisponiblesProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        elevation:                 0,
        title: const Text(
          'Productos Disponibles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () =>
                ref.invalidate(productosDisponiblesProvider),
          ),
        ],
      ),
      body: productosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️',
                  style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar los productos',
                style: TextStyle(color: AppColores.textSecond),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.invalidate(productosDisponiblesProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (productos) => productos.isEmpty
            ? const _EmptyProductos()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(productosDisponiblesProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ── Banner informativo ───────────────
                    _BannerInfo(),
                    const SizedBox(height: 16),

                    // ── Lista de productos ───────────────
                    ...productos.map(
                      (p) => _ProductoCard(producto: p),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BANNER INFORMATIVO
// ══════════════════════════════════════════════════════════
class _BannerInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColores.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColores.primary.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          const Text('🫓',
              style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catálogo del día',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                    color:      AppColores.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aquí verás lo que estará disponible. '
                  'Planifica tu compra antes de que llegue el vendedor.',
                  style: TextStyle(
                    fontSize: 12,
                    color:    AppColores.textSecond,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD DE PRODUCTO
// ══════════════════════════════════════════════════════════
class _ProductoCard extends StatelessWidget {
  final ProductoDisponible producto;
  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [

          // ── Ícono / inicial ──────────────────────────
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        AppColores.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                producto.nombre.isNotEmpty
                    ? producto.nombre[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Info ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  ),
                ),
                if (producto.descripcion != null &&
                    producto.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    producto.descripcion!,
                    style: const TextStyle(
                      fontSize: 12,
                      color:    AppColores.textSecond,
                    ),
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Precio ───────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${producto.precio.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.success,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColores.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Disponible',
                  style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.success,
                  ),
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
//  EMPTY STATE
// ══════════════════════════════════════════════════════════
class _EmptyProductos extends StatelessWidget {
  const _EmptyProductos();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🫓', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text(
              'No hay productos disponibles',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'El catálogo se actualizará cuando el\nadministrador agregue productos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:    AppColores.textSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }
}