import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
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
        error:   (e, _) => Center(
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
                  vendedor: lista[i],
                  onEditar: () =>
                      _mostrarForm(context, ref, vendedor: lista[i]),
                ),
              ),
      ),
    );
  }

  void _mostrarForm(BuildContext context, WidgetRef ref,
    {VendedorAdmin? vendedor}) {
  // Resetear estado antes de abrir
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
          return; // No cerrar si hubo error
        }
        ref.invalidate(vendedoresAdminProvider);
        ref.invalidate(resumenAdminProvider);
        if (modalCtx.mounted) Navigator.pop(modalCtx);
      },
    ),
  );
}
}

// ── Card de vendedor ───────────────────────────────────────
class _VendedorCard extends StatelessWidget {
  final VendedorAdmin vendedor;
  final VoidCallback  onEditar;
  const _VendedorCard({required this.vendedor, required this.onEditar});

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
          CircleAvatar(
            backgroundColor: vendedor.estaActivo
                ? AppColores.accent.withOpacity(0.12)
                : Colors.grey.shade100,
            child: Text(
              vendedor.nombreCompleto[0].toUpperCase(),
              style: TextStyle(
                color:      vendedor.estaActivo
                    ? AppColores.accent
                    : AppColores.textSecond,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                        color:        vendedor.estaActivo
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
                  ],
                ),
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
  bool _estaActivo  = true;
  bool _verContra   = false;
  bool _cargando    = false;

  @override
  void initState() {
    super.initState();
    if (widget.vendedor != null) _estaActivo = widget.vendedor!.estaActivo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _teleCtrl.dispose();
    _usuarioCtrl.dispose();
    _correoCtrl.dispose();
    _contraCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
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
    return BottomForm(                          // ← sin guion bajo
      titulo:    esEdicion ? 'Editar Vendedor' : 'Nuevo Vendedor',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear vendedor',
      children: [
        AdminInput(                             // ← sin guion bajo
          ctrl:  _nombreCtrl,
          label: 'Nombre completo *',
          icono: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        AdminInput(
          ctrl:    _teleCtrl,
          label:   'Teléfono',
          icono:   Icons.phone_outlined,
          teclado: TextInputType.phone,
        ),
        const SizedBox(height: 12),

        // Campos solo para nuevo vendedor
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

        // Contraseña
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
            border:     OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled:     true,
            fillColor:  AppColores.background,
          ),
        ),

        // Toggle activo solo en edición
        if (esEdicion) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value:          _estaActivo,
            onChanged:      (v) => setState(() => _estaActivo = v),
            title:          const Text('Vendedor activo'),
            subtitle:       const Text(
                'Los inactivos no pueden iniciar sesión'),
            activeColor:    AppColores.success,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}