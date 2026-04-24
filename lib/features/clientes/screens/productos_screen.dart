import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/pedidos_cliente_provider.dart';
import 'carrito_screen.dart';
import 'cliente_shell.dart';
import '../widgets/producto_card.dart';

// ══════════════════════════════════════════════════════════
//  PANTALLA CATÁLOGO DE PRODUCTOS
// ══════════════════════════════════════════════════════════
class ProductosScreen extends ConsumerWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosDisponiblesProvider);
    final carrito        = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Productos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(productosDisponiblesProvider),
          ),
        ],
      ),
      floatingActionButton: carrito.cantidadTotal > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CarritoScreen()),
              ),
              backgroundColor: AppColores.accent,
              foregroundColor: Colors.white,
              icon:  const Icon(Icons.shopping_cart),
              label: Text(
                '${carrito.cantidadTotal} items  '
                '\$${carrito.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: productosAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar los productos',
                style: TextStyle(color: AppColores.textSecond)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.invalidate(productosDisponiblesProvider),
              child: const Text('Reintentar'),
            ),
          ],
        )),
        data: (productos) => productos.isEmpty
            ? const _SinProductos()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(productosDisponiblesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      16, 16, 16, 100),
                  children: [
                    const _BannerInfo(),
                    const SizedBox(height: 16),
                    ...productos.map(
                        (p) => ProductoCard(producto: p)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BannerInfo extends StatelessWidget {
  const _BannerInfo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppColores.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: AppColores.primary.withOpacity(0.20)),
    ),
    child: const Row(children: [
      Text('🫓', style: TextStyle(fontSize: 28)),
      SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Haz tu pedido',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   14,
                color:      AppColores.textPrimary,
              )),
          SizedBox(height: 2),
          Text(
            'Agrega productos al carrito y elige '
            'cómo pagar. Te lo llevamos.',
            style: TextStyle(
                fontSize: 12, color: AppColores.textSecond),
          ),
        ],
      )),
    ]),
  );
}

class _SinProductos extends StatelessWidget {
  const _SinProductos();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🫓', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text('No hay productos disponibles',
              style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
          SizedBox(height: 8),
          Text('El catálogo se actualizará pronto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color:    AppColores.textSecond)),
        ],
      ),
    ),
  );
}