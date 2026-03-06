import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/registro_publico_provider.dart';

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {

  final _cedulaCtrl   = TextEditingController();
  final _nombreCtrl   = TextEditingController();
  final _correoCtrl   = TextEditingController();
  final _teleCtrl     = TextEditingController();
  final _usuarioCtrl  = TextEditingController();
  final _contraCtrl   = TextEditingController();
  final _contra2Ctrl  = TextEditingController();

  bool _verContra  = false;
  bool _verContra2 = false;
  int  _paso       = 1; // 1 = datos personales, 2 = credenciales

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _teleCtrl.dispose();
    _usuarioCtrl.dispose();
    _contraCtrl.dispose();
    _contra2Ctrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_paso == 1) {
      if (_cedulaCtrl.text.trim().isEmpty) {
        _error('La cédula es obligatoria.');
        return;
      }
      if (_nombreCtrl.text.trim().isEmpty) {
        _error('El nombre es obligatorio.');
        return;
      }
      setState(() => _paso = 2);
    } else {
      _registrar();
    }
  }

  Future<void> _registrar() async {
    if (_usuarioCtrl.text.trim().isEmpty) {
      _error('El nombre de usuario es obligatorio.');
      return;
    }
    if (_contraCtrl.text.length < 6) {
      _error('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_contraCtrl.text != _contra2Ctrl.text) {
      _error('Las contraseñas no coinciden.');
      return;
    }

    await ref.read(registroPublicoProvider.notifier).registrar(
      cedula:        _cedulaCtrl.text.trim(),
      nombre:        _nombreCtrl.text.trim(),
      correo:        _correoCtrl.text.trim(),
      telefono:      _teleCtrl.text.trim(),
      nombreUsuario: _usuarioCtrl.text.trim(),
      contrasena:    _contraCtrl.text,
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColores.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registroPublicoProvider);

    ref.listen<RegistroPublicoState>(registroPublicoProvider,
        (prev, next) {
      if (next.exitoso) {
        // Mostrar diálogo de éxito y volver al login
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉',
                    style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                const Text(
                  '¡Registro exitoso!',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hola ${_nombreCtrl.text.trim().split(' ').first}, '
                  'ya puedes iniciar sesión con tu usuario '
                  '"${_usuarioCtrl.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color:   AppColores.textSecond,
                    fontSize: 14,
                  ),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Ir al inicio de sesión'),
                ),
              ),
            ],
          ),
        );
      }
      if (next.error != null) {
        _error(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ────────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                color:        AppColores.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botón atrás
                  GestureDetector(
                    onTap: () {
                      if (_paso == 2) {
                        setState(() => _paso = 1);
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '🫓 EmpanaTrack',
                    style: TextStyle(
                      color:      Colors.white70,
                      fontSize:   14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Indicador de pasos
                  _IndicadorPasos(paso: _paso),
                ],
              ),
            ),

            // ── Formulario ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _paso == 1
                      ? _Paso1(
                          key:        const ValueKey(1),
                          cedulaCtrl: _cedulaCtrl,
                          nombreCtrl: _nombreCtrl,
                          correoCtrl: _correoCtrl,
                          teleCtrl:   _teleCtrl,
                        )
                      : _Paso2(
                          key:         const ValueKey(2),
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

            // ── Botón ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                24, 0, 24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width:  double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: state.cargando ? null : _siguiente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paso == 2
                        ? AppColores.success
                        : AppColores.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: state.cargando
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            color:       Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _paso == 1
                                  ? 'Siguiente'
                                  : 'Crear mi cuenta',
                              style: const TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(_paso == 1
                                ? Icons.arrow_forward
                                : Icons.check_circle_outline),
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

// ── Indicador de pasos ─────────────────────────────────────
class _IndicadorPasos extends StatelessWidget {
  final int paso;
  const _IndicadorPasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Circulo(num: 1, activo: paso == 1, hecho: paso > 1),
        Expanded(
          child: Container(
            height: 2,
            color:  paso > 1
                ? Colors.white
                : Colors.white30,
          ),
        ),
        _Circulo(num: 2, activo: paso == 2, hecho: false),
      ],
    );
  }
}

class _Circulo extends StatelessWidget {
  final int  num;
  final bool activo;
  final bool hecho;
  const _Circulo({
    required this.num,
    required this.activo,
    required this.hecho,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        hecho
                ? Colors.greenAccent
                : activo
                    ? Colors.white
                    : Colors.white24,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: hecho
                ? const Icon(Icons.check, size: 16,
                    color: AppColores.primary)
                : Text(
                    '$num',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                      color: activo
                          ? AppColores.primary
                          : Colors.white54,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          num == 1 ? 'Tus datos' : 'Acceso',
          style: TextStyle(
            color:      activo ? Colors.white : Colors.white54,
            fontSize:   10,
            fontWeight: activo
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── PASO 1: Datos personales ───────────────────────────────
class _Paso1 extends StatelessWidget {
  final TextEditingController cedulaCtrl;
  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController teleCtrl;
  const _Paso1({
    super.key,
    required this.cedulaCtrl,
    required this.nombreCtrl,
    required this.correoCtrl,
    required this.teleCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SecTitulo(
          icono:  '📋',
          titulo: 'Datos personales',
          sub:    'Cédula y nombre son obligatorios',
        ),
        const SizedBox(height: 24),
        _Campo(
          ctrl:    cedulaCtrl,
          label:   'Cédula *',
          icono:   Icons.badge_outlined,
          teclado: TextInputType.number,
        ),
        const SizedBox(height: 14),
        _Campo(
          ctrl:  nombreCtrl,
          label: 'Nombre completo *',
          icono: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _Campo(
          ctrl:    teleCtrl,
          label:   'Teléfono',
          icono:   Icons.phone_outlined,
          teclado: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _Campo(
          ctrl:    correoCtrl,
          label:   'Correo electrónico',
          icono:   Icons.email_outlined,
          teclado: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        // Info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColores.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColores.accent.withOpacity(0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppColores.accent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu cédula nos permite identificarte y '
                  'vincular tus compras.',
                  style: TextStyle(
                    color:   AppColores.accent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── PASO 2: Credenciales ───────────────────────────────────
class _Paso2 extends StatelessWidget {
  final TextEditingController usuarioCtrl;
  final TextEditingController contraCtrl;
  final TextEditingController contra2Ctrl;
  final bool                  verContra;
  final bool                  verContra2;
  final String                nombre;
  final VoidCallback          onToggle1;
  final VoidCallback          onToggle2;

  const _Paso2({
    super.key,
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
    // Sugerir usuario basado en el nombre
    if (usuarioCtrl.text.isEmpty && nombre.isNotEmpty) {
      usuarioCtrl.text = nombre.split(' ').first.toLowerCase();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SecTitulo(
          icono:  '🔐',
          titulo: 'Crea tu acceso',
          sub:    'Usarás esto para entrar a la app',
        ),
        const SizedBox(height: 24),

        // Usuario
        _Campo(
          ctrl:  usuarioCtrl,
          label: 'Nombre de usuario *',
          icono: Icons.alternate_email,
        ),
        const SizedBox(height: 14),

        // Contraseña
        TextField(
          controller:  contraCtrl,
          obscureText: !verContra,
          decoration: InputDecoration(
            labelText:  'Contraseña *',
            hintText:   'Mínimo 6 caracteres',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(verContra
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: onToggle1,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),

        // Confirmar contraseña
        TextField(
          controller:  contra2Ctrl,
          obscureText: !verContra2,
          decoration: InputDecoration(
            labelText:  'Confirmar contraseña *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(verContra2
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: onToggle2,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Tip seguridad
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColores.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColores.success.withOpacity(0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.security_outlined,
                  color: AppColores.success, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Usa una contraseña segura que no compartas '
                  'con nadie.',
                  style: TextStyle(
                    color:    AppColores.success,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Widgets reutilizables ──────────────────────────────────
class _SecTitulo extends StatelessWidget {
  final String icono;
  final String titulo;
  final String sub;
  const _SecTitulo({
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
        Column(
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
                  fontSize: 12,
                  color:    AppColores.textSecond,
                )),
          ],
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final IconData              icono;
  final TextInputType         teclado;
  const _Campo({
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled:    true,
        fillColor: Colors.white,
      ),
    );
  }
}