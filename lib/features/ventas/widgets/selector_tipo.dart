import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';

class TipoBtn extends StatelessWidget {
  final String label;
  final String valor;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  const TipoBtn({
    required this.label,
    required this.valor,
    required this.activo,
    required this.color,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: activo ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activo ? Colors.white : AppColores.textSecond,
              fontSize: 13,
            ),
          ),
        ),
      ),
    ),
  );
}

class SelectorTipo extends StatelessWidget {
  final String seleccionado;
  final Function(String) onChange;

  const SelectorTipo({
    required this.seleccionado,
    required this.onChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TipoBtn(
        label: '💳  Fiado (Crédito)',
        valor: 'credito',
        activo: seleccionado == 'credito',
        color: AppColores.warning,
        onTap: () => onChange('credito'),
      ),
      const SizedBox(width: 12),
      TipoBtn(
        label: '💵  Contado',
        valor: 'contado',
        activo: seleccionado == 'contado',
        color: AppColores.success,
        onTap: () => onChange('contado'),
      ),
    ],
  );
}
