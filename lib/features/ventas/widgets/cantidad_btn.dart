import 'package:flutter/material.dart';


class CantidadBtn extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final Color color;
  final bool disabled;

  const CantidadBtn({
    required this.icono,
    required this.onTap,
    required this.color,
    this.disabled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(disabled ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icono,
        size: 18,
        color: disabled ? Colors.grey.shade300 : color,
      ),
    ),
  );
}
