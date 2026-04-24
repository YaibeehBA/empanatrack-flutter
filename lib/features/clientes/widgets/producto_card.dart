import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colores.dart';
import '../providers/pedidos_cliente_provider.dart';
import '../screens/cliente_shell.dart';

// ══════════════════════════════════════════════════════════
//  CARD DE PRODUCTO — reutilizable en catálogo y carrito
// ══════════════════════════════════════════════════════════
class ProductoCard extends ConsumerWidget {
  final ProductoDisponible producto;
  const ProductoCard({super.key, required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final cantidad = carrito.cantidadDeProducto(producto.id);
    final enCarrito = cantidad > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: enCarrito
            ? Border.all(color: AppColores.primary.withOpacity(0.4), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen / inicial
          _ProductoImagen(producto: producto),
          const SizedBox(width: 12),

          // Nombre y precio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${producto.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColores.success,
                  ),
                ),
              ],
            ),
          ),

          // Controles
          if (!enCarrito)
            _BtnAgregar(
              onTap: () => ref.read(carritoProvider.notifier).agregar(producto),
            )
          else
            ContadorCantidad(
              cantidad: cantidad,
              onMenos: () =>
                  ref.read(carritoProvider.notifier).quitar(producto.id),
              onMas: () => ref.read(carritoProvider.notifier).agregar(producto),
            ),
        ],
      ),
    );
  }
}

// ── Imagen con fallback a inicial ─────────────────────────
class _ProductoImagen extends StatelessWidget {
  final ProductoDisponible producto;
  const _ProductoImagen({required this.producto});

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: AppColores.primary.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty
          ? Image.network(
              producto.imagenUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  ProductoInicial(nombre: producto.nombre),
            )
          : ProductoInicial(nombre: producto.nombre),
    ),
  );
}

class _BtnAgregar extends StatelessWidget {
  final VoidCallback onTap;
  const _BtnAgregar({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColores.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    ),
  );
}

// ── Contador +/- exportable para uso en carrito ───────────
class ContadorCantidad extends StatelessWidget {
  final int cantidad;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final bool filledMas;

  const ContadorCantidad({
    super.key,
    required this.cantidad,
    required this.onMenos,
    required this.onMas,
    this.filledMas = true,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _BtnQty(icono: Icons.remove, onTap: onMenos),
      Container(
        width: 36,
        alignment: Alignment.center,
        child: Text(
          '$cantidad',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColores.primary,
          ),
        ),
      ),
      _BtnQty(icono: Icons.add, filled: filledMas, onTap: onMas),
    ],
  );
}

class _BtnQty extends StatelessWidget {
  final IconData icono;
  final bool filled;
  final VoidCallback onTap;

  const _BtnQty({
    required this.icono,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: filled
            ? AppColores.primary
            : AppColores.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icono,
        color: filled ? Colors.white : AppColores.primary,
        size: 18,
      ),
    ),
  );
}

// ── Inicial del producto (sin imagen) ─────────────────────
class ProductoInicial extends StatelessWidget {
  final String nombre;
  const ProductoInicial({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColores.primary,
      ),
    ),
  );
}
