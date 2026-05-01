import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

class EmpresaMarker extends StatelessWidget {
  final EmpresaRuta empresa;
  final bool        esCercana;
  final bool        esInicio;   // ← NUEVO

  const EmpresaMarker({
    super.key,
    required this.empresa,
    required this.esCercana,
    this.esInicio = false,      // ← NUEVO
  });

  Color get _color {
    if (empresa.visitada) return AppColores.success;
    if (esCercana)        return AppColores.warning;
    if (esInicio)         return AppColores.primary;   // ← azul para inicio
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
          border: Border.all(
              color: _color.withOpacity(0.5),
              // Borde más grueso para punto de inicio
              width: esInicio ? 2.0 : 1.0),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (esInicio) ...[
            Icon(Icons.play_arrow_rounded,
                size: 10, color: AppColores.primary),
            const SizedBox(width: 2),
          ] else
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
              fontWeight: esInicio || empresa.visitada
                  ? FontWeight.bold : FontWeight.normal,
              color: empresa.visitada
                  ? AppColores.success : AppColores.textPrimary,
            ),
          ),
        ]),
      ),
      Icon(
        empresa.visitada
            ? Icons.check_circle
            : esInicio
                ? Icons.flag_rounded
                : Icons.location_on,
        color: _color,
        size:  empresa.visitada ? 20 : esInicio ? 24 : 22,
      ),
    ],
  );
}