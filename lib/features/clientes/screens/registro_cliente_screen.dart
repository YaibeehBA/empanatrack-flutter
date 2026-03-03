// lib/features/clientes/screens/registro_cliente_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/registro_cliente_provider.dart';
import '../providers/clientes_provider.dart';
import '../../../shared/models/empresa_model.dart';

class RegistroClienteScreen extends ConsumerStatefulWidget {
  // Si viene desde nueva-venta, al crear regresa con el cliente listo
  final bool desdeNuevaVenta;
  const RegistroClienteScreen({super.key, this.desdeNuevaVenta = false});

  @override
  ConsumerState<RegistroClienteScreen> createState() =>
      _RegistroClienteScreenState();
}

class _RegistroClienteScreenState
    extends ConsumerState<RegistroClienteScreen> {

  // Controladores
  final _cedulaCtrl    = TextEditingController();
  final _nombreCtrl    = TextEditingController();
  final _correoCtrl    = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _usuarioCtrl   = TextEditingController();
  final _contraCtrl    = TextEditingController();

  // Estado local
  EmpresaModel? _empresaSelec;
  bool          _crearAccesoApp = false;
  bool          _verContrasena  = false;

  // Paso actual del formulario (1 = datos básicos, 2 = empresa, 3 = acceso)
  int _paso = 1;

  final _formKey = GlobalKey<FormState>();

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

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    // Si creará acceso, validar usuario y contraseña
    if (_crearAccesoApp) {
      if (_usuarioCtrl.text.trim().isEmpty) {
        _mostrarError('Ingresa un nombre de usuario para la app.');
        return;
      }
      if (_contraCtrl.text.length < 6) {
        _mostrarError('La contraseña debe tener al menos 6 caracteres.');
        return;
      }
    }

    await ref.read(registroClienteProvider.notifier).registrar(
      cedula:        _cedulaCtrl.text.trim(),
      nombre:        _nombreCtrl.text.trim(),
      correo:        _correoCtrl.text.trim(),
      telefono:      _telefonoCtrl.text.trim(),
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

    // Escuchar resultado
    ref.listen<RegistroClienteState>(registroClienteProvider, (prev, next) {
      if (next.clienteCreado != null) {
        // Refrescar lista de clientes
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

        // Si viene desde nueva venta, retornar el cliente creado
        if (widget.desdeNuevaVenta) {
          context.pop(next.clienteCreado);
        } else {
          context.pop();
        }
      }
      if (next.error != null) {
        _mostrarError(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title:           const Text('Nuevo Cliente',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: _BottomBar(
        paso:          _paso,
        cargando:      state.cargando,
        onAnterior:    () => setState(() => _paso--),
        onSiguiente:   () {
          if (_paso < 3) {
            if (_paso == 1 && !_validarPaso1()) return;
            setState(() => _paso++);
          } else {
            _registrar();
          }
        },
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Indicador de pasos
            _IndicadorPasos(pasoActual: _paso),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _paso == 1
                      ? _Paso1DatosBasicos(
                          key:         const ValueKey(1),
                          cedulaCtrl:  _cedulaCtrl,
                          nombreCtrl:  _nombreCtrl,
                          correoCtrl:  _correoCtrl,
                          telefonoCtrl: _telefonoCtrl,
                        )
                      : _paso == 2
                          ? _Paso2Empresa(
                              key:              const ValueKey(2),
                              empresaSelec:     _empresaSelec,
                              onSelec: (e) =>
                                  setState(() => _empresaSelec = e),
                            )
                          : _Paso3Acceso(
                              key:              const ValueKey(3),
                              crearAcceso:      _crearAccesoApp,
                              verContrasena:    _verContrasena,
                              usuarioCtrl:      _usuarioCtrl,
                              contraCtrl:       _contraCtrl,
                              sugerirUsuario:   _nombreCtrl.text.trim()
                                  .split(' ').first.toLowerCase(),
                              onToggleAcceso: (v) =>
                                  setState(() => _crearAccesoApp = v),
                              onToggleVer: () =>
                                  setState(() => _verContrasena = !_verContrasena),
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validarPaso1() {
    if (_cedulaCtrl.text.trim().isEmpty) {
      _mostrarError('La cédula es obligatoria.');
      return false;
    }
    if (_nombreCtrl.text.trim().isEmpty) {
      _mostrarError('El nombre es obligatorio.');
      return false;
    }
    return true;
  }
}

// ── Indicador de pasos ─────────────────────────────────────
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
          final num     = i + 1;
          final activo  = pasoActual == num;
          final hecho   = pasoActual > num;
          return Expanded(
            child: Row(
              children: [
                // Círculo numerado
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color:        hecho
                        ? AppColores.success
                        : activo
                            ? Colors.white
                            : Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: hecho
                        ? const Icon(Icons.check, size: 16,
                            color: Colors.white)
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
                const SizedBox(width: 6),
                // Nombre del paso
                Text(
                  pasos[i],
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: activo
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: activo ? Colors.white : Colors.white54,
                  ),
                ),
                // Línea separadora
                if (i < pasos.length - 1) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── PASO 1: Datos básicos ──────────────────────────────────
class _Paso1DatosBasicos extends StatelessWidget {
  final TextEditingController cedulaCtrl;
  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController telefonoCtrl;

  const _Paso1DatosBasicos({
    super.key,
    required this.cedulaCtrl,
    required this.nombreCtrl,
    required this.correoCtrl,
    required this.telefonoCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion(
          icono:  '📋',
          titulo: 'Datos personales',
          sub:    'Campos obligatorios: cédula y nombre',
        ),
        const SizedBox(height: 20),

        // Cédula
        _Campo(
          ctrl:       cedulaCtrl,
          label:      'Cédula *',
          icono:      Icons.badge_outlined,
          teclado:    TextInputType.number,
          obligatorio: true,
        ),
        const SizedBox(height: 14),

        // Nombre
        _Campo(
          ctrl:       nombreCtrl,
          label:      'Nombre completo *',
          icono:      Icons.person_outline,
          obligatorio: true,
        ),
        const SizedBox(height: 14),

        // Teléfono
        _Campo(
          ctrl:    telefonoCtrl,
          label:   'Teléfono',
          icono:   Icons.phone_outlined,
          teclado: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        // Correo
        _Campo(
          ctrl:    correoCtrl,
          label:   'Correo electrónico',
          icono:   Icons.email_outlined,
          teclado: TextInputType.emailAddress,
        ),
      ],
    );
  }
}

// ── PASO 2: Empresa ────────────────────────────────────────
class _Paso2Empresa extends ConsumerWidget {
  final EmpresaModel?         empresaSelec;
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

        // Sin empresa
        _OpcionEmpresa(
          seleccionada: empresaSelec == null,
          titulo:       'Sin empresa',
          subtitulo:    'El cliente compra de forma independiente',
          icono:        Icons.person_outline,
          onTap:        () => onSelec(null),
        ),
        const SizedBox(height: 10),

        // Lista de empresas
        empresasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => const Text('Error cargando empresas'),
          data:    (empresas) => empresas.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColores.background,
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: Colors.grey.shade200),
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
          color:        seleccionada
              ? AppColores.accent.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
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
              color: seleccionada ? AppColores.accent : AppColores.textSecond,
            ),
            const SizedBox(width: 12),
            Icon(icono, color: AppColores.textSecond, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: seleccionada
                          ? AppColores.accent
                          : AppColores.textPrimary,
                    ),
                  ),
                  Text(
                    subtitulo,
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
    );
  }
}

// ── PASO 3: Acceso a la app ────────────────────────────────
class _Paso3Acceso extends StatelessWidget {
  final bool                  crearAcceso;
  final bool                  verContrasena;
  final TextEditingController usuarioCtrl;
  final TextEditingController contraCtrl;
  final String                sugerirUsuario;
  final Function(bool)        onToggleAcceso;
  final VoidCallback          onToggleVer;

  const _Paso3Acceso({
    super.key,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion(
          icono:  '📱',
          titulo: 'Acceso a la app',
          sub:    '¿El cliente quiere ver su deuda desde el celular?',
        ),
        const SizedBox(height: 20),

        // Toggle
        GestureDetector(
          onTap: () => onToggleAcceso(!crearAcceso),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        crearAcceso
                  ? AppColores.success.withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: crearAcceso ? AppColores.success : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  crearAcceso
                      ? Icons.toggle_on
                      : Icons.toggle_off,
                  color: crearAcceso ? AppColores.success : AppColores.textSecond,
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

        // Campos de acceso — solo si está activado
        if (crearAcceso) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColores.background,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Credenciales de acceso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'El cliente usará estas credenciales para entrar a la app',
                  style: TextStyle(
                    fontSize: 12, color: AppColores.textSecond,
                  ),
                ),
                const SizedBox(height: 16),

                // Usuario — sugerido con el primer nombre
                TextField(
                  controller: usuarioCtrl,
                  decoration: InputDecoration(
                    labelText:   'Usuario',
                    hintText:    sugerirUsuario.isNotEmpty
                        ? 'Ej: $sugerirUsuario'
                        : 'nombre de usuario',
                    prefixIcon:  const Icon(Icons.person_outline),
                    border:      OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled:      true,
                    fillColor:   Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Contraseña
                TextField(
                  controller:  contraCtrl,
                  obscureText: !verContrasena,
                  decoration: InputDecoration(
                    labelText:   'Contraseña',
                    hintText:    'Mínimo 6 caracteres',
                    prefixIcon:  const Icon(Icons.lock_outline),
                    suffixIcon:  IconButton(
                      icon: Icon(verContrasena
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: onToggleVer,
                    ),
                    border:      OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled:      true,
                    fillColor:   Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Widgets reutilizables ──────────────────────────────────
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12, color: AppColores.textSecond,
              ),
            ),
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
  final bool                  obligatorio;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.icono,
    this.teclado     = TextInputType.text,
    this.obligatorio = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: teclado,
      validator: obligatorio
          ? (v) => (v == null || v.trim().isEmpty)
              ? 'Este campo es obligatorio'
              : null
          : null,
      decoration: InputDecoration(
        labelText:   label,
        prefixIcon:  Icon(icono),
        border:      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled:      true,
        fillColor:   Colors.white,
      ),
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
          // Botón anterior
          if (paso > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed:  cargando ? null : onAnterior,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.arrow_back),
              ),
            ),

          // Botón siguiente / guardar
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:  cargando ? null : onSiguiente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: esUltimoPaso
                      ? AppColores.success
                      : AppColores.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                            esUltimoPaso ? 'Guardar Cliente' : 'Siguiente',
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
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