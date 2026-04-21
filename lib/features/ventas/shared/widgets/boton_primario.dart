import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';

class BotonPrimario extends StatelessWidget {
  final String        texto;
  final VoidCallback? onPressed;
  final bool          cargando;
  final Color?        color;

  const BotonPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColores.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: cargando
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(texto, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
    ),
  );
}