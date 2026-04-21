import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

class EmpresaMarker extends StatelessWidget {
  final EmpresaRuta empresa;
  final bool        esCercana;

  const EmpresaMarker({
    super.key,
    required this.empresa,
    required this.esCercana,
  });

  Color get _color {
    if (empresa.visitada) return AppColores.success;
    if (esCercana)        return AppColores.warning;
    return AppColores.danger;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: _color.withOpacity(0.4)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15), blurRadius: 4)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            empresa.visitada ? Icons.check_circle : Icons.store,
            size: 10, color: _color,
          ),
          const SizedBox(width: 3),
          Text(
            empresa.nombre.length > 14
                ? '${empresa.nombre.substring(0, 14)}…'
                : empresa.nombre,
            style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.bold,
              color: empresa.visitada
                  ? AppColores.success : AppColores.textPrimary,
            ),
          ),
        ]),
      ),
      Icon(
        empresa.visitada ? Icons.check_circle : Icons.location_on,
        color: _color, size: 26,
      ),
    ],
  );
}