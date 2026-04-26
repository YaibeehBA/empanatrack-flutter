import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../providers/admin_provider.dart';
import 'admin_form_widgets.dart';

class RepartidoresScreen extends ConsumerWidget {
  const RepartidoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(repartidoresAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Repartidores',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(repartidoresAdminProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag:         'fab_repartidor',
        onPressed:       () => _mostrarForm(context, ref),
        backgroundColor: AppColores.accent,
        foregroundColor: Colors.white,
        icon:  const Icon(Icons.delivery_dining_outlined),
        label: const Text('Nuevo Repartidor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listaAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error cargando repartidores'),
            TextButton(
              onPressed: () =>
                  ref.invalidate(repartidoresAdminProvider),
              child: const Text('Reintentar'),
            ),
          ],
        )),
        data: (lista) => lista.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🛵', style: TextStyle(fontSize: 52)),
                    SizedBox(height: 16),
                    Text('No hay repartidores registrados.',
                        style: TextStyle(
                            color:    AppColores.textSecond,
                            fontSize: 15)),
                    SizedBox(height: 8),
                    Text('Crea uno con el botón de abajo.',
                        style: TextStyle(
                            color:    AppColores.textSecond,
                            fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                padding:     const EdgeInsets.all(16),
                itemCount:   lista.length,
                itemBuilder: (ctx, i) => _RepartidorCard(
                  repartidor: lista[i],
                  onEditar:   () => _mostrarForm(
                      context, ref, repartidor: lista[i]),
                  onEliminar: () =>
                      _confirmarEliminar(context, ref, lista[i]),
                ),
              ),
      ),
    );
  }

  void _mostrarForm(BuildContext context, WidgetRef ref,
      {RepartidorAdmin? repartidor}) {
    ref.read(adminOpProvider.notifier).resetear();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (modalCtx) => _FormRepartidor(
        repartidor: repartidor,
        onGuardar:  (datos) async {
          if (repartidor == null) {
            await ref
                .read(adminOpProvider.notifier)
                .crearRepartidor(datos);
          } else {
            await ref
                .read(adminOpProvider.notifier)
                .editarRepartidor(repartidor.id, datos);
          }
          final state = ref.read(adminOpProvider);
          if (state.error != null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:         Text(state.error!),
                backgroundColor: AppColores.danger,
              ));
            }
            return;
          }
          ref.invalidate(repartidoresAdminProvider);
          if (modalCtx.mounted) Navigator.pop(modalCtx);
        },
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref,
      RepartidorAdmin repartidor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColores.danger),
          SizedBox(width: 8),
          Text('Eliminar repartidor'),
        ]),
        content: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(
                  color: AppColores.textPrimary, fontSize: 14),
              children: [
                const TextSpan(text: '¿Eliminar a '),
                TextSpan(
                  text: repartidor.nombreCompleto,
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
                  'Si tiene pedidos registrados no se podrá '
                  'eliminar. Desactívalo en su lugar.',
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
              await ref
                  .read(adminOpProvider.notifier)
                  .eliminarRepartidor(repartidor.id);
              final state = ref.read(adminOpProvider);
              if (state.error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:         Text(state.error!),
                  backgroundColor: AppColores.danger,
                ));
                ref.read(adminOpProvider.notifier).resetear();
                return;
              }
              ref.invalidate(repartidoresAdminProvider);
              ref.read(adminOpProvider.notifier).resetear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD REPARTIDOR
// ══════════════════════════════════════════════════════════
class _RepartidorCard extends StatelessWidget {
  final RepartidorAdmin repartidor;
  final VoidCallback    onEditar;
  final VoidCallback    onEliminar;

