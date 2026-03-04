// lib/features/admin/screens/admin_form_widgets.dart
import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';

class BottomForm extends StatelessWidget {
  final String       titulo;
  final bool         cargando;
  final VoidCallback onGuardar;
  final String       btnLabel;
  final List<Widget> children;
  const BottomForm({
    super.key,
    required this.titulo,
    required this.cargando,
    required this.onGuardar,
    required this.btnLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle visual
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(titulo, style: const TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      AppColores.textPrimary,
            )),
            const SizedBox(height: 20),
            ...children,
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: cargando ? null : onGuardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: cargando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                    : Text(btnLabel, style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                      )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final IconData              icono;
  final TextInputType         teclado;
  const AdminInput({
    super.key,
    required this.ctrl,
    required this.label,
    required this.icono,
    this.teclado = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   ctrl,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icono),
        border:     OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled:     true,
        fillColor:  AppColores.background,
      ),
    );
  }
}