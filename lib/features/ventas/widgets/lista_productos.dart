import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../../../shared/models/producto_model.dart';
import '../providers/nueva_venta_provider.dart';
import 'cantidad_btn.dart';

class ListaProductos extends StatelessWidget {
  final List<ProductoModel> productos;
  final List<ItemCarrito> carrito;
  final Map<String, int> stockDisponible;
  final Function(String, int) onChange;
  final Function(ProductoModel) onAgregar;

  const ListaProductos({
    required this.productos,
    required this.carrito,
    required this.stockDisponible,
    required this.onChange,
    required this.onAgregar,
    super.key,
  });

  int _stockRestante(String productoId) => stockDisponible[productoId] ?? 999;

  int _cantidadEn(String productoId) {
    final item = carrito.where((i) => i.producto.id == productoId);
    return item.isEmpty ? 0 : item.first.cantidad;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: productos.map((p) {
        final cantidad = _cantidadEn(p.id);
        final restante = _stockRestante(p.id);
        final agotado = restante <= 0;
        final enLimite = cantidad >= restante;

        return _ProductoItem(
          producto: p,
          cantidad: cantidad,
          restante: restante,
          agotado: agotado,
          enLimite: enLimite,
          onChange: (delta) => onChange(p.id, delta),
          onAgregar: () => onAgregar(p),
        );
      }).toList(),
    );
  }
}

class _ProductoItem extends StatelessWidget {
  final ProductoModel producto;
  final int cantidad;
  final int restante;
  final bool agotado;
  final bool enLimite;
  final Function(int) onChange;
  final VoidCallback onAgregar;

  const _ProductoItem({
    required this.producto,
    required this.cantidad,
    required this.restante,
    required this.agotado,
    required this.enLimite,
    required this.onChange,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: agotado ? Colors.grey.shade50 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: agotado
            ? Colors.grey.shade300
            : cantidad > 0
            ? AppColores.accent
            : Colors.grey.shade200,
        width: cantidad > 0 ? 2 : 1,
      ),
    ),
    child: Row(
      children: [
        _ProductoImagen(imagenUrl: producto.imagenUrl, agotado: agotado),
        const SizedBox(width: 12),
        Expanded(
          child: _ProductoInfo(
            nombre: producto.nombre,
            precio: producto.precio,
            restante: restante,
            agotado: agotado,
            enLimite: enLimite,
            mostrarStock: true,
          ),
        ),
        _ProductoAccion(
          agotado: agotado,
          cantidad: cantidad,
          enLimite: enLimite,
          onAgregar: onAgregar,
          onChange: onChange,
        ),
      ],
    ),
  );
}

class _ProductoImagen extends StatelessWidget {
  final String? imagenUrl;
  final bool agotado;

  const _ProductoImagen({required this.imagenUrl, required this.agotado});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: agotado ? 0.4 : 1.0,
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColores.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imagenUrl != null && imagenUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imagenUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('🫓', style: TextStyle(fontSize: 22)),
                ),
              ),
            )
          : const Center(child: Text('🫓', style: TextStyle(fontSize: 22))),
    ),
  );
}

class _ProductoInfo extends StatelessWidget {
  final String nombre;
  final double precio;
  final int restante;
  final bool agotado;
  final bool enLimite;
  final bool mostrarStock;

  const _ProductoInfo({
    required this.nombre,
    required this.precio,
    required this.restante,
    required this.agotado,
    required this.enLimite,
    required this.mostrarStock,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        nombre,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: agotado ? AppColores.textSecond : AppColores.textPrimary,
        ),
      ),
      Text(
        '\$${precio.toStringAsFixed(2)} c/u',
        style: const TextStyle(color: AppColores.accent, fontSize: 13),
      ),
      if (mostrarStock)
        Text(
          agotado ? 'Sin stock' : 'Disponible: $restante uds',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: agotado
                ? AppColores.danger
                : enLimite
                ? AppColores.warning
                : AppColores.success,
          ),
        ),
    ],
  );
}

class _ProductoAccion extends StatelessWidget {
  final bool agotado;
  final int cantidad;
  final bool enLimite;
  final VoidCallback onAgregar;
  final Function(int) onChange;

  const _ProductoAccion({
    required this.agotado,
    required this.cantidad,
    required this.enLimite,
    required this.onAgregar,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    if (agotado) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Agotado',
          style: TextStyle(
            color: AppColores.textSecond,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (cantidad == 0) {
      return GestureDetector(
        onTap: onAgregar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColores.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '+ Agregar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        CantidadBtn(
          icono: Icons.remove,
          onTap: () => onChange(-1),
          color: AppColores.danger,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$cantidad',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        CantidadBtn(
          icono: Icons.add,
          onTap: enLimite ? null : () => onChange(1),
          color: enLimite ? Colors.grey : AppColores.success,
          disabled: enLimite,
        ),
      ],
    );
  }
}
