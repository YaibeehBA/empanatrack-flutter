import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colores.dart';
import '../../../../core/network/api_client.dart';
import '../models/ruta_activa_models.dart';

class StockProductoItem extends StatelessWidget {
  final ProductoStock  producto;
  final ValueChanged<int> onCantidadChanged;

  const StockProductoItem({
    super.key,
    required this.producto,
    required this.onCantidadChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Row(children: [
      // Avatar / imagen
      _ProductoAvatar(
          nombre:    producto.nombre,
          imagenUrl: producto.imagenUrl),
      const SizedBox(width: 12),
      // Info
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(producto.nombre, style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColores.textPrimary)),
          Text('\$${producto.precio.toStringAsFixed(2)} c/u',
              style: const TextStyle(
                  fontSize: 12, color: AppColores.textSecond)),
        ],
      )),
      // Controles cantidad
      _CantidadControl(
        cantidad:  producto.cantidad,
        onChange:  onCantidadChanged,
      ),
    ]),
  );
}

class _ProductoAvatar extends StatelessWidget {
  final String  nombre;
  final String? imagenUrl;
  const _ProductoAvatar({required this.nombre, this.imagenUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color:        AppColores.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imagenUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '${ApiClient.baseUrl}$imagenUrl',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Inicial(nombre),
              ))
          : _Inicial(nombre),
    );
  }
}

class _Inicial extends StatelessWidget {
  final String nombre;
  const _Inicial(this.nombre);
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: AppColores.primary),
    ),
  );
}

class _CantidadControl extends StatelessWidget {
  final int              cantidad;
  final ValueChanged<int> onChange;
  const _CantidadControl({
    required this.cantidad, required this.onChange});

  @override
  Widget build(BuildContext context) => Row(children: [
    _Btn(
      icono:  Icons.remove,
      filled: false,
      activo: cantidad > 0,
      onTap:  cantidad > 0 ? () => onChange(cantidad - 1) : null,
    ),
    SizedBox(
      width: 46,
      child: TextFormField(
        key:         ValueKey(cantidad),
        initialValue: '$cantidad',
        textAlign:    TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            color: AppColores.primary),
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true),
        onChanged: (v) => onChange(int.tryParse(v) ?? 0),
      ),
    ),
    _Btn(
      icono:  Icons.add,
      filled: true,
      activo: true,
      onTap:  () => onChange(cantidad + 1),
    ),
  ]);
}

class _Btn extends StatelessWidget {
  final IconData   icono;
  final bool       filled;
  final bool       activo;
  final VoidCallback? onTap;
  const _Btn({required this.icono, required this.filled,
      required this.activo, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: !activo
            ? Colors.grey.shade100
            : filled
                ? AppColores.primary
                : AppColores.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icono, size: 16,
          color: !activo ? Colors.grey.shade400
              : filled ? Colors.white : AppColores.primary),
    ),
  );
}