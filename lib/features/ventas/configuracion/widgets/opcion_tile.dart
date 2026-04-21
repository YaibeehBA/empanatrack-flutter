import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';

class OpcionTile extends StatelessWidget {
  final IconData     icono;
  final Color        color;
  final String       titulo;
  final String       subtitulo;
  final VoidCallback onTap;
  final bool         sinFlecha;

  const OpcionTile({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.sinFlecha = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color:      Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2))],
    ),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: color, size: 20),
      ),
      title: Text(titulo, style: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w600,
          color:      AppColores.textPrimary)),
      subtitle: Text(subtitulo, style: const TextStyle(
          fontSize: 12,
          color:    AppColores.textSecond)),
      trailing: sinFlecha
          ? null
          : const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColores.textSecond),
    ),
  );
}