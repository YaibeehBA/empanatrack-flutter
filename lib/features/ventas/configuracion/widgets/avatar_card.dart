import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';
import '../perfil_provider.dart';

class AvatarCard extends StatelessWidget {
  final PerfilVendedor perfil;
  const AvatarCard({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    final inicial = perfil.nombre.isNotEmpty
        ? perfil.nombre[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color:        AppColores.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(child: Text(inicial,
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   28,
                  fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(perfil.nombre, style: const TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary)),
            const SizedBox(height: 4),
            Text('@${perfil.nombreUsuario}',
                style: const TextStyle(
                    fontSize: 13,
                    color:    AppColores.textSecond)),
            if (perfil.telefono != null &&
                perfil.telefono!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.phone_outlined,
                    size: 13, color: AppColores.textSecond),
                const SizedBox(width: 4),
                Text(perfil.telefono!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.textSecond)),
              ]),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(perfil.rol.toUpperCase(),
                  style: const TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.bold,
                      color:      AppColores.primary)),
            ),
          ],
        )),
      ]),
    );
  }
}