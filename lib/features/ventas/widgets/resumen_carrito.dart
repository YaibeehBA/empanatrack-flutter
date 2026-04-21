import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../providers/nueva_venta_provider.dart';

class ResumenCarrito extends StatelessWidget {
  final List<ItemCarrito> carrito;
  final double total;

  const ResumenCarrito({required this.carrito, required this.total, super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColores.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColores.primary.withOpacity(0.15)),
    ),
    child: Column(
      children: [
        ...carrito.map(
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '${i.cantidad}x  ${i.producto.nombre}',
                  style: const TextStyle(color: AppColores.textPrimary),
                ),
                const Spacer(),
                Text(
                  '\$${i.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Text(
              'TOTAL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColores.primary,
              ),
            ),
            const Spacer(),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColores.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