  const _RepartidorCard({
    required this.repartidor,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color:      Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2))],
    ),
    child: Row(children: [

      // Avatar
      Container(
        width:  44, height: 44,
        decoration: BoxDecoration(
          color: repartidor.estaActivo
              ? AppColores.accent.withOpacity(0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(
          repartidor.nombreCompleto[0].toUpperCase(),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   18,
              color: repartidor.estaActivo
                  ? AppColores.accent : AppColores.textSecond),
        )),
      ),
      const SizedBox(width: 12),

      // Info
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(
              repartidor.nombreCompleto,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary),
            )),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: repartidor.estaActivo
                    ? AppColores.success.withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                repartidor.estaActivo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.bold,
                    color: repartidor.estaActivo
                        ? AppColores.success
                        : AppColores.textSecond),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text('@${repartidor.nombreUsuario}',
              style: const TextStyle(
                  fontSize: 12, color: AppColores.textSecond)),
          if (repartidor.telefono != null)
            Row(children: [
              const Icon(Icons.phone_outlined,
                  size: 11, color: AppColores.textSecond),
              const SizedBox(width: 4),
              Text(repartidor.telefono!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
            ]),
          if (repartidor.correo != null)
            Row(children: [
              const Icon(Icons.email_outlined,
                  size: 11, color: AppColores.textSecond),
              const SizedBox(width: 4),
              Text(repartidor.correo!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond),
                  overflow: TextOverflow.ellipsis),
            ]),
        ],
      )),

      // Acciones
      Column(mainAxisSize: MainAxisSize.min, children: [
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

// ══════════════════════════════════════════════════════════
//  FORMULARIO REPARTIDOR
//  Reutiliza exactamente el mismo patrón que _FormVendedor
// ══════════════════════════════════════════════════════════
class _FormRepartidor extends StatefulWidget {
  final RepartidorAdmin?               repartidor;
  final Function(Map<String, dynamic>) onGuardar;

  const _FormRepartidor({
    this.repartidor,
    required this.onGuardar,
  });

  @override
  State<_FormRepartidor> createState() => _FormRepartidorState();
}

class _FormRepartidorState extends State<_FormRepartidor> {
  late final _nombreCtrl  = TextEditingController(
      text: widget.repartidor?.nombreCompleto);
  late final _teleCtrl    = TextEditingController(
      text: widget.repartidor?.telefono);
  late final _usuarioCtrl = TextEditingController(
      text: widget.repartidor?.nombreUsuario);
  late final _correoCtrl  = TextEditingController(
      text: widget.repartidor?.correo);
  final _contraCtrl = TextEditingController();

  bool  _estaActivo = true;
  bool  _verContra  = false;
  bool  _cargando   = false;
  bool? _telefonoOk;

  @override
  void initState() {
    super.initState();
    if (widget.repartidor != null) {
      _estaActivo = widget.repartidor!.estaActivo;
      final t = widget.repartidor?.telefono ?? '';
      if (t.isNotEmpty) {
        _telefonoOk = Validators.telefonoEcuador(t) == null;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();  _teleCtrl.dispose();
    _usuarioCtrl.dispose(); _correoCtrl.dispose();
    _contraCtrl.dispose();
    super.dispose();
  }

  void _onTelefonoChange(String v) {
    if (v.isEmpty) {
      setState(() => _telefonoOk = null);
      return;
    }
    setState(() =>
        _telefonoOk = Validators.telefonoEcuador(v) == null);
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
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('El nombre es obligatorio'),
        backgroundColor: AppColores.danger,
      ));
      return;
    }
    if (_teleCtrl.text.trim().isNotEmpty &&
        Validators.telefonoEcuador(_teleCtrl.text.trim()) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('El teléfono no es válido'),
        backgroundColor: AppColores.danger,
      ));
      return;
    }
    final esNuevo = widget.repartidor == null;
    if (esNuevo && _usuarioCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('El usuario es obligatorio'),
        backgroundColor: AppColores.danger,
      ));
      return;
    }
    if (esNuevo && _contraCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('La contraseña es obligatoria'),
        backgroundColor: AppColores.danger,
      ));
      return;
    }

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
    final esEdicion = widget.repartidor != null;
    return BottomForm(
      titulo:    esEdicion ? 'Editar Repartidor' : 'Nuevo Repartidor',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear repartidor',
      children: [

        AdminInput(
          ctrl:  _nombreCtrl,
          label: 'Nombre completo *',
          icono: Icons.person_outline,
        ),
        const SizedBox(height: 12),

        // Teléfono con validación en tiempo real
        TextFormField(
          controller:   _teleCtrl,
          keyboardType: TextInputType.number,
          maxLength:    10,
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
          ),
        ),
        if (_telefonoOk == false)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 12),
            child:   Text('Debe tener 10 dígitos numéricos',
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
        const SizedBox(height: 4),

        if (esEdicion) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value:     _estaActivo,
            onChanged: (v) => setState(() => _estaActivo = v),
            title: const Text('Repartidor activo'),
            subtitle: const Text(
                'Los inactivos no pueden iniciar sesión '
                'ni recibir pedidos'),
            activeColor:    AppColores.success,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}