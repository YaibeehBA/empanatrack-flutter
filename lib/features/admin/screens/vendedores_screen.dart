import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../providers/admin_provider.dart';
import 'admin_form_widgets.dart';

class VendedoresScreen extends ConsumerWidget {
  const VendedoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(vendedoresAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Vendedores',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(vendedoresAdminProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       () => _mostrarForm(context, ref),
        backgroundColor: AppColores.accent,
        foregroundColor: Colors.white,
        icon:            const Icon(Icons.person_add_outlined),
        label:           const Text('Nuevo Vendedor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error cargando vendedores'),
              TextButton(
                onPressed: () => ref.invalidate(vendedoresAdminProvider),
                child:     const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (lista) => lista.isEmpty
            ? const Center(
                child: Text('No hay vendedores registrados.',
                    style: TextStyle(color: AppColores.textSecond)),
              )
            : ListView.builder(
                padding:     const EdgeInsets.all(16),
                itemCount:   lista.length,
                itemBuilder: (ctx, i) => _VendedorCard(
                  vendedor:   lista[i],
                  onEditar:   () => _mostrarForm(context, ref,
                      vendedor: lista[i]),
                  onEliminar: () =>
                      _confirmarEliminar(context, ref, lista[i]),
                ),
              ),
      ),
    );
  }

  void _mostrarForm(BuildContext context, WidgetRef ref,
      {VendedorAdmin? vendedor}) {
    ref.read(adminOpProvider.notifier).resetear();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (modalCtx) => _FormVendedor(
        vendedor:  vendedor,
        onGuardar: (datos) async {
          if (vendedor == null) {
            await ref.read(adminOpProvider.notifier).crearVendedor(datos);
          } else {
            await ref.read(adminOpProvider.notifier)
                .editarVendedor(vendedor.id, datos);
          }
          final state = ref.read(adminOpProvider);
          if (state.error != null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:         Text(state.error!),
                backgroundColor: Colors.red,
              ));
            }
            return;
          }
          ref.invalidate(vendedoresAdminProvider);
          ref.invalidate(resumenAdminProvider);
          if (modalCtx.mounted) Navigator.pop(modalCtx);
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, VendedorAdmin vendedor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColores.danger),
          SizedBox(width: 8),
          Text('Eliminar vendedor'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(
                  color: AppColores.textPrimary, fontSize: 14),
              children: [
                const TextSpan(text: '¿Eliminar a '),
                TextSpan(
                  text: vendedor.nombreCompleto,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?'),
              ],
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColores.warning.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: AppColores.warning, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Si tiene ventas registradas no se podrá eliminar. '
                  'Desactívalo en su lugar.',
                  style: TextStyle(
                      fontSize: 12, color: AppColores.warning),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:     const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(adminOpProvider.notifier)
                  .eliminarVendedor(vendedor.id.toString());
              final state = ref.read(adminOpProvider);
              if (state.error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:         Text(state.error!),
                  backgroundColor: AppColores.danger,
                ));
                ref.read(adminOpProvider.notifier).resetear();
                return;
              }
              ref.invalidate(vendedoresAdminProvider);
              ref.invalidate(resumenAdminProvider);
              ref.read(adminOpProvider.notifier).resetear();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Card de vendedor ───────────────────────────────────────
class _VendedorCard extends StatelessWidget {
  final VendedorAdmin vendedor;
  final VoidCallback  onEditar;
  final VoidCallback  onEliminar;
  const _VendedorCard({
    required this.vendedor,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: vendedor.estaActivo
              ? AppColores.accent.withOpacity(0.12)
              : Colors.grey.shade100,
          child: Text(
            vendedor.nombreCompleto[0].toUpperCase(),
            style: TextStyle(
              color:      vendedor.estaActivo
                  ? AppColores.accent : AppColores.textSecond,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(vendedor.nombreCompleto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColores.textPrimary,
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: vendedor.estaActivo
                        ? AppColores.success.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vendedor.estaActivo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.bold,
                      color:      vendedor.estaActivo
                          ? AppColores.success
                          : AppColores.textSecond,
                    ),
                  ),
                ),
              ]),
              Text('@${vendedor.nombreUsuario}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
              if (vendedor.telefono != null)
                Text(vendedor.telefono!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond)),
            ],
          ),
        ),
        // Botones acción
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon:      const Icon(Icons.edit_outlined,
                color: AppColores.textSecond),
            onPressed: onEditar,
            tooltip:   'Editar',
          ),
          IconButton(
            icon:      const Icon(Icons.delete_outline,
                color: AppColores.danger),
            onPressed: onEliminar,
            tooltip:   'Eliminar',
          ),
        ]),
      ]),
    );
  }
}

// ── Formulario vendedor ────────────────────────────────────
class _FormVendedor extends StatefulWidget {
  final VendedorAdmin?                 vendedor;
  final Function(Map<String, dynamic>) onGuardar;
  const _FormVendedor({this.vendedor, required this.onGuardar});

  @override
  State<_FormVendedor> createState() => _FormVendedorState();
}

