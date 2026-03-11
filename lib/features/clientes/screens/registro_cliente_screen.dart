// lib/features/clientes/screens/registro_cliente_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../providers/registro_cliente_provider.dart';
import '../providers/clientes_provider.dart';
import '../../../shared/models/empresa_model.dart';

class RegistroClienteScreen extends ConsumerStatefulWidget {
  final bool desdeNuevaVenta;
  const RegistroClienteScreen({super.key, this.desdeNuevaVenta = false});

  @override
  ConsumerState<RegistroClienteScreen> createState() =>
      _RegistroClienteScreenState();
}

class _RegistroClienteScreenState
    extends ConsumerState<RegistroClienteScreen> {

  final _cedulaCtrl   = TextEditingController();
  final _nombreCtrl   = TextEditingController();
  final _correoCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _usuarioCtrl  = TextEditingController();
  final _contraCtrl   = TextEditingController();

  EmpresaModel? _empresaSelec;
  bool          _crearAccesoApp = false;
  bool          _verContrasena  = false;
  int           _paso           = 1;

  final _formKeyPaso1 = GlobalKey<FormState>();
  final _formKeyPaso3 = GlobalKey<FormState>();

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _usuarioCtrl.dispose();
    _contraCtrl.dispose();
    super.dispose();
  }

  bool _validarPaso1() {
    return _formKeyPaso1.currentState!.validate();
  }

  Future<void> _registrar() async {
    if (_crearAccesoApp) {
      if (!_formKeyPaso3.currentState!.validate()) return;
    }
    await ref.read(registroClienteProvider.notifier).registrar(
      cedula:        _cedulaCtrl.text.trim(),
      nombre:        _nombreCtrl.text.trim(),
      correo:        _correoCtrl.text.trim().isEmpty
          ? null : _correoCtrl.text.trim(),
      telefono:      _telefonoCtrl.text.trim().isEmpty
          ? null : _telefonoCtrl.text.trim(),
      empresaId:     _empresaSelec?.id,
      nombreUsuario: _crearAccesoApp ? _usuarioCtrl.text.trim() : null,
      contrasena:    _crearAccesoApp ? _contraCtrl.text : null,
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColores.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registroClienteProvider);

    ref.listen<RegistroClienteState>(registroClienteProvider, (prev, next) {
      if (next.clienteCreado != null) {
        ref.invalidate(clientesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${next.clienteCreado!.nombre} registrado correctamente'
              '${_crearAccesoApp ? " con acceso a la app" : ""}',
            ),
            backgroundColor: AppColores.success,
          ),
        );
        if (widget.desdeNuevaVenta) {
          context.pop(next.clienteCreado);
        } else {
          context.pop();
        }
      }
      if (next.error != null) _mostrarError(next.error!);
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Nuevo Cliente',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: _BottomBar(
        paso:     _paso,
        cargando: state.cargando,
        onAnterior:  () => setState(() => _paso--),
        onSiguiente: () {
          if (_paso == 1) {
            if (_validarPaso1()) setState(() => _paso++);
          } else if (_paso == 2) {
            setState(() => _paso++);
          } else {
            _registrar();
          }
        },
      ),
      body: Column(
        children: [
          _IndicadorPasos(pasoActual: _paso),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _paso == 1
                    ? _Paso1DatosBasicos(
                        key:          const ValueKey(1),
                        formKey:      _formKeyPaso1,
                        cedulaCtrl:   _cedulaCtrl,
                        nombreCtrl:   _nombreCtrl,
                        correoCtrl:   _correoCtrl,
                        telefonoCtrl: _telefonoCtrl,
                      )
                    : _paso == 2
                        ? _Paso2Empresa(
                            key:          const ValueKey(2),
                            empresaSelec: _empresaSelec,
                            onSelec: (e) =>
                                setState(() => _empresaSelec = e),
                          )
                        : _Paso3Acceso(
                            key:            const ValueKey(3),
                            formKey:        _formKeyPaso3,
                            crearAcceso:    _crearAccesoApp,
                            verContrasena:  _verContrasena,
                            usuarioCtrl:    _usuarioCtrl,
                            contraCtrl:     _contraCtrl,
                            sugerirUsuario: _nombreCtrl.text.trim()
                                .split(' ').first.toLowerCase(),
                            onToggleAcceso: (v) =>
                                setState(() => _crearAccesoApp = v),
                            onToggleVer: () => setState(
                                () => _verContrasena = !_verContrasena),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  INDICADOR DE PASOS
// ══════════════════════════════════════════════════════════
class _IndicadorPasos extends StatelessWidget {
  final int pasoActual;
  const _IndicadorPasos({required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    final pasos = ['Datos', 'Empresa', 'Acceso app'];
    return Container(
      color:   AppColores.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(pasos.length, (i) {
          final num    = i + 1;
          final activo = pasoActual == num;
          final hecho  = pasoActual > num;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: hecho
                        ? AppColores.success
                        : activo ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: hecho
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : Text('$num',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:   13,
                              color: activo
                                  ? AppColores.primary
                                  : Colors.white54,
                            )),
                  ),
                ),
                const SizedBox(width: 6),
                Text(pasos[i],
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: activo
                          ? FontWeight.bold : FontWeight.normal,
                      color: activo ? Colors.white : Colors.white54,
                    )),
                if (i < pasos.length - 1) ...[
                  const SizedBox(width: 6),
                  Expanded(
                      child: Container(height: 1, color: Colors.white24)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 1 — cada campo valida solo cuando el usuario
//  interactúa CON ÉL, no con otros campos
// ══════════════════════════════════════════════════════════
class _Paso1DatosBasicos extends StatefulWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController cedulaCtrl;
  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController telefonoCtrl;

  const _Paso1DatosBasicos({
    super.key,
    required this.formKey,
    required this.cedulaCtrl,
    required this.nombreCtrl,
    required this.correoCtrl,
    required this.telefonoCtrl,
  });

  @override
  State<_Paso1DatosBasicos> createState() => _Paso1DatosBasicosState();
}

class _Paso1DatosBasicosState extends State<_Paso1DatosBasicos> {
  // null = intacto | true = válido | false = inválido
  bool? _cedulaOk;
  bool? _telefonoOk;

  // El nombre solo muestra error si fue tocado y está vacío
  bool  _nombreTocado = false;

  void _onCedulaChange(String v) {
    if (v.isEmpty) {
      setState(() => _cedulaOk = null);
      return;
    }
    setState(() => _cedulaOk = Validators.cedulaEcuador(v) == null);
  }

  void _onTelefonoChange(String v) {
    if (v.isEmpty) {
      setState(() => _telefonoOk = null);
      return;
    }
    setState(() => _telefonoOk = Validators.telefonoEcuador(v) == null);
  }

  Color _borderColor(bool? ok) {
    if (ok == null) return Colors.grey.shade300;
    return ok ? AppColores.success : AppColores.danger;
  }

  Color _fillColor(bool? ok) {
    if (ok == null) return Colors.white;
    return ok
        ? AppColores.success.withOpacity(0.05)
        : AppColores.danger.withOpacity(0.05);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      // ⚠️ disabled — cada campo controla su propia validación visual
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloSeccion(
            icono:  '📋',
            titulo: 'Datos personales',
            sub:    'Campos obligatorios: cédula y nombre',
          ),
          const SizedBox(height: 20),

          // ── Cédula ───────────────────────────────────
          TextFormField(
            controller:   widget.cedulaCtrl,
            keyboardType: TextInputType.number,
            maxLength:    10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged:    _onCedulaChange,
            decoration: InputDecoration(
              labelText:   'Cédula *',
              prefixIcon:  const Icon(Icons.badge_outlined),
              counterText: '',
              suffixIcon: _cedulaOk == null
                  ? null
                  : Icon(
                      _cedulaOk!
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _cedulaOk!
                          ? AppColores.success
                          : AppColores.danger,
                    ),
              filled:    true,
              fillColor: _fillColor(_cedulaOk),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _borderColor(_cedulaOk), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _cedulaOk == null
                      ? AppColores.primary
                      : _borderColor(_cedulaOk),
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
            ),
            // El validator solo corre cuando el Form hace validate()
            // es decir al pulsar "Siguiente"
            validator: Validators.cedulaEcuador,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _cedulaOk == true
                ? Padding(
                    key: const ValueKey('c-ok'),
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Row(children: const [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: AppColores.success),
                      SizedBox(width: 4),
                      Text('Cédula válida ✓',
                          style: TextStyle(
                            fontSize:   12,
                            color:      AppColores.success,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  )
                : const SizedBox.shrink(key: ValueKey('c-no')),
          ),
          const SizedBox(height: 14),

          // ── Nombre ───────────────────────────────────
          TextFormField(
            controller:   widget.nombreCtrl,
            keyboardType: TextInputType.name,
            // Solo activa el error de este campo cuando el usuario
            // lo toca y lo deja vacío
            onChanged: (_) {
              if (!_nombreTocado) return;
              setState(() {});   // redibuja para mostrar/ocultar error
            },
            onTap: () => setState(() => _nombreTocado = true),
            decoration: InputDecoration(
              labelText:  'Nombre completo *',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled:    true,
              fillColor: Colors.white,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre es obligatorio'
                : null,
          ),
          const SizedBox(height: 14),

          // ── Teléfono ─────────────────────────────────
          TextFormField(
            controller:   widget.telefonoCtrl,
            keyboardType: TextInputType.number,
            maxLength:    10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged:    _onTelefonoChange,
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
                          ? AppColores.success
                          : AppColores.danger,
                    ),
              filled:    true,
              fillColor: _fillColor(_telefonoOk),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _borderColor(_telefonoOk), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _telefonoOk == null
                      ? AppColores.primary
                      : _borderColor(_telefonoOk),
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
            ),
            validator: Validators.telefonoEcuador,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _telefonoOk == true
                ? Padding(
                    key: const ValueKey('t-ok'),
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Row(children: const [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: AppColores.success),
                      SizedBox(width: 4),
                      Text('Teléfono válido ✓',
                          style: TextStyle(
                            fontSize:   12,
                            color:      AppColores.success,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  )
                : const SizedBox.shrink(key: ValueKey('t-no')),
          ),
          const SizedBox(height: 14),

          // ── Correo ───────────────────────────────────
          TextFormField(
            controller:   widget.correoCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText:  'Correo electrónico',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled:    true,
              fillColor: Colors.white,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
              if (!regex.hasMatch(v.trim())) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 2: Empresa
// ══════════════════════════════════════════════════════════
class _Paso2Empresa extends ConsumerWidget {
  final EmpresaModel?          empresaSelec;
  final Function(EmpresaModel?) onSelec;

  const _Paso2Empresa({
    super.key,
    required this.empresaSelec,
    required this.onSelec,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresasAsync = ref.watch(empresasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion(
          icono:  '🏢',
          titulo: 'Empresa donde trabaja',
          sub:    'Opcional — puedes dejarlo en blanco',
        ),
        const SizedBox(height: 20),

        _OpcionEmpresa(
          seleccionada: empresaSelec == null,
          titulo:       'Sin empresa',
          subtitulo:    'El cliente compra de forma independiente',
          icono:        Icons.person_outline,
          onTap:        () => onSelec(null),
        ),
        const SizedBox(height: 10),

        empresasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => const Text('Error cargando empresas'),
          data: (empresas) => empresas.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColores.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay empresas registradas.\nSe creará el cliente sin empresa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColores.textSecond),
                    ),
                  ),
                )
              : Column(
                  children: empresas.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OpcionEmpresa(
                      seleccionada: empresaSelec?.id == e.id,
                      titulo:       e.nombre,
                      subtitulo:    e.direccion ?? 'Sin dirección registrada',
                      icono:        Icons.business_outlined,
                      onTap:        () => onSelec(e),
                    ),
                  )).toList(),
                ),
        ),
      ],
    );
  }
}

class _OpcionEmpresa extends StatelessWidget {
  final bool         seleccionada;
  final String       titulo;
  final String       subtitulo;
  final IconData     icono;
  final VoidCallback onTap;

  const _OpcionEmpresa({
    required this.seleccionada,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColores.accent.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada ? AppColores.accent : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              seleccionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: seleccionada
                  ? AppColores.accent : AppColores.textSecond,
            ),
            const SizedBox(width: 12),
            Icon(icono, color: AppColores.textSecond, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: seleccionada
                            ? AppColores.accent
                            : AppColores.textPrimary,
                      )),
                  Text(subtitulo,
                      style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 3: Acceso a la app
// ══════════════════════════════════════════════════════════
class _Paso3Acceso extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final bool                  crearAcceso;
  final bool                  verContrasena;
  final TextEditingController usuarioCtrl;
  final TextEditingController contraCtrl;
  final String                sugerirUsuario;
  final Function(bool)        onToggleAcceso;
  final VoidCallback          onToggleVer;

  const _Paso3Acceso({
    super.key,
    required this.formKey,
    required this.crearAcceso,
    required this.verContrasena,
    required this.usuarioCtrl,
    required this.contraCtrl,
    required this.sugerirUsuario,
    required this.onToggleAcceso,
    required this.onToggleVer,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key:              formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloSeccion(
            icono:  '📱',
            titulo: 'Acceso a la app',
            sub:    '¿El cliente quiere ver su deuda desde el celular?',
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => onToggleAcceso(!crearAcceso),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: crearAcceso
                    ? AppColores.success.withOpacity(0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: crearAcceso
                      ? AppColores.success : Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    crearAcceso ? Icons.toggle_on : Icons.toggle_off,
                    color: crearAcceso
                        ? AppColores.success : AppColores.textSecond,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crearAcceso
                              ? 'Sí, crear acceso a la app'
                              : 'No por ahora',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: crearAcceso
                                ? AppColores.success
                                : AppColores.textPrimary,
                          ),
                        ),
                        Text(
                          crearAcceso
                              ? 'El cliente podrá ver su deuda y pagos'
                              : 'Solo el vendedor gestionará su cuenta',
                          style: const TextStyle(
                            fontSize: 12, color: AppColores.textSecond,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (crearAcceso) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColores.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Credenciales de acceso',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColores.textPrimary,
                      )),
                  const SizedBox(height: 4),
                  const Text(
                    'El cliente usará estas credenciales para entrar a la app',
                    style: TextStyle(
                        fontSize: 12, color: AppColores.textSecond),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: usuarioCtrl,
                    decoration: InputDecoration(
                      labelText:  'Usuario',
                      hintText:   sugerirUsuario.isNotEmpty
                          ? 'Ej: $sugerirUsuario' : 'nombre de usuario',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled:    true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El usuario es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller:  contraCtrl,
                    obscureText: !verContrasena,
                    decoration: InputDecoration(
                      labelText:  'Contraseña',
                      hintText:   'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(verContrasena
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: onToggleVer,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled:    true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'La contraseña es obligatoria';
                      }
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS REUTILIZABLES
// ══════════════════════════════════════════════════════════
class _TituloSeccion extends StatelessWidget {
  final String icono;
  final String titulo;
  final String sub;
  const _TituloSeccion({
    required this.icono,
    required this.titulo,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icono, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  )),
              Text(sub,
                  style: const TextStyle(
                    fontSize: 12, color: AppColores.textSecond,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int          paso;
  final bool         cargando;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  const _BottomBar({
    required this.paso,
    required this.cargando,
    required this.onAnterior,
    required this.onSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    final esUltimoPaso = paso == 3;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color:     Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (paso > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed: cargando ? null : onAnterior,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.arrow_back),
              ),
            ),

          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: cargando ? null : onSiguiente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: esUltimoPaso
                      ? AppColores.success : AppColores.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: cargando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            esUltimoPaso
                                ? 'Guardar Cliente' : 'Siguiente',
                            style: const TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(esUltimoPaso
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}