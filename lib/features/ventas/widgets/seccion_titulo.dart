import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';

class SeccionTitulo extends StatelessWidget {
  final String titulo;
  final TextStyle? style;

  const SeccionTitulo({required this.titulo, this.style, super.key});

  @override
  Widget build(BuildContext context) => Text(
    titulo.toUpperCase(),
    style:
        style ??
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColores.textSecond,
          letterSpacing: 1.2,
        ),
  );
}
