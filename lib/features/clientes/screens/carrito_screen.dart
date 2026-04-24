import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/pedidos_cliente_provider.dart';
import '../widgets/producto_card.dart';
import 'checkout_screen.dart';

// ══════════════════════════════════════════════════════════
//  PANTALLA CARRITO
// ══════════════════════════════════════════════════════════
class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Mi Carrito',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (carrito.items.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(carritoProvider.notifier).limpiar();
                Navigator.pop(context);
              },
              child: const Text('Vaciar',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: carrito.items.isEmpty
          ? const _CarritoVacio()
          : Column(children: [
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: carrito.items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ItemCarritoCard(item: carrito.items[i]),
              )),
              _BarraTotal(carrito: carrito),
            ]),
    );
  }
}

// ── Item del carrito con controles ────────────────────────
class _ItemCarritoCard extends ConsumerWidget {
  final ItemCarrito item;
  const _ItemCarritoCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6)],
      ),
      child: Row(children: [
        // Imagen
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color:        AppColores.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.producto.imagenUrl != null
                ? Image.network(
                    item.producto.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ProductoInicial(
                            nombre: item.producto.nombre),
                  )
                : ProductoInicial(nombre: item.producto.nombre),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.producto.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary)),
            Text('\$${item.producto.precio.toStringAsFixed(2)} c/u',
                style: const TextStyle(
                    fontSize: 12,
                    color:    AppColores.textSecond)),
          ],
        )),

        // Controles cantidad + eliminar
        Row(children: [
          ContadorCantidad(
            cantidad: item.cantidad,
            onMenos: () => ref
                .read(carritoProvider.notifier)
                .quitar(item.producto.id),
            onMas: () => ref
                .read(carritoProvider.notifier)
                .agregar(item.producto),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref
                .read(carritoProvider.notifier)
                .eliminar(item.producto.id),
            child: const Icon(Icons.delete_outline,
                color: AppColores.danger, size: 22),
          ),
        ]),
      ]),
    );
  }
}

// ── Barra inferior: total + botón checkout ────────────────
class _BarraTotal extends StatelessWidget {
  final CarritoState carrito;
  const _BarraTotal({required this.carrito});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16),
    decoration: BoxDecoration(
      color:     Colors.white,
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, -4))],
    ),
    child: Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total',
              style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
          Text('\$${carrito.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary)),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width:  double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CheckoutScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon:  const Icon(Icons.arrow_forward),
          label: const Text('Confirmar pedido',
              style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );
}

class _CarritoVacio extends StatelessWidget {
  const _CarritoVacio();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🛒', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('Tu carrito está vacío',
            style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary)),
      ],
    ),
  );
}