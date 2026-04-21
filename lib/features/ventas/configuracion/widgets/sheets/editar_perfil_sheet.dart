import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/colores.dart';
import '../../../../../core/network/api_client.dart';
import '../../../shared/widgets/bottom_sheet_wrapper.dart';
import '../../../shared/widgets/campo_texto.dart';
import '../../../shared/widgets/boton_primario.dart';
import '../../perfil_provider.dart';

class EditarPerfilSheet extends ConsumerStatefulWidget {
  final PerfilVendedor perfil;
  const EditarPerfilSheet({super.key, required this.perfil});

  @override
  ConsumerState<EditarPerfilSheet> createState() =>
      _EditarPerfilSheetState();
}

class _EditarPerfilSheetState
    extends ConsumerState<EditarPerfilSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  bool    _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.perfil.nombre);
    _telefonoCtrl = TextEditingController(
        text: widget.perfil.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre   = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre no puede estar vacío');
      return;
    }
    setState(() { _guardando = true; _error = null; });
    try {
      await ApiClient.put('/vendedores/mi-perfil', data: {
        'nombre':   nombre,
        'telefono': telefono.isEmpty ? null : telefono,
      });
      ref.invalidate(perfilVendedorProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('✅ Perfil actualizado correctamente'),
          backgroundColor: AppColores.success,
        ));
      }
    } catch (_) {
      setState(() {
        _error     = 'No se pudo actualizar el perfil';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => BottomSheetWrapper(
    titulo: 'Editar perfil',
    child: Column(children: [
      CampoTexto(
        controlador: _nombreCtrl,
        etiqueta:    'Nombre completo',
        icono:       Icons.person_outline_rounded,
        teclado:     TextInputType.name,
      ),
      const SizedBox(height: 14),
      CampoTexto(
        controlador: _telefonoCtrl,
        etiqueta:    'Teléfono (opcional)',
        icono:       Icons.phone_outlined,
        teclado:     TextInputType.phone,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(
            color: AppColores.danger, fontSize: 13)),
      ],
      const SizedBox(height: 20),
      BotonPrimario(
        texto:     _guardando ? 'Guardando...' : 'Guardar cambios',
        cargando:  _guardando,
        onPressed: _guardando ? null : _guardar,
      ),
    ]),
  );
}