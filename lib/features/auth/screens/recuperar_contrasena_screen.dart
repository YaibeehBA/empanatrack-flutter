import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/recuperacion_provider.dart';

class RecuperarContrasenaScreen extends ConsumerStatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  ConsumerState<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState
    extends ConsumerState<RecuperarContrasenaScreen> {
  final _correoCtrl  = TextEditingController();
  final _codigoCtrl  = TextEditingController();
  final _contra1Ctrl = TextEditingController();
  final _contra2Ctrl = TextEditingController();

  bool _verContra1 = false;
  bool _verContra2 = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    _contra1Ctrl.dispose();
    _contra2Ctrl.dispose();
    super.dispose();
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColores.danger,
    ));
  }

  // ── Paso 1: enviar código ────────────────────────────────
  Future<void> _enviarCodigo() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty) {
      _mostrarError('Ingresa tu correo electrónico.');
      return;
    }
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(correo)) {
      _mostrarError('Ingresa un correo válido.');
      return;
    }
    await ref.read(recuperacionProvider.notifier).solicitarCodigo(correo);
  }

  // ── Paso 2: verificar código y cambiar contraseña ────────
  Future<void> _cambiarContrasena() async {
    final codigo  = _codigoCtrl.text.trim();
    final contra1 = _contra1Ctrl.text;
    final contra2 = _contra2Ctrl.text;

    if (codigo.length != 6) {
      _mostrarError('El código debe tener 6 dígitos.');
      return;
    }
    if (contra1.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (contra1 != contra2) {
      _mostrarError('Las contraseñas no coinciden.');
      return;
    }

    await ref.read(recuperacionProvider.notifier).verificarCodigo(
      correo:         _correoCtrl.text.trim(),
      codigo:         codigo,
      contrasenaNueva: contra1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recuperacionProvider);

    // Escuchar errores y éxito
    ref.listen<RecuperacionState>(recuperacionProvider, (prev, next) {
      if (next.error != null) _mostrarError(next.error!);

      if (next.exitoso) {
        showDialog(
          context:           context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('✅', style: TextStyle(fontSize: 52)),
                SizedBox(height: 12),
                Text(
                  '¡Contraseña actualizada!',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ya puedes iniciar sesión con tu nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ───────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                color:        AppColores.primary,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/login'),
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
                  const Text('🫓 EmpanaTrack',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    'Recuperar contraseña',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Indicador de pasos
                  _IndicadorPasos(
                      paso: state.codigoEnviado ? 2 : 1),
                ],
              ),
            ),

            // ── Contenido ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: state.codigoEnviado
                      ? _PasoCodigo(
                          key:         const ValueKey('paso2'),
                          correo:      _correoCtrl.text.trim(),
                          codigoCtrl:  _codigoCtrl,
                          contra1Ctrl: _contra1Ctrl,
                          contra2Ctrl: _contra2Ctrl,
                          verContra1:  _verContra1,
                          verContra2:  _verContra2,
                          onToggle1: () => setState(
                              () => _verContra1 = !_verContra1),
                          onToggle2: () => setState(
                              () => _verContra2 = !_verContra2),
                          onReenviar: () {
                            ref
                                .read(recuperacionProvider.notifier)
                                .resetear();
                            // Vuelve al paso 1 limpiando solo código/contraseñas
                            _codigoCtrl.clear();
                            _contra1Ctrl.clear();
                            _contra2Ctrl.clear();
                          },
                        )
                      : _PasoCorreo(
                          key:       const ValueKey('paso1'),
                          correoCtrl: _correoCtrl,
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
                width:  double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: state.cargando
                      ? null
                      : state.codigoEnviado
                          ? _cambiarContrasena
                          : _enviarCodigo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.codigoEnviado
                        ? AppColores.success : AppColores.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: state.cargando
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              state.codigoEnviado
                                  ? 'Cambiar contraseña'
                                  : 'Enviar código',
                              style: const TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(state.codigoEnviado
                                ? Icons.check_circle_outline
                                : Icons.send_outlined),
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
        _Circulo(num: 1, activo: paso == 1, hecho: paso > 1,
            label: 'Correo'),
        Expanded(child: Container(height: 2,
            color: paso > 1 ? Colors.white : Colors.white30)),
        _Circulo(num: 2, activo: paso == 2, hecho: false,
            label: 'Nueva clave'),
      ],
    );
  }
}

class _Circulo extends StatelessWidget {
  final int    num;
  final bool   activo;
  final bool   hecho;
  final String label;
  const _Circulo({
    required this.num,   required this.activo,
    required this.hecho, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: hecho
                ? Colors.greenAccent
                : activo ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: hecho
                ? const Icon(Icons.check, size: 16,
                    color: AppColores.primary)
                : Text('$num', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: activo
                        ? AppColores.primary : Colors.white54)),
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
//  PASO 1 — Ingresar correo
// ══════════════════════════════════════════════════════════
class _PasoCorreo extends StatelessWidget {
  final TextEditingController correoCtrl;
  const _PasoCorreo({super.key, required this.correoCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ilustración
        Center(
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color:        AppColores.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Center(
              child: Text('📧', style: TextStyle(fontSize: 48)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Ingresa tu correo',
          style: TextStyle(
            fontSize:   20,
            fontWeight: FontWeight.bold,
            color:      AppColores.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Te enviaremos un código de 6 dígitos para '
          'restablecer tu contraseña.',
          style: TextStyle(
              color: AppColores.textSecond, fontSize: 14),
        ),
        const SizedBox(height: 28),

        TextFormField(
          controller:  correoCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText:  'Correo electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColores.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColores.accent.withOpacity(0.2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline,
                  color: AppColores.accent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El correo debe ser el que registraste '
                  'al crear tu cuenta.',
                  style: TextStyle(
                      color: AppColores.accent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PASO 2 — Código + nueva contraseña
// ══════════════════════════════════════════════════════════
class _PasoCodigo extends StatelessWidget {
  final String                correo;
  final TextEditingController codigoCtrl;
  final TextEditingController contra1Ctrl;
  final TextEditingController contra2Ctrl;
  final bool                  verContra1;
  final bool                  verContra2;
  final VoidCallback          onToggle1;
  final VoidCallback          onToggle2;
  final VoidCallback          onReenviar;

  const _PasoCodigo({
    super.key,
    required this.correo,
    required this.codigoCtrl,
    required this.contra1Ctrl,
    required this.contra2Ctrl,
    required this.verContra1,
    required this.verContra2,
    required this.onToggle1,
    required this.onToggle2,
    required this.onReenviar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Confirmación de envío
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        AppColores.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColores.success.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  color: AppColores.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('¡Código enviado!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:      AppColores.success,
                        )),
                    Text(
                      'Revisa tu bandeja en\n$correo',
                      style: const TextStyle(
                          fontSize: 12,
                          color:    AppColores.textSecond),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Campo código
        const Text('Código de verificación',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   15,
              color:      AppColores.textPrimary,
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller:      codigoCtrl,
          keyboardType:    TextInputType.number,
          textAlign:       TextAlign.center,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
              letterSpacing: 12),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText:   '— — — — — —',
            hintStyle:  const TextStyle(
                letterSpacing: 8, color: Colors.grey),
            prefixIcon: const Icon(Icons.pin_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),

        // Reenviar código
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReenviar,
            icon:  const Icon(Icons.refresh, size: 16),
            label: const Text('Reenviar código',
                style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
                foregroundColor: AppColores.primary),
          ),
        ),
        const SizedBox(height: 8),

        // Nueva contraseña
        const Text('Nueva contraseña',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   15,
              color:      AppColores.textPrimary,
            )),
        const SizedBox(height: 8),

        TextFormField(
          controller:  contra1Ctrl,
          obscureText: !verContra1,
          decoration: InputDecoration(
            labelText:  'Nueva contraseña',
            hintText:   'Mínimo 6 caracteres',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(verContra1
                  ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle1,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller:  contra2Ctrl,
          obscureText: !verContra2,
          decoration: InputDecoration(
            labelText:  'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(verContra2
                  ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle2,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled:    true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColores.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColores.accent.withOpacity(0.2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.timer_outlined,
                  color: AppColores.accent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El código expira en 15 minutos.',
                  style: TextStyle(
                      color: AppColores.accent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}