class _FormVendedorState extends State<_FormVendedor> {
  late final _nombreCtrl  =
      TextEditingController(text: widget.vendedor?.nombreCompleto);
  late final _teleCtrl    =
      TextEditingController(text: widget.vendedor?.telefono);
  late final _usuarioCtrl =
      TextEditingController(text: widget.vendedor?.nombreUsuario);
  late final _correoCtrl  =
      TextEditingController(text: widget.vendedor?.correo);
  final _contraCtrl = TextEditingController();

  bool  _estaActivo  = true;
  bool  _verContra   = false;
  bool  _cargando    = false;
  bool? _telefonoOk;

  @override
  void initState() {
    super.initState();
    if (widget.vendedor != null) {
      _estaActivo = widget.vendedor!.estaActivo;
      final t = widget.vendedor?.telefono ?? '';
      if (t.isNotEmpty) {
        _telefonoOk = Validators.telefonoEcuador(t) == null;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _teleCtrl.dispose();
    _usuarioCtrl.dispose(); _correoCtrl.dispose();
    _contraCtrl.dispose(); super.dispose();
  }

  void _onTelefonoChange(String v) {
    if (v.isEmpty) { setState(() => _telefonoOk = null); return; }
    setState(() => _telefonoOk = Validators.telefonoEcuador(v) == null);
  }

  Color _borderColor(bool? ok) {
    if (ok == null) return Colors.grey.shade300;
    return ok ? AppColores.success : AppColores.danger;
  }

  Color _fillColor(bool? ok) {
    if (ok == null) return AppColores.background;
    return ok
        ? AppColores.success.withOpacity(0.05)
        : AppColores.danger.withOpacity(0.05);
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    if (_teleCtrl.text.trim().isNotEmpty &&
        Validators.telefonoEcuador(_teleCtrl.text.trim()) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('El teléfono no es válido'),
        backgroundColor: AppColores.danger,
      ));
      return;
    }
    final esNuevo = widget.vendedor == null;
    if (esNuevo && _usuarioCtrl.text.trim().isEmpty) return;
    if (esNuevo && _contraCtrl.text.isEmpty) return;

    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'nombre_completo': _nombreCtrl.text.trim(),
      'telefono':        _teleCtrl.text.trim().isEmpty
          ? null : _teleCtrl.text.trim(),
      'esta_activo':     _estaActivo,
    };
    if (esNuevo) {
      datos['nombre_usuario'] = _usuarioCtrl.text.trim();
      datos['contrasena']     = _contraCtrl.text;
      datos['correo']         = _correoCtrl.text.trim().isEmpty
          ? null : _correoCtrl.text.trim();
    }
    if (!esNuevo && _contraCtrl.text.isNotEmpty) {
      datos['nueva_contrasena'] = _contraCtrl.text;
    }
    await widget.onGuardar(datos);
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.vendedor != null;
    return BottomForm(
      titulo:    esEdicion ? 'Editar Vendedor' : 'Nuevo Vendedor',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear vendedor',
      children: [
        AdminInput(
          ctrl:  _nombreCtrl,
          label: 'Nombre completo *',
          icono: Icons.person_outline,
        ),
        const SizedBox(height: 12),

        // Teléfono con validación en tiempo real
        TextFormField(
          controller:  _teleCtrl,
          keyboardType: TextInputType.number,
          maxLength:   10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: _onTelefonoChange,
          decoration: InputDecoration(
            labelText:   'Teléfono',
            prefixIcon:  const Icon(Icons.phone_outlined),
            counterText: '',
            suffixIcon: _telefonoOk == null
                ? null
                : Icon(
                    _telefonoOk!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _telefonoOk!
                        ? AppColores.success : AppColores.danger,
                  ),
            filled:    true,
            fillColor: _fillColor(_telefonoOk),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _borderColor(_telefonoOk), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _telefonoOk == null
                    ? AppColores.primary
                    : _borderColor(_telefonoOk),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColores.danger, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColores.danger, width: 2),
            ),
          ),
        ),
        if (_telefonoOk == false)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: const Text('Debe tener 10 dígitos numéricos',
                style: TextStyle(
                    fontSize: 12, color: AppColores.danger)),
          ),
        const SizedBox(height: 12),

        if (!esEdicion) ...[
          AdminInput(
            ctrl:  _usuarioCtrl,
            label: 'Usuario *',
            icono: Icons.alternate_email,
          ),
          const SizedBox(height: 12),
          AdminInput(
            ctrl:    _correoCtrl,
            label:   'Correo',
            icono:   Icons.email_outlined,
            teclado: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
        ],

        TextField(
          controller:  _contraCtrl,
          obscureText: !_verContra,
          decoration: InputDecoration(
            labelText:  esEdicion
                ? 'Nueva contraseña (opcional)'
                : 'Contraseña *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_verContra
                  ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _verContra = !_verContra),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            filled:    true,
            fillColor: AppColores.background,
          ),
        ),

        if (esEdicion) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value:          _estaActivo,
            onChanged:      (v) => setState(() => _estaActivo = v),
            title:          const Text('Vendedor activo'),
            subtitle: const Text(
                'Los inactivos no pueden iniciar sesión'),
            activeColor:    AppColores.success,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}