// lib/features/auth/screens/registro_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../providers/registro_publico_provider.dart';

final _busquedaEmpresaProvider = StateProvider<String>((ref) => '');
final _empresaSelecProvider    = StateProvider<EmpresaOpcion?>((ref) => null);
final _modoEmpresaProvider     = StateProvider<String>((ref) => 'ninguna');

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  final _cedulaCtrl  = TextEditingController();
  final _nombreCtrl  = TextEditingController();
  final _correoCtrl  = TextEditingController();
  final _teleCtrl    = TextEditingController();

  final _empresaNombreCtrl    = TextEditingController();
  final _empresaDireccionCtrl = TextEditingController();
  final _empresaTelefonoCtrl  = TextEditingController();

  final _usuarioCtrl = TextEditingController();
  final _contraCtrl  = TextEditingController();
  final _contra2Ctrl = TextEditingController();

  bool _verContra  = false;
  bool _verContra2 = false;
  int  _paso       = 1;

  @override
  void dispose() {
    _cedulaCtrl.dispose();  _nombreCtrl.dispose();
    _correoCtrl.dispose();  _teleCtrl.dispose();
    _empresaNombreCtrl.dispose(); _empresaDireccionCtrl.dispose();
    _empresaTelefonoCtrl.dispose();
    _usuarioCtrl.dispose(); _contraCtrl.dispose(); _contra2Ctrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_paso == 1) {
      if (!(_formKey1.currentState?.validate() ?? false)) return;
      setState(() => _paso = 2);
    } else if (_paso == 2) {
      if (!(_formKey2.currentState?.validate() ?? false)) return;
      final modo = ref.read(_modoEmpresaProvider);
      if (modo == 'existente' && ref.read(_empresaSelecProvider) == null) {
        _error('Selecciona una empresa de la lista.');
        return;
      }
      setState(() => _paso = 3);
    } else {
      if (!(_formKey3.currentState?.validate() ?? false)) return;
      _registrar();
    }
  }

  Future<void> _registrar() async {
    final modo         = ref.read(_modoEmpresaProvider);
    final empresaSelec = ref.read(_empresaSelecProvider);

    await ref.read(registroPublicoProvider.notifier).registrar(
      cedula:           _cedulaCtrl.text.trim(),
      nombre:           _nombreCtrl.text.trim(),
      correo:           _correoCtrl.text.trim(),
      telefono:         _teleCtrl.text.trim(),
      nombreUsuario:    _usuarioCtrl.text.trim(),
      contrasena:       _contraCtrl.text,
      empresaId:        modo == 'existente' ? empresaSelec?.id            : null,
      empresaNombre:    modo == 'nueva'     ? _empresaNombreCtrl.text.trim()    : null,
      empresaDireccion: modo == 'nueva'     ? _empresaDireccionCtrl.text.trim() : null,
      empresaTelefono:  modo == 'nueva'     ? _empresaTelefonoCtrl.text.trim()  : null,
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppColores.danger,
    ));
  }

  void _atras() {
    if (_paso > 1) setState(() => _paso--);
    else context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registroPublicoProvider);

    ref.listen<RegistroPublicoState>(registroPublicoProvider, (prev, next) {
      if (next.exitoso) {
        showDialog(
          context: context, barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                const Text('¡Registro exitoso!',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColores.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Hola ${_nombreCtrl.text.trim().split(' ').first}, '
                  'ya puedes iniciar sesión con tu usuario '
                  '"${_usuarioCtrl.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColores.textSecond, fontSize: 14),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ir al inicio de sesión'),
                ),
              ),
            ],
          ),
        );
      }
      if (next.error != null) _error(next.error!);
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                color: AppColores.primary,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _atras,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('🫓 EmpanaTrack',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Crear cuenta',
                      style: TextStyle(color: Colors.white,
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _IndicadorPasos(paso: _paso),
                ],
              ),
            ),

            // ── Formulario ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _paso == 1
                      ? _Paso1(
                          key:        const ValueKey(1),
                          formKey:    _formKey1,
                          cedulaCtrl: _cedulaCtrl,
                          nombreCtrl: _nombreCtrl,
                          correoCtrl: _correoCtrl,
                          teleCtrl:   _teleCtrl,
                        )
                      : _paso == 2
                          ? _Paso2Empresa(
                              key:                  const ValueKey(2),
                              formKey:              _formKey2,
                              empresaNombreCtrl:    _empresaNombreCtrl,
                              empresaDireccionCtrl: _empresaDireccionCtrl,
                              empresaTelefonoCtrl:  _empresaTelefonoCtrl,
                            )
                          : _Paso3Acceso(
                              key:         const ValueKey(3),
                              formKey:     _formKey3,
                              usuarioCtrl: _usuarioCtrl,
                              contraCtrl:  _contraCtrl,
                              contra2Ctrl: _contra2Ctrl,
                              verContra:   _verContra,
                              verContra2:  _verContra2,
                              nombre:      _nombreCtrl.text.trim(),
                              onToggle1: () =>
                                  setState(() => _verContra = !_verContra),
                              onToggle2: () =>
                                  setState(() => _verContra2 = !_verContra2),
                            ),
                ),
              ),
            ),

            // ── Botón ────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                24, 0, 24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: state.cargando ? null : _siguiente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paso == 3
                        ? AppColores.success : AppColores.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: state.cargando
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _paso == 3 ? 'Crear mi cuenta' : 'Siguiente',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Icon(_paso == 3
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  INDICADOR DE PASOS
// ══════════════════════════════════════════════════════════
class _IndicadorPasos extends StatelessWidget {
  final int paso;
  const _IndicadorPasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Circulo(num: 1, activo: paso == 1, hecho: paso > 1, label: 'Mis datos'),
        Expanded(child: Container(height: 2,
            color: paso > 1 ? Colors.white : Colors.white30)),
        _Circulo(num: 2, activo: paso == 2, hecho: paso > 2, label: 'Empresa'),
        Expanded(child: Container(height: 2,
            color: paso > 2 ? Colors.white : Colors.white30)),
        _Circulo(num: 3, activo: paso == 3, hecho: false, label: 'Acceso'),
      ],
    );
  }
}

class _Circulo extends StatelessWidget {
  final int num; final bool activo; final bool hecho; final String label;
  const _Circulo({required this.num, required this.activo,
      required this.hecho, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: hecho ? Colors.greenAccent
                : activo ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: hecho
                ? const Icon(Icons.check, size: 16, color: AppColores.primary)
                : Text('$num', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: activo ? AppColores.primary : Colors.white54)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          color:      activo ? Colors.white : Colors.white54,
          fontSize:   10,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 1 — Datos personales
// ══════════════════════════════════════════════════════════
class _Paso1 extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController cedulaCtrl;
  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController teleCtrl;
  const _Paso1({
    super.key,
    required this.formKey,
    required this.cedulaCtrl,
    required this.nombreCtrl,
    required this.correoCtrl,
    required this.teleCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecTitulo(
            icono: '📋', titulo: 'Datos personales',
            sub: 'Cédula y nombre son obligatorios',
          ),
          const SizedBox(height: 24),

          // ── Cédula con verificación backend ───────────
          _CampoCedula(ctrl: cedulaCtrl),
          const SizedBox(height: 14),

          // ── Nombre ────────────────────────────────────
          _CampoValidado(
            ctrl:  nombreCtrl,
            label: 'Nombre completo *',
            icono: Icons.person_outline,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
              if (v.trim().length < 3) return 'Mínimo 3 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Teléfono ──────────────────────────────────
          _CampoValidado(
            ctrl:    teleCtrl,
            label:   'Teléfono',
            icono:   Icons.phone_outlined,
            teclado: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: Validators.telefonoEcuador,
          ),
          const SizedBox(height: 14),

          // ── Correo ────────────────────────────────────
          _CampoValidado(
            ctrl:    correoCtrl,
            label:   'Correo electrónico',
            icono:   Icons.email_outlined,
            teclado: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$')
                  .hasMatch(v.trim())) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          const _InfoBox(
            icono: Icons.info_outline,
            color: AppColores.accent,
            texto: 'Tu cédula nos permite identificarte '
                'y vincular tus compras.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 2 — Empresa
// ══════════════════════════════════════════════════════════
class _Paso2Empresa extends ConsumerStatefulWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController empresaNombreCtrl;
  final TextEditingController empresaDireccionCtrl;
  final TextEditingController empresaTelefonoCtrl;
  const _Paso2Empresa({
    super.key,
    required this.formKey,
    required this.empresaNombreCtrl,
    required this.empresaDireccionCtrl,
    required this.empresaTelefonoCtrl,
  });

  @override
  ConsumerState<_Paso2Empresa> createState() => _Paso2EmpresaState();
}

class _Paso2EmpresaState extends ConsumerState<_Paso2Empresa> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() { _busquedaCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final modo         = ref.watch(_modoEmpresaProvider);
    final empresaSelec = ref.watch(_empresaSelecProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecTitulo(
            icono: '🏢', titulo: 'Tu empresa',
            sub: 'Opcional — puedes omitir este paso',
          ),
          const SizedBox(height: 24),

          _OpcionEmpresa(
            valor: 'ninguna', actual: modo,
            titulo: 'No pertenezco a ninguna empresa',
            subtitulo: 'Me registro como cliente individual',
            icono: Icons.person_outline,
            onChange: (v) {
              ref.read(_modoEmpresaProvider.notifier).state = v;
              ref.read(_empresaSelecProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 10),

          _OpcionEmpresa(
            valor: 'existente', actual: modo,
            titulo: 'Mi empresa ya está registrada',
            subtitulo: 'Busca y selecciona tu empresa',
            icono: Icons.search,
            onChange: (v) =>
                ref.read(_modoEmpresaProvider.notifier).state = v,
          ),
          const SizedBox(height: 10),

          _OpcionEmpresa(
            valor: 'nueva', actual: modo,
            titulo: 'Registrar nueva empresa',
            subtitulo: 'Mi empresa aún no está en el sistema',
            icono: Icons.add_business_outlined,
            onChange: (v) {
              ref.read(_modoEmpresaProvider.notifier).state = v;
              ref.read(_empresaSelecProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 24),

          // ── Empresa existente ────────────────────────
          if (modo == 'existente') ...[
            TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                labelText:  'Buscar empresa',
                hintText:   'Escribe el nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.white,
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          ref.read(_busquedaEmpresaProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(_busquedaEmpresaProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),

            if (empresaSelec != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        AppColores.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColores.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColores.success),
                    const SizedBox(width: 10),
                    Expanded(child: Text(empresaSelec.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColores.textPrimary))),
                    GestureDetector(
                      onTap: () => ref
                          .read(_empresaSelecProvider.notifier)
                          .state = null,
                      child: const Icon(Icons.close,
                          color: AppColores.textSecond, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            _ListaEmpresas(
              onSeleccionar: (empresa) {
                ref.read(_empresaSelecProvider.notifier).state = empresa;
                _busquedaCtrl.clear();
                ref.read(_busquedaEmpresaProvider.notifier).state = '';
              },
            ),
          ],

          // ── Empresa nueva ────────────────────────────
          if (modo == 'nueva') ...[
            _CampoValidado(
              ctrl:  widget.empresaNombreCtrl,
              label: 'Nombre de la empresa *',
              icono: Icons.business_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre de la empresa es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _CampoValidado(
              ctrl:  widget.empresaDireccionCtrl,
              label: 'Dirección',
              icono: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            _CampoValidado(
              ctrl:    widget.empresaTelefonoCtrl,
              label:   'Teléfono de la empresa',
              icono:   Icons.phone_outlined,
              teclado: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.telefonoEcuador,
            ),
            const SizedBox(height: 12),
            const _InfoBox(
              icono: Icons.info_outline,
              color: AppColores.accent,
              texto: 'Si ya existe una empresa con ese nombre, '
                  'se vinculará automáticamente.',
            ),
          ],

          // ── Sin empresa ──────────────────────────────
          if (modo == 'ninguna') ...[
            const _InfoBox(
              icono: Icons.check_circle_outline,
              color: AppColores.success,
              texto: 'Te registrarás como cliente individual. '
                  'Puedes asociarte a una empresa más adelante.',
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 3 — Acceso
// ══════════════════════════════════════════════════════════
class _Paso3Acceso extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController usuarioCtrl;
  final TextEditingController contraCtrl;
  final TextEditingController contra2Ctrl;
  final bool                  verContra;
  final bool                  verContra2;
  final String                nombre;
  final VoidCallback          onToggle1;
  final VoidCallback          onToggle2;
  const _Paso3Acceso({
    super.key,
    required this.formKey,
    required this.usuarioCtrl,
    required this.contraCtrl,
    required this.contra2Ctrl,
    required this.verContra,
    required this.verContra2,
    required this.nombre,
    required this.onToggle1,
    required this.onToggle2,
  });

  @override
  Widget build(BuildContext context) {
    if (usuarioCtrl.text.isEmpty && nombre.isNotEmpty) {
      usuarioCtrl.text = nombre.split(' ').first.toLowerCase();
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecTitulo(
            icono: '🔐', titulo: 'Crea tu acceso',
            sub: 'Usarás esto para entrar a la app',
          ),
          const SizedBox(height: 24),

          _CampoValidado(
            ctrl:  usuarioCtrl,
            label: 'Nombre de usuario *',
            icono: Icons.alternate_email,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'El nombre de usuario es obligatorio';
              }
              if (v.trim().length < 3) return 'Mínimo 3 caracteres';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                return 'Solo letras, números y guión bajo';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          _ContraField(
            ctrl:      contraCtrl,
            label:     'Contraseña *',
            hint:      'Mínimo 6 caracteres',
            verTexto:  verContra,
            onToggle:  onToggle1,
            validator: (v) {
              if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 14),

          _ContraField(
            ctrl:      contra2Ctrl,
            label:     'Confirmar contraseña *',
            hint:      null,
            verTexto:  verContra2,
            onToggle:  onToggle2,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirma tu contraseña';
              if (v != contraCtrl.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 24),

          const _InfoBox(
            icono: Icons.security_outlined,
            color: AppColores.success,
            texto: 'Usa una contraseña segura que no compartas con nadie.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CAMPO CÉDULA CON VERIFICACIÓN EN BACKEND
// ══════════════════════════════════════════════════════════
class _CampoCedula extends ConsumerStatefulWidget {
  final TextEditingController ctrl;
  const _CampoCedula({required this.ctrl});

  @override
  ConsumerState<_CampoCedula> createState() => _CampoCedulaState();
}

class _CampoCedulaState extends ConsumerState<_CampoCedula> {
  bool    _tocado      = false;
  bool    _verificando = false;
  bool?   _disponible;
  String? _errorLocal;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (_tocado) {
      final err = Validators.cedulaEcuador(widget.ctrl.text);
      setState(() {
        _errorLocal = err;
        _disponible = null;
      });
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _verificarEnBackend() async {
    final cedula       = widget.ctrl.text;
    final errorFormato = Validators.cedulaEcuador(cedula);

    setState(() {
      _tocado     = true;
      _errorLocal = errorFormato;
      _disponible = null;
    });

    if (errorFormato != null) return;

    setState(() => _verificando = true);
    try {
      final disponible = await ref
          .read(cedulaDisponibleProvider(cedula).future);
      setState(() {
        _disponible  = disponible;
        _verificando = false;
        if (!disponible) {
          _errorLocal = 'Esta cédula ya está registrada en el sistema';
        }
      });
    } catch (_) {
      setState(() => _verificando = false);
    }
  }

  String? get _errorMostrar {
    if (!_tocado) return null;
    if (_errorLocal != null) return _errorLocal;
    if (_disponible == false) {
      return 'Esta cédula ya está registrada en el sistema';
    }
    return null;
  }

  bool get _esValido =>
      _tocado &&
      _errorLocal == null &&
      _disponible == true &&
      widget.ctrl.text.isNotEmpty;

  Color? get _colorBorde {
    if (!_tocado || widget.ctrl.text.isEmpty) return null;
    if (_verificando) return AppColores.accent;
    if (_esValido) return AppColores.success;
    return AppColores.danger;
  }

  InputBorder _borde(Color? color, {bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: color ??
            (focused ? AppColores.primary : Colors.grey.shade400),
        width: color != null || focused ? 2 : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && widget.ctrl.text.isNotEmpty) {
          _verificarEnBackend();
        }
      },
      child: TextFormField(
        controller:      widget.ctrl,
        keyboardType:    TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: (_) {
          if (_errorLocal != null) return _errorLocal;
          if (_disponible == false) {
            return 'Esta cédula ya está registrada en el sistema';
          }
          if (!_esValido && _tocado) return 'Verifica tu cédula';
          return null;
        },
        decoration: InputDecoration(
          labelText:  'Cédula *',
          prefixIcon: const Icon(Icons.badge_outlined),
          suffixIcon: _verificando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _tocado && widget.ctrl.text.isNotEmpty
                  ? Icon(
                      _esValido
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _esValido
                          ? AppColores.success : AppColores.danger,
                      size: 22,
                    )
                  : null,
          border:             _borde(null),
          enabledBorder:      _borde(_colorBorde),
          focusedBorder:      _borde(_colorBorde, focused: true),
          errorBorder:        _borde(AppColores.danger),
          focusedErrorBorder: _borde(AppColores.danger, focused: true),
          errorText: _errorMostrar,
          filled:    true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CAMPO CON VALIDACIÓN EN TIEMPO REAL
// ══════════════════════════════════════════════════════════
class _CampoValidado extends StatefulWidget {
  final TextEditingController      ctrl;
  final String                     label;
  final IconData                   icono;
  final TextInputType              teclado;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>?  inputFormatters;

  const _CampoValidado({
    required this.ctrl,
    required this.label,
    required this.icono,
    this.teclado         = TextInputType.text,
    this.validator,
    this.inputFormatters,
  });

  @override
  State<_CampoValidado> createState() => _CampoValidadoState();
}

class _CampoValidadoState extends State<_CampoValidado> {
  bool _tocado = false;
  bool _valido = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (_tocado) {
      final error = widget.validator?.call(widget.ctrl.text);
      setState(() => _valido =
          error == null && widget.ctrl.text.isNotEmpty);
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onChanged);
    super.dispose();
  }

  InputBorder _borde(Color? color, {bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: color ??
            (focused ? AppColores.primary : Colors.grey.shade400),
        width: color != null || focused ? 2 : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _tocado
        ? widget.validator?.call(widget.ctrl.text)
        : null;

    final Color? colorBorde = !_tocado || widget.ctrl.text.isEmpty
        ? null
        : error != null ? AppColores.danger : AppColores.success;

    final tieneValidator = widget.validator != null;

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && widget.ctrl.text.isNotEmpty) {
          final err = widget.validator?.call(widget.ctrl.text);
          setState(() {
            _tocado = true;
            _valido = err == null;
          });
        }
      },
      child: TextFormField(
        controller:      widget.ctrl,
        keyboardType:    widget.teclado,
        inputFormatters: widget.inputFormatters,
        validator:       _tocado ? widget.validator : null,
        decoration: InputDecoration(
          labelText:  widget.label,
          prefixIcon: Icon(widget.icono),
          suffixIcon: tieneValidator && _tocado &&
                  widget.ctrl.text.isNotEmpty
              ? Icon(
                  _valido
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: _valido
                      ? AppColores.success : AppColores.danger,
                  size: 22,
                )
              : null,
          border:             _borde(null),
          enabledBorder:      _borde(colorBorde),
          focusedBorder:      _borde(colorBorde, focused: true),
          errorBorder:        _borde(AppColores.danger),
          focusedErrorBorder: _borde(AppColores.danger, focused: true),
          errorText:  error,
          filled:     true,
          fillColor:  Colors.white,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CAMPO CONTRASEÑA CON VALIDACIÓN
// ══════════════════════════════════════════════════════════
class _ContraField extends StatefulWidget {
  final TextEditingController      ctrl;
  final String                     label;
  final String?                    hint;
  final bool                       verTexto;
  final VoidCallback               onToggle;
  final String? Function(String?)? validator;

  const _ContraField({
    required this.ctrl,
    required this.label,
    this.hint,
    required this.verTexto,
    required this.onToggle,
    this.validator,
  });

  @override
  State<_ContraField> createState() => _ContraFieldState();
}

class _ContraFieldState extends State<_ContraField> {
  bool _tocado = false;
  bool _valido = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (_tocado) {
      final error = widget.validator?.call(widget.ctrl.text);
      setState(() => _valido =
          error == null && widget.ctrl.text.isNotEmpty);
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onChanged);
    super.dispose();
  }

  InputBorder _borde(Color? color, {bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: color ??
            (focused ? AppColores.primary : Colors.grey.shade400),
        width: color != null || focused ? 2 : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _tocado
        ? widget.validator?.call(widget.ctrl.text)
        : null;

    final Color? colorBorde = !_tocado || widget.ctrl.text.isEmpty
        ? null
        : error != null ? AppColores.danger : AppColores.success;

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && widget.ctrl.text.isNotEmpty) {
          final err = widget.validator?.call(widget.ctrl.text);
          setState(() {
            _tocado = true;
            _valido = err == null;
          });
        }
      },
      child: TextFormField(
        controller:  widget.ctrl,
        obscureText: !widget.verTexto,
        validator:   _tocado ? widget.validator : null,
        decoration: InputDecoration(
          labelText:  widget.label,
          hintText:   widget.hint,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_tocado && widget.ctrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    _valido
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _valido
                        ? AppColores.success : AppColores.danger,
                    size: 22,
                  ),
                ),
              IconButton(
                icon: Icon(widget.verTexto
                    ? Icons.visibility_off : Icons.visibility),
                onPressed: widget.onToggle,
              ),
            ],
          ),
          border:             _borde(null),
          enabledBorder:      _borde(colorBorde),
          focusedBorder:      _borde(colorBorde, focused: true),
          errorBorder:        _borde(AppColores.danger),
          focusedErrorBorder: _borde(AppColores.danger, focused: true),
          errorText:  error,
          filled:     true,
          fillColor:  Colors.white,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS REUTILIZABLES
// ══════════════════════════════════════════════════════════
class _ListaEmpresas extends ConsumerWidget {
  final Function(EmpresaOpcion) onSeleccionar;
  const _ListaEmpresas({required this.onSeleccionar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busqueda = ref.watch(_busquedaEmpresaProvider);
    final async    = ref.watch(empresasPublicasProvider(busqueda));

    return async.when(
      loading: () => const Center(
          child: Padding(padding: EdgeInsets.all(16),
              child: CircularProgressIndicator())),
      error: (e, _) => const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Error cargando empresas',
              style: TextStyle(color: AppColores.danger))),
      data: (empresas) => empresas.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                busqueda.isEmpty
                    ? 'Escribe para buscar empresas'
                    : 'No se encontró "$busqueda"',
                style: const TextStyle(color: AppColores.textSecond),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: empresas.take(5)
                    .map((e) => _EmpresaItem(
                          empresa: e, onSeleccionar: onSeleccionar))
                    .toList(),
              ),
            ),
    );
  }
}

class _EmpresaItem extends StatelessWidget {
  final EmpresaOpcion           empresa;
  final Function(EmpresaOpcion) onSeleccionar;
  const _EmpresaItem(
      {required this.empresa, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        () => onSeleccionar(empresa),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.business_outlined,
                color: AppColores.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(empresa.nombre,
                style: const TextStyle(
                    fontSize: 14, color: AppColores.textPrimary))),
            const Icon(Icons.chevron_right,
                color: AppColores.textSecond, size: 18),
          ],
        ),
      ),
    );
  }
}

class _OpcionEmpresa extends StatelessWidget {
  final String           valor;
  final String           actual;
  final String           titulo;
  final String           subtitulo;
  final IconData         icono;
  final Function(String) onChange;
  const _OpcionEmpresa({
    required this.valor,   required this.actual,
    required this.titulo,  required this.subtitulo,
    required this.icono,   required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final seleccionado = valor == actual;
    return GestureDetector(
      onTap: () => onChange(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColores.primary.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado
                ? AppColores.primary : Colors.grey.shade200,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: seleccionado
                    ? AppColores.primary.withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono,
                  color: seleccionado
                      ? AppColores.primary : AppColores.textSecond,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14,
                      color: seleccionado
                          ? AppColores.primary : AppColores.textPrimary)),
                  Text(subtitulo, style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
                ],
              ),
            ),
            if (seleccionado)
              const Icon(Icons.check_circle,
                  color: AppColores.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SecTitulo extends StatelessWidget {
  final String icono; final String titulo; final String sub;
  const _SecTitulo({
      required this.icono, required this.titulo, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icono, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: AppColores.textPrimary)),
            Text(sub, style: const TextStyle(
                fontSize: 12, color: AppColores.textSecond)),
          ],
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icono; final Color color; final String texto;
  const _InfoBox({
      required this.icono, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(texto,
              style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}