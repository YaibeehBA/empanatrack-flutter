import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/colores.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usuarioCtrl   = TextEditingController();
  final _contraCtrl    = TextEditingController();
  bool  _verContrasena = false;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _contraCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usuarioCtrl.text.isEmpty || _contraCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }
    await ref.read(authProvider.notifier).login(
      _usuarioCtrl.text.trim(),
      _contraCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Escuchar cambios en el estado de auth ─────────────────
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.estado == AuthEstado.autenticado) {
        // Redirigir según el rol
        final rol = next.sesion!.rol;
        if (rol == 'vendedor') {
          context.go('/dashboard');
        } else if (rol == 'administrador') {
          context.go('/admin');  // ← ADMIN va a /admin
        } else if (rol == 'cliente') {
          context.go('/mi-cuenta');
        }
      } else if (next.estado == AuthEstado.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(next.mensajeError ?? 'Error'),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    final cargando  = authState.estado == AuthEstado.cargando;

    return Scaffold(
      backgroundColor: AppColores.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Logo / ícono
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColores.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('🫓', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 24),

                // Título
                const Text(
                  'EmpanaTrack',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColores.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tus credenciales',
                  style: TextStyle(color: AppColores.textSecond),
                ),
                const SizedBox(height: 40),

                // Campo usuario
                TextField(
                  controller: _usuarioCtrl,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColores.surface,
                  ),
                ),
                const SizedBox(height: 16),

                // Campo contraseña
                TextField(
                  controller: _contraCtrl,
                  obscureText: !_verContrasena,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_verContrasena
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _verContrasena = !_verContrasena),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColores.surface,
                  ),
                ),
                const SizedBox(height: 28),

                // Botón ingresar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: cargando ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Ingresar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                // ── ¿Olvidaste tu contraseña? ────────────────────────
                const SizedBox(height: 16),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/recuperar-contrasena'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColores.primary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Separador
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '¿No tienes cuenta?',
                        style: TextStyle(
                          color:   Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 16),

                // Botón de registro
                SizedBox(
                  width:  double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/registro'),
                    icon:      const Icon(Icons.person_add_outlined),
                    label:     const Text(
                      'Crear cuenta nueva',
                      style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColores.primary,
                      side: const BorderSide(
                        color: AppColores.primary, width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}