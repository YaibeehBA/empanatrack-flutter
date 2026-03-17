import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../../clientes/providers/registro_cliente_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_form_widgets.dart';

class EmpresasScreen extends ConsumerWidget {
  const EmpresasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(empresasAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Empresas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       () => _form(context, ref),
        backgroundColor: AppColores.warning,
        foregroundColor: Colors.white,
        icon:            const Icon(Icons.add_business_outlined),
        label:           const Text('Nueva Empresa',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => const Center(child: Text('Error cargando')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('No hay empresas registradas.'))
            : ListView.builder(
                padding:     const EdgeInsets.all(16),
                itemCount:   lista.length,
                itemBuilder: (ctx, i) => _EmpresaCard(
                  empresa:    lista[i],
                  onEditar:   () => _form(context, ref,
                      empresa: lista[i]),
                  onEliminar: () =>
                      _confirmarEliminar(context, ref, lista[i]),
                ),
              ),
      ),
    );
  }

  void _form(BuildContext ctx, WidgetRef ref,
      {EmpresaAdmin? empresa}) {
    ref.read(adminOpProvider.notifier).resetear();
    showModalBottomSheet(
      context:            ctx,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (modalCtx) => _FormEmpresa(
        empresa:   empresa,
        onGuardar: (datos) async {
          if (empresa == null) {
            await ref.read(adminOpProvider.notifier).crearEmpresa(datos);
          } else {
            await ref.read(adminOpProvider.notifier)
                .editarEmpresa(empresa.id, datos);
          }
          final state = ref.read(adminOpProvider);
          if (state.error != null) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content:         Text(state.error!),
                backgroundColor: Colors.red,
              ));
            }
            return;
          }
          ref.invalidate(empresasAdminProvider);
          ref.invalidate(empresasProvider);
          if (modalCtx.mounted) Navigator.pop(modalCtx);
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, EmpresaAdmin empresa) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColores.danger),
          SizedBox(width: 8),
          Text('Eliminar empresa'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(
                  color: AppColores.textPrimary, fontSize: 14),
              children: [
                const TextSpan(text: '¿Eliminar '),
                TextSpan(
                  text: empresa.nombre,
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
                  'Si tiene clientes asociados no se podrá eliminar. '
                  'Desactívala en su lugar.',
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
                  .eliminarEmpresa(empresa.id.toString());
              final state = ref.read(adminOpProvider);
              if (state.error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:         Text(state.error!),
                  backgroundColor: AppColores.danger,
                ));
                ref.read(adminOpProvider.notifier).resetear();
                return;
              }
              ref.invalidate(empresasAdminProvider);
              ref.invalidate(empresasProvider);
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

// ── Card de empresa ────────────────────────────────────────
class _EmpresaCard extends StatelessWidget {
  final EmpresaAdmin empresa;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  const _EmpresaCard({
    required this.empresa,
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
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        AppColores.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
              child: Text('🏢', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(empresa.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColores.textPrimary,
                      )),
                ),
                if (!empresa.estaActiva)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Inactiva',
                        style: TextStyle(
                            fontSize: 10,
                            color:    AppColores.textSecond)),
                  ),
              ]),
              if (empresa.direccion != null)
                Text(empresa.direccion!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textSecond)),
              if (empresa.telefono != null)
                Text(empresa.telefono!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textSecond)),
              if (empresa.latitud != null && empresa.longitud != null)
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 12, color: AppColores.success),
                  const SizedBox(width: 4),
                  Text(
                    '${empresa.latitud!.toStringAsFixed(4)}, '
                    '${empresa.longitud!.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColores.success),
                  ),
                ]),
            ],
          ),
        ),
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

// ── Formulario empresa ─────────────────────────────────────
class _FormEmpresa extends StatefulWidget {
  final EmpresaAdmin?                  empresa;
  final Function(Map<String, dynamic>) onGuardar;
  const _FormEmpresa({this.empresa, required this.onGuardar});

  @override
  State<_FormEmpresa> createState() => _FormEmpresaState();
}

class _FormEmpresaState extends State<_FormEmpresa> {
  late final _nombreCtrl = TextEditingController(
      text: widget.empresa?.nombre);
  late final _dirCtrl    = TextEditingController(
      text: widget.empresa?.direccion);
  late final _teleCtrl   = TextEditingController(
      text: widget.empresa?.telefono);
  late final _latCtrl    = TextEditingController(
      text: widget.empresa?.latitud?.toString() ?? '');
  late final _lngCtrl    = TextEditingController(
      text: widget.empresa?.longitud?.toString() ?? '');

  final _formKey   = GlobalKey<FormState>();
  bool  _estaActiva = true;
  bool  _cargando   = false;
  bool? _telefonoOk;
  bool? _latitudOk;
  bool? _longitudOk;

  @override
  void initState() {
    super.initState();
    if (widget.empresa != null) {
      _estaActiva = widget.empresa!.estaActiva;
      final t = widget.empresa?.telefono ?? '';
      if (t.isNotEmpty) {
        _telefonoOk = Validators.telefonoEcuador(t) == null;
      }
      final lat = widget.empresa?.latitud?.toString() ?? '';
      if (lat.isNotEmpty) {
        _latitudOk = Validators.latitud(lat) == null;
      }
      final lng = widget.empresa?.longitud?.toString() ?? '';
      if (lng.isNotEmpty) {
        _longitudOk = Validators.longitud(lng) == null;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _dirCtrl.dispose();
    _teleCtrl.dispose();   _latCtrl.dispose();
    _lngCtrl.dispose();    super.dispose();
  }

  void _onTelefonoChange(String v) {
    if (v.isEmpty) { setState(() => _telefonoOk = null); return; }
    setState(() => _telefonoOk = Validators.telefonoEcuador(v) == null);
  }

  void _onLatitudChange(String v) {
    if (v.isEmpty) { setState(() => _latitudOk = null); return; }
    setState(() => _latitudOk = Validators.latitud(v) == null);
  }

  void _onLongitudChange(String v) {
    if (v.isEmpty) { setState(() => _longitudOk = null); return; }
    setState(() => _longitudOk = Validators.longitud(v) == null);
  }

  Color _borde(bool? ok) {
    if (ok == null) return Colors.grey.shade300;
    return ok ? AppColores.success : AppColores.danger;
  }

  Color _fondo(bool? ok) {
    if (ok == null) return AppColores.background;
    return ok
        ? AppColores.success.withOpacity(0.05)
        : AppColores.danger.withOpacity(0.05);
  }

  Widget? _icono(bool? ok) {
    if (ok == null) return null;
    return Icon(
      ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: ok ? AppColores.success : AppColores.danger,
      size: 20,
    );
  }

  InputDecoration _deco({
    required String   label,
    required IconData prefixIcono,
    bool?    ok,
    String?  hint,
  }) =>
      InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(prefixIcono),
        suffixIcon: _icono(ok),
        filled:     true,
        fillColor:  _fondo(ok),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: _borde(ok), width: ok != null ? 2 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ok == null ? AppColores.primary : _borde(ok),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColores.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColores.danger, width: 2),
        ),
      );

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _cargando = true);
    await widget.onGuardar({
      'nombre':      _nombreCtrl.text.trim(),
      'direccion':   _dirCtrl.text.trim().isEmpty
          ? null : _dirCtrl.text.trim(),
      'telefono':    _teleCtrl.text.trim().isEmpty
          ? null : _teleCtrl.text.trim(),
      'latitud':     _latCtrl.text.trim().isEmpty
          ? null : double.tryParse(_latCtrl.text.trim()),
      'longitud':    _lngCtrl.text.trim().isEmpty
          ? null : double.tryParse(_lngCtrl.text.trim()),
      'esta_activa': _estaActiva,
    });
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.empresa != null;
    return BottomForm(
      titulo:    esEdicion ? 'Editar Empresa' : 'Nueva Empresa',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear empresa',
      children: [
        Form(
          key: _formKey,
          child: Column(children: [

            // Nombre
            TextFormField(
              controller: _nombreCtrl,
              decoration: _deco(
                  label:       'Nombre *',
                  prefixIcono: Icons.business_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Dirección
            TextFormField(
              controller: _dirCtrl,
              decoration: _deco(
                  label:       'Dirección',
                  prefixIcono: Icons.location_on_outlined),
            ),
            const SizedBox(height: 12),

            // Teléfono
            TextFormField(
              controller:  _teleCtrl,
              keyboardType: TextInputType.number,
              maxLength:   10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: _onTelefonoChange,
              decoration: _deco(
                label:       'Teléfono',
                prefixIcono: Icons.phone_outlined,
                ok:          _telefonoOk,
              ).copyWith(counterText: ''),
              validator: (v) => Validators.telefonoEcuador(v),
            ),
            const SizedBox(height: 12),

            // Separador GPS
            Row(children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Coordenadas GPS (opcional)',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ]),
            const SizedBox(height: 12),

            // Latitud
            TextFormField(
              controller: _latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*')),
              ],
              onChanged: _onLatitudChange,
              decoration: _deco(
                label:       'Latitud (-90 a 90)',
                prefixIcono: Icons.swap_vert,
                ok:          _latitudOk,
              ),
              validator: (v) => Validators.latitud(v),
            ),
            const SizedBox(height: 12),

            // Longitud
            TextFormField(
              controller: _lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*')),
              ],
              onChanged: _onLongitudChange,
              decoration: _deco(
                label:       'Longitud (-180 a 180)',
                prefixIcono: Icons.swap_horiz,
                ok:          _longitudOk,
              ),
              validator: (v) => Validators.longitud(v),
            ),

            // Switch activa
            if (esEdicion) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                value:          _estaActiva,
                onChanged:      (v) => setState(() => _estaActiva = v),
                title:          const Text('Empresa activa'),
                activeColor:    AppColores.success,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ]),
        ),
      ],
    );
  }
}