import 'package:flutter/material.dart';
import '../../core/constants/colores.dart';
import '../models/venta_model.dart';

class VentaItem extends StatelessWidget {
  final VentaModel venta;

  const VentaItem({super.key, required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito  = venta.tipo == 'credito';
    final colorTipo  = esCredito ? AppColores.warning : AppColores.success;
    final labelTipo  = esCredito ? 'FIADO'            : 'CONTADO';

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono según tipo
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        colorTipo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                esCredito ? '💳' : '💵',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nombre cliente y estado
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venta.cliente ?? 'Venta de contado',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Badge tipo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        colorTipo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        labelTipo,
                        style: TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.bold,
                          color:      colorTipo,
                        ),
                      ),
                    ),
                    if (esCredito) ...[
                      const SizedBox(width: 6),
                      // Badge estado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color:        _colorEstado(venta.estado)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          venta.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize:   10,
                            fontWeight: FontWeight.bold,
                            color:      _colorEstado(venta.estado),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${venta.montoTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   15,
                  color:      AppColores.textPrimary,
                ),
              ),
              if (esCredito && venta.montoPendiente > 0)
                Text(
                  'Debe: \$${venta.montoPendiente.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color:    AppColores.danger,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pagado':   return AppColores.success;
      case 'parcial':  return AppColores.warning;
      default:         return AppColores.danger;
    }
  }
}