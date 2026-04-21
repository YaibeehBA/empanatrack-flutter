import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';

class CampoTexto extends StatelessWidget {
  final TextEditingController controlador;
  final String                etiqueta;
  final IconData              icono;
  final bool                  oscuro;
  final TextInputType         teclado;
  final Widget?               sufijo;

  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.oscuro  = false,
    this.teclado = TextInputType.text,
    this.sufijo,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:   controlador,
    obscureText:  oscuro,
    keyboardType: teclado,
    style: const TextStyle(
        fontSize: 15, color: AppColores.textPrimary),
    decoration: InputDecoration(
      labelText:  etiqueta,
      labelStyle: const TextStyle(
          color: AppColores.textSecond, fontSize: 14),
      prefixIcon: Icon(icono, color: AppColores.primary, size: 20),
      suffixIcon: sufijo,
      filled:     true,
      fillColor:  AppColores.background,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColores.primary, width: 1.5)),
    ),
  );
}