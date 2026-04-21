import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/colores.dart';
import '../../../../../core/network/api_client.dart';
import '../../../shared/widgets/bottom_sheet_wrapper.dart';
import '../../../shared/widgets/campo_texto.dart';
import '../../../shared/widgets/boton_primario.dart';

class CambiarContrasenaSheet extends ConsumerStatefulWidget {
  const CambiarContrasenaSheet({super.key});

  @override
  ConsumerState<CambiarContrasenaSheet> createState() =>
      _CambiarContrasenaSheetState();
}

class _CambiarContrasenaSheetState
    extends ConsumerState<CambiarContrasenaSheet> {
  final _actualCtrl   = TextEditingController();
  final _nuevaCtrl    = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool    _guardando   = false;
  bool    _verActual   = false;
  bool    _verNueva    = false;
  bool    _verConfirma = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    final actual   = _actualCtrl.text.trim();
    final nueva    = _nuevaCtrl.text.trim();
    final confirma = _confirmaCtrl.text.trim();

    if (actual.isEmpty || nueva.isEmpty || confirma.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (nueva.length < 6) {
      setState(() => _error =
          'La contraseña nueva debe tener al menos 6 caracteres');
      return;
    }
    if (nueva != confirma) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden');
      return;
    }

    setState(() { _guardando = true; _error = null; });
    try {
      await ApiClient.put('/vendedores/mi-perfil/contrasena', data: {
        'contrasena_actual': actual,
        'contrasena_nueva':  nueva,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('✅ Contraseña actualizada correctamente'),
          backgroundColor: AppColores.success,
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('400')
            ? 'La contraseña actual es incorrecta'
            : 'No se pudo cambiar la contraseña';
        _guardando = false;
      });
    }
  }

  Widget _toggleIcon(bool ver, VoidCallback onPressed) =>
      IconButton(
        icon: Icon(ver
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
            size: 20, color: AppColores.textSecond),
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context) => BottomSheetWrapper(
    titulo: 'Cambiar contraseña',
    child: Column(children: [
      CampoTexto(
        controlador: _actualCtrl,
        etiqueta:    'Contraseña actual',
        icono:       Icons.lock_outline_rounded,
        oscuro:      !_verActual,
        sufijo:      _toggleIcon(_verActual,
            () => setState(() => _verActual = !_verActual)),
      ),
      const SizedBox(height: 14),
      CampoTexto(
        controlador: _nuevaCtrl,
        etiqueta:    'Contraseña nueva',
        icono:       Icons.lock_reset_rounded,
        oscuro:      !_verNueva,
        sufijo:      _toggleIcon(_verNueva,
            () => setState(() => _verNueva = !_verNueva)),
      ),
      const SizedBox(height: 14),
      CampoTexto(
        controlador: _confirmaCtrl,
        etiqueta:    'Confirmar contraseña nueva',
        icono:       Icons.check_circle_outline_rounded,
        oscuro:      !_verConfirma,
        sufijo:      _toggleIcon(_verConfirma,
            () => setState(() => _verConfirma = !_verConfirma)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(
            color: AppColores.danger, fontSize: 13)),
      ],
      const SizedBox(height: 20),
      BotonPrimario(
        texto:     _guardando ? 'Guardando...' : 'Cambiar contraseña',
        cargando:  _guardando,
        onPressed: _guardando ? null : _cambiar,
      ),
    ]),
  );
}