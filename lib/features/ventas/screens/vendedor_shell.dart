// lib/features/ventas/screens/vendedor_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'historial_screen.dart';
import '../../clientes/screens/clientes_screen.dart';

// ── Provider tab activo ───────────────────────────────────
final tabActivoProvider = StateProvider<int>((ref) => 0);

// ── Modelo perfil vendedor ────────────────────────────────
class PerfilVendedor {
  final String  id;
  final String  nombre;
  final String? telefono;
  final String  nombreUsuario;
  final String  rol;

  const PerfilVendedor({
    required this.id,
    required this.nombre,
    this.telefono,
    required this.nombreUsuario,
    required this.rol,
  });

  factory PerfilVendedor.fromJson(Map<String, dynamic> j) => PerfilVendedor(
    id:            j['id'].toString(),
    nombre:        j['nombre'].toString(),
    telefono:      j['telefono']?.toString(),
    nombreUsuario: j['nombre_usuario'].toString(),
    rol:           j['rol'].toString(),
  );
}

// ── Provider perfil ───────────────────────────────────────
final perfilVendedorProvider =
    FutureProvider.autoDispose<PerfilVendedor>((ref) async {
  final response = await ApiClient.get('/vendedores/mi-perfil');
  return PerfilVendedor.fromJson(response.data);
});

// ══════════════════════════════════════════════════════════
//  SHELL
// ══════════════════════════════════════════════════════════
class VendedorShell extends ConsumerWidget {
  const VendedorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabActivoProvider);

    final pantallas = const [
      DashboardScreen(),
      ClientesScreen(),
      HistorialScreen(),
      _ConfiguracionScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index:    tab,
        children: pantallas,
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed:       () => context.push('/nueva-venta'),
              backgroundColor: AppColores.accent,
              foregroundColor: Colors.white,
              icon:            const Icon(Icons.add),
              label: const Text(
                'Nueva Venta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset:     const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icono:       Icons.home_outlined,
                  iconoActivo: Icons.home_rounded,
                  label:       'Inicio',
                  activo:      tab == 0,
                  onTap: () =>
                      ref.read(tabActivoProvider.notifier).state = 0,
                ),
                _NavItem(
                  icono:       Icons.people_outline,
                  iconoActivo: Icons.people_rounded,
                  label:       'Clientes',
                  activo:      tab == 1,
                  onTap: () =>
                      ref.read(tabActivoProvider.notifier).state = 1,
                ),
                _NavItem(
                  icono:       Icons.receipt_long_outlined,
                  iconoActivo: Icons.receipt_long_rounded,
                  label:       'Historial',
                  activo:      tab == 2,
                  onTap: () =>
                      ref.read(tabActivoProvider.notifier).state = 2,
                ),
                _NavItem(
                  icono:       Icons.settings_outlined,
                  iconoActivo: Icons.settings_rounded,
                  label:       'Config.',
                  activo:      tab == 3,
                  onTap: () =>
                      ref.read(tabActivoProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NAV ITEM
// ══════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final IconData     icono;
  final IconData     iconoActivo;
  final String       label;
  final bool         activo;
  final VoidCallback onTap;
  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.primary.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activo ? iconoActivo : icono,
              color: activo
                  ? AppColores.primary
                  : AppColores.textSecond,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize:   10,
                fontWeight: activo
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: activo
                    ? AppColores.primary
                    : AppColores.textSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PANTALLA CONFIGURACIÓN
// ══════════════════════════════════════════════════════════
class _ConfiguracionScreen extends ConsumerWidget {
  const _ConfiguracionScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilVendedorProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        elevation:                 0,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: perfilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorPerfil(onReintentar: () =>
            ref.invalidate(perfilVendedorProvider)),
        data:    (perfil) => _ConfigBody(perfil: perfil),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BODY CONFIGURACIÓN
// ══════════════════════════════════════════════════════════
class _ConfigBody extends StatelessWidget {
  final PerfilVendedor perfil;
  const _ConfigBody({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Avatar + nombre ──────────────────────────
        _AvatarCard(perfil: perfil),
        const SizedBox(height: 20),

        // ── Sección: Mi cuenta ───────────────────────
        _SeccionLabel(texto: 'MI CUENTA'),
        const SizedBox(height: 8),

        _OpcionTile(
          icono:    Icons.person_outline_rounded,
          color:    AppColores.primary,
          titulo:   'Editar perfil',
          subtitulo: 'Nombre y teléfono',
          onTap:    () => _mostrarEditarPerfil(context, perfil),
        ),
        _OpcionTile(
          icono:    Icons.lock_outline_rounded,
          color:    AppColores.warning,
          titulo:   'Cambiar contraseña',
          subtitulo: 'Actualiza tu contraseña de acceso',
          onTap:    () => _mostrarCambiarContrasena(context),
        ),

        const SizedBox(height: 20),

        // ── Sección: Información ─────────────────────
        _SeccionLabel(texto: 'INFORMACIÓN'),
        const SizedBox(height: 8),

        _OpcionTile(
          icono:    Icons.info_outline_rounded,
          color:    AppColores.accent,
          titulo:   'Acerca de EmpanaTrack',
          subtitulo: 'Versión 1.0.0',
          onTap:    () => _mostrarAcercaDe(context),
          sinFlecha: true,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Modal: Editar perfil ────────────────────────────────
  void _mostrarEditarPerfil(
      BuildContext context, PerfilVendedor perfil) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarPerfilSheet(perfil: perfil),
    );
  }

  // ── Modal: Cambiar contraseña ───────────────────────────
  void _mostrarCambiarContrasena(BuildContext context) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CambiarContrasenaSheet(),
    );
  }

  // ── Dialog: Acerca de ──────────────────────────────────
  void _mostrarAcercaDe(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🫓', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Text('EmpanaTrack'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión: 1.0.0'),
            SizedBox(height: 6),
            Text('Sistema de gestión de ventas fiadas '
                'y cobranzas para negocios.'),
            SizedBox(height: 12),
            Text(
              'Desarrollado con Flutter + FastAPI',
              style: TextStyle(
                fontSize: 12,
                color:    AppColores.textSecond,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  AVATAR CARD
// ══════════════════════════════════════════════════════════
class _AvatarCard extends StatelessWidget {
  final PerfilVendedor perfil;
  const _AvatarCard({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final inicial = perfil.nombre.isNotEmpty
        ? perfil.nombre[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar con inicial
          Container(
            width:  64,
            height: 64,
            decoration: BoxDecoration(
              color:        AppColores.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                inicial,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perfil.nombre,
                  style: const TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${perfil.nombreUsuario}',
                  style: const TextStyle(
                    fontSize: 13,
                    color:    AppColores.textSecond,
                  ),
                ),
                if (perfil.telefono != null &&
                    perfil.telefono!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppColores.textSecond),
                      const SizedBox(width: 4),
                      Text(
                        perfil.telefono!,
                        style: const TextStyle(
                          fontSize: 13,
                          color:    AppColores.textSecond,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColores.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    perfil.rol.toUpperCase(),
                    style: const TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.bold,
                      color:      AppColores.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SECCIÓN LABEL
// ══════════════════════════════════════════════════════════
class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize:      11,
          fontWeight:    FontWeight.bold,
          color:         AppColores.textSecond,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  OPCIÓN TILE
// ══════════════════════════════════════════════════════════
class _OpcionTile extends StatelessWidget {
  final IconData icono;
  final Color    color;
  final String   titulo;
  final String   subtitulo;
  final VoidCallback onTap;
  final bool     sinFlecha;

  const _OpcionTile({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.sinFlecha = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        onTap:        onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: color, size: 20),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
            color:      AppColores.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(
            fontSize: 12,
            color:    AppColores.textSecond,
          ),
        ),
        trailing: sinFlecha
            ? null
            : const Icon(
                Icons.arrow_forward_ios_rounded,
                size:  14,
                color: AppColores.textSecond,
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHEET: EDITAR PERFIL
// ══════════════════════════════════════════════════════════
class _EditarPerfilSheet extends ConsumerStatefulWidget {
  final PerfilVendedor perfil;
  const _EditarPerfilSheet({required this.perfil});

  @override
  ConsumerState<_EditarPerfilSheet> createState() =>
      _EditarPerfilSheetState();
}

class _EditarPerfilSheetState
    extends ConsumerState<_EditarPerfilSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.perfil.nombre);
    _telefonoCtrl = TextEditingController(
        text: widget.perfil.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre   = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre no puede estar vacío');
      return;
    }

    setState(() { _guardando = true; _error = null; });

    try {
      await ApiClient.put('/vendedores/mi-perfil', data: {
        'nombre':   nombre,
        'telefono': telefono.isEmpty ? null : telefono,
      });

      // Refrescar el provider del perfil
      ref.invalidate(perfilVendedorProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perfil actualizado correctamente'),
            backgroundColor: AppColores.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error    = 'No se pudo actualizar el perfil';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetWrapper(
      titulo: 'Editar perfil',
      child:  Column(
        children: [
          _Campo(
            controlador: _nombreCtrl,
            etiqueta:    'Nombre completo',
            icono:       Icons.person_outline_rounded,
            teclado:     TextInputType.name,
          ),
          const SizedBox(height: 14),
          _Campo(
            controlador: _telefonoCtrl,
            etiqueta:    'Teléfono (opcional)',
            icono:       Icons.phone_outlined,
            teclado:     TextInputType.phone,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColores.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          _BotonPrimario(
            texto:      _guardando ? 'Guardando...' : 'Guardar cambios',
            cargando:   _guardando,
            onPressed:  _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHEET: CAMBIAR CONTRASEÑA
// ══════════════════════════════════════════════════════════
class _CambiarContrasenaSheet extends ConsumerStatefulWidget {
  const _CambiarContrasenaSheet();

  @override
  ConsumerState<_CambiarContrasenaSheet> createState() =>
      _CambiarContrasenaSheetState();
}

class _CambiarContrasenaSheetState
    extends ConsumerState<_CambiarContrasenaSheet> {
  final _actualCtrl  = TextEditingController();
  final _nuevaCtrl   = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool    _guardando    = false;
  bool    _verActual    = false;
  bool    _verNueva     = false;
  bool    _verConfirma  = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    final actual   = _actualCtrl.text.trim();
    final nueva    = _nuevaCtrl.text.trim();
    final confirma = _confirmaCtrl.text.trim();

    if (actual.isEmpty || nueva.isEmpty || confirma.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (nueva.length < 6) {
      setState(() =>
          _error = 'La contraseña nueva debe tener al menos 6 caracteres');
      return;
    }
    if (nueva != confirma) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden');
      return;
    }

    setState(() { _guardando = true; _error = null; });

    try {
      await ApiClient.put('/vendedores/mi-perfil/contrasena', data: {
        'contrasena_actual': actual,
        'contrasena_nueva':  nueva,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Contraseña actualizada correctamente'),
            backgroundColor: AppColores.success,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().contains('400')
          ? 'La contraseña actual es incorrecta'
          : 'No se pudo cambiar la contraseña';
      setState(() { _error = msg; _guardando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetWrapper(
      titulo: 'Cambiar contraseña',
      child: Column(
        children: [
          _Campo(
            controlador: _actualCtrl,
            etiqueta:    'Contraseña actual',
            icono:       Icons.lock_outline_rounded,
            oscuro:      !_verActual,
            sufijo: IconButton(
              icon: Icon(_verActual
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  size: 20, color: AppColores.textSecond),
              onPressed: () =>
                  setState(() => _verActual = !_verActual),
            ),
          ),
          const SizedBox(height: 14),
          _Campo(
            controlador: _nuevaCtrl,
            etiqueta:    'Contraseña nueva',
            icono:       Icons.lock_reset_rounded,
            oscuro:      !_verNueva,
            sufijo: IconButton(
              icon: Icon(_verNueva
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  size: 20, color: AppColores.textSecond),
              onPressed: () =>
                  setState(() => _verNueva = !_verNueva),
            ),
          ),
          const SizedBox(height: 14),
          _Campo(
            controlador: _confirmaCtrl,
            etiqueta:    'Confirmar contraseña nueva',
            icono:       Icons.check_circle_outline_rounded,
            oscuro:      !_verConfirma,
            sufijo: IconButton(
              icon: Icon(_verConfirma
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  size: 20, color: AppColores.textSecond),
              onPressed: () =>
                  setState(() => _verConfirma = !_verConfirma),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                  color: AppColores.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          _BotonPrimario(
            texto:     _guardando
                ? 'Guardando...'
                : 'Cambiar contraseña',
            cargando:  _guardando,
            onPressed: _guardando ? null : _cambiar,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS REUTILIZABLES
// ══════════════════════════════════════════════════════════

// Wrapper del bottom sheet
class _BottomSheetWrapper extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _BottomSheetWrapper({
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left:   24,
        right:  24,
        top:    20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width:  40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Text(
            titulo,
            style: const TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      AppColores.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// Campo de texto
class _Campo extends StatelessWidget {
  final TextEditingController controlador;
  final String       etiqueta;
  final IconData     icono;
  final bool         oscuro;
  final TextInputType teclado;
  final Widget?      sufijo;

  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.oscuro  = false,
    this.teclado = TextInputType.text,
    this.sufijo,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:    controlador,
      obscureText:   oscuro,
      keyboardType:  teclado,
      style: const TextStyle(
          fontSize: 15, color: AppColores.textPrimary),
      decoration: InputDecoration(
        labelText:   etiqueta,
        labelStyle:  const TextStyle(
            color: AppColores.textSecond, fontSize: 14),
        prefixIcon:  Icon(icono,
            color: AppColores.primary, size: 20),
        suffixIcon:  sufijo,
        filled:      true,
        fillColor:   AppColores.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColores.primary, width: 1.5),
        ),
      ),
    );
  }
}

// Botón primario
class _BotonPrimario extends StatelessWidget {
  final String    texto;
  final bool      cargando;
  final VoidCallback? onPressed;

  const _BotonPrimario({
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: cargando
            ? const SizedBox(
                width:  20,
                height: 20,
                child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// ── Error perfil ──────────────────────────────────────────
class _ErrorPerfil extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorPerfil({required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el perfil',
            style: TextStyle(color: AppColores.textSecond),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onReintentar,
            child:     const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}