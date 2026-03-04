import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
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
                  empresa:  lista[i],
                  onEditar: () => _form(context, ref, empresa: lista[i]),
                ),
              ),
      ),
    );
  }
void _form(BuildContext ctx, WidgetRef ref, {EmpresaAdmin? empresa}) {
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

}

// ── Card de empresa ────────────────────────────────────────
class _EmpresaCard extends StatelessWidget {
  final EmpresaAdmin empresa;
  final VoidCallback onEditar;
  const _EmpresaCard({required this.empresa, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        AppColores.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🏢', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(empresa.nombre, style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColores.textPrimary,
                    )),
                    const SizedBox(width: 8),
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
                  ],
                ),
                if (empresa.direccion != null)
                  Text(empresa.direccion!, style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
                if (empresa.telefono != null)
                  Text(empresa.telefono!, style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
              ],
            ),
          ),
          IconButton(
            icon:      const Icon(Icons.edit_outlined,
                color: AppColores.textSecond),
            onPressed: onEditar,
          ),
        ],
      ),
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
  late final _nombreCtrl =
      TextEditingController(text: widget.empresa?.nombre);
  late final _dirCtrl    =
      TextEditingController(text: widget.empresa?.direccion);
  late final _teleCtrl   =
      TextEditingController(text: widget.empresa?.telefono);
  bool _estaActiva = true;
  bool _cargando   = false;

  @override
  void initState() {
    super.initState();
    if (widget.empresa != null) _estaActiva = widget.empresa!.estaActiva;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _teleCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _cargando = true);
    await widget.onGuardar({
      'nombre':      _nombreCtrl.text.trim(),
      'direccion':   _dirCtrl.text.trim().isEmpty
          ? null : _dirCtrl.text.trim(),
      'telefono':    _teleCtrl.text.trim().isEmpty
          ? null : _teleCtrl.text.trim(),
      'esta_activa': _estaActiva,
    });
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.empresa != null;
    return BottomForm(                          // ← sin guion bajo
      titulo:    esEdicion ? 'Editar Empresa' : 'Nueva Empresa',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear empresa',
      children: [
        AdminInput(                             // ← sin guion bajo
          ctrl:   _nombreCtrl,
          label:  'Nombre *',
          icono:  Icons.business_outlined,
        ),
        const SizedBox(height: 12),
        AdminInput(
          ctrl:   _dirCtrl,
          label:  'Dirección',
          icono:  Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        AdminInput(
          ctrl:    _teleCtrl,
          label:   'Teléfono',
          icono:   Icons.phone_outlined,
          teclado: TextInputType.phone,
        ),
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
      ],
    );
  }
}