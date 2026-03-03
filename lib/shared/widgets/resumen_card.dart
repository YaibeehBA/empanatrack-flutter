import 'package:flutter/material.dart';
import '../../core/constants/colores.dart';

class ResumenCard extends StatelessWidget {
  final String icono;
  final String titulo;
  final String valor;
  final Color  color;

  const ResumenCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withOpacity(0.06),
            blurRadius:  10,
            offset:      const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono con fondo de color
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icono, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 12),

          // Valor principal
          Text(
            valor,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
          const SizedBox(height: 4),

          // Título descriptivo
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color:    AppColores.textSecond,
            ),
          ),
        ],
      ),
    );
  }
}