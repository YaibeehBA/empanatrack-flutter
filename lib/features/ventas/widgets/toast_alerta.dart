import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';

class ToastAlerta extends StatelessWidget {
  final String       titulo;
  final String       subtitulo;
  final VoidCallback onCerrar;

  const ToastAlerta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.12), blurRadius: 10)],
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color:        AppColores.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.warning_amber_rounded,
            color: AppColores.danger, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13,
              color: AppColores.textPrimary)),
          const SizedBox(height: 1),
          Text(subtitulo, style: const TextStyle(
              fontSize: 11, color: AppColores.textSecond)),
        ],
      )),
      GestureDetector(
        onTap: onCerrar,
        child: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.close, size: 16,
              color: AppColores.textSecond),
        ),
      ),
    ]),
  );
}