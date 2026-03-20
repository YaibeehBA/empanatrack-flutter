import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/utils/validators.dart';
import '../../clientes/providers/registro_cliente_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_form_widgets.dart';

// ══════════════════════════════════════════════════════════
//  EMPRESAS SCREEN — UX mejorado (Google Maps UX principles)
// ══════════════════════════════════════════════════════════
class EmpresasScreen extends ConsumerWidget {
  const EmpresasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(empresasAdminProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar colapsable con título grande ──
          SliverAppBar(
            expandedHeight: 120,
            floating:       false,
            pinned:         true,
            elevation:      0,
            backgroundColor: AppColores.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: const Text(
                'Empresas',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize:   20,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      AppColores.primary,
                      AppColores.primary.withOpacity(0.82),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, top: 16),
                    child: Icon(
                      Icons.business_rounded,
                      size:  72,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido ──────────────────────────────────
          listaAsync.when(
            loading: () => const SliverFillRemaining(
              child: _LoadingState(),
            ),
            error: (e, _) => const SliverFillRemaining(
              child: _ErrorState(),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyState(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EmpresaCard(
                      empresa:    lista[i],
                      index:      i,
                      onEditar:   () => _form(ctx, ref, empresa: lista[i]),
                      onEliminar: () =>
                          _confirmarEliminar(ctx, ref, lista[i]),
                    ),
                    childCount: lista.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ── FAB accesible con label claro ──────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed:       () => _form(context, ref),
          backgroundColor: AppColores.warning,
          foregroundColor: Colors.white,
          elevation:       4,
          icon:            const Icon(Icons.add_business_rounded, size: 22),
          label: const Text(
            'Nueva Empresa',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
            await ref
                .read(adminOpProvider.notifier)
                .editarEmpresa(empresa.id, datos);
          }
          final state = ref.read(adminOpProvider);
          if (state.error != null) {
            if (ctx.mounted) {
              _mostrarSnack(ctx, state.error!, isError: true);
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

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, EmpresaAdmin empresa) {
    showDialog(
      context: context,
      builder: (_) => _DialogEliminar(
        empresa: empresa,
        onConfirmar: () async {
          Navigator.pop(context);
          await ref
              .read(adminOpProvider.notifier)
              .eliminarEmpresa(empresa.id.toString());
          final state = ref.read(adminOpProvider);
          if (state.error != null && context.mounted) {
            _mostrarSnack(context, state.error!, isError: true);
            ref.read(adminOpProvider.notifier).resetear();
            return;
          }
          ref.invalidate(empresasAdminProvider);
          ref.invalidate(empresasProvider);
          ref.read(adminOpProvider.notifier).resetear();
        },
      ),
    );
  }

  static void _mostrarSnack(BuildContext ctx, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_rounded
                : Icons.check_circle_rounded,
            color: Colors.white,
            size:  18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor:
            isError ? AppColores.danger : AppColores.success,
        behavior:     SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ESTADOS VACÍO / CARGA / ERROR
// ══════════════════════════════════════════════════════════
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando empresas…',
              style: TextStyle(color: AppColores.textSecond)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No pudimos cargar las empresas',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColores.textPrimary)),
          const SizedBox(height: 6),
          const Text('Verifica tu conexión e intenta de nuevo.',
              style: TextStyle(
                  fontSize: 13, color: AppColores.textSecond)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  84,
            height: 84,
            decoration: BoxDecoration(
              color:        AppColores.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
                child: Text('🏢', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 18),
          const Text('Aún no hay empresas',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColores.textPrimary,
              )),
          const SizedBox(height: 6),
          const Text('Toca "+ Nueva Empresa" para comenzar.',
              style: TextStyle(
                  fontSize: 14, color: AppColores.textSecond)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD DE EMPRESA — rediseñada
// ══════════════════════════════════════════════════════════
class _EmpresaCard extends StatelessWidget {
  final EmpresaAdmin empresa;
  final int          index;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _EmpresaCard({
    required this.empresa,
    required this.index,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneGPS =
        empresa.latitud != null && empresa.longitud != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation:    0,
        child: InkWell(
          onTap:        onEditar,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.grey.shade100, width: 1.5),
            ),
            child: Column(
              children: [
                // ── Cabecera ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar con inicial
                      _AvatarEmpresa(nombre: empresa.nombre),
                      const SizedBox(width: 12),

                      // Info principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    empresa.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize:   15,
                                      color:      AppColores.textPrimary,
                                      height:     1.2,
                                    ),
                                  ),
                                ),
                                // Badge estado
                                if (!empresa.estaActiva)
                                  _BadgeInactiva(),
                              ],
                            ),
                            if (empresa.direccion != null) ...[
                              const SizedBox(height: 4),
                              _InfoRow(
                                icon:  Icons.location_on_outlined,
                                text:  empresa.direccion!,
                                color: AppColores.textSecond,
                              ),
                            ],
                            if (empresa.telefono != null) ...[
                              const SizedBox(height: 2),
                              _InfoRow(
                                icon:  Icons.phone_outlined,
                                text:  empresa.telefono!,
                                color: AppColores.textSecond,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer GPS + acciones ────────────────
                Container(
                  decoration: BoxDecoration(
                    color:        Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      // GPS chip
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 0, 8),
                          child: tieneGPS
                              ? _GpsChip(
                                  lat: empresa.latitud!,
                                  lng: empresa.longitud!,
                                )
                              : const _SinGps(),
                        ),
                      ),

                      // Botones de acción
                      _ActionBtn(
                        icon:    Icons.edit_rounded,
                        color:   AppColores.primary,
                        tooltip: 'Editar empresa',
                        onTap:   onEditar,
                      ),
                      _ActionBtn(
                        icon:    Icons.delete_outline_rounded,
                        color:   AppColores.danger,
                        tooltip: 'Eliminar empresa',
                        onTap:   onEliminar,
                      ),
                      const SizedBox(width: 4),
                    ],
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

class _AvatarEmpresa extends StatelessWidget {
  final String nombre;
  const _AvatarEmpresa({required this.nombre});

  Color _colorForName(String name) {
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC04),
      const Color(0xFFEA4335),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF607D8B),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForName(nombre);
    final inicial = nombre.isNotEmpty
        ? nombre[0].toUpperCase()
        : '?';
    return Container(
      width:  46,
      height: 46,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          inicial,
          style: TextStyle(
            fontSize:   20,
            fontWeight: FontWeight.w800,
            color:      color,
          ),
        ),
      ),
    );
  }
}

class _BadgeInactiva extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Inactiva',
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      AppColores.textSecond,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    color;
  const _InfoRow(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
          maxLines:  1,
          overflow:  TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

class _GpsChip extends StatelessWidget {
  final double lat;
  final double lng;
  const _GpsChip({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.my_location_rounded,
          size: 13, color: AppColores.success),
      const SizedBox(width: 4),
      Text(
        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        style: const TextStyle(
          fontSize:      11,
          color:         AppColores.success,
          fontWeight:    FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ]);
  }
}

class _SinGps extends StatelessWidget {
  const _SinGps();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.location_off_outlined,
          size: 13, color: Colors.grey.shade400),
      const SizedBox(width: 4),
      Text('Sin ubicación GPS',
          style: TextStyle(
              fontSize: 11, color: Colors.grey.shade400)),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData   icon;
  final Color      color;
  final String     tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DIÁLOGO ELIMINAR — rediseñado
// ══════════════════════════════════════════════════════════
class _DialogEliminar extends StatelessWidget {
  final EmpresaAdmin empresa;
  final VoidCallback onConfirmar;
  const _DialogEliminar(
      {required this.empresa, required this.onConfirmar});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:           RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono central
            Container(
              width:  60,
              height: 60,
              decoration: BoxDecoration(
                color:        AppColores.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Icon(Icons.delete_forever_rounded,
                    color: AppColores.danger, size: 30),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Text('¿Eliminar empresa?',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      AppColores.textPrimary,
                )),
            const SizedBox(height: 8),

            // Descripción
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    color: AppColores.textSecond,
                    fontSize: 14,
                    height:   1.5),
                children: [
                  const TextSpan(text: 'Vas a eliminar '),
                  TextSpan(
                    text: empresa.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color:      AppColores.textPrimary,
                    ),
                  ),
                  const TextSpan(text: '. Esta acción no se puede deshacer.'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Aviso
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColores.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColores.warning.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColores.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Si tiene clientes asociados, no se puede eliminar. '
                      'Desactívala desde "Editar" en su lugar.',
                      style: TextStyle(
                          fontSize: 12,
                          color:    AppColores.warning,
                          height:   1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botones
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side:    BorderSide(color: Colors.grey.shade300),
                    shape:   RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:      AppColores.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.danger,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Eliminar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FORMULARIO EMPRESA — rediseñado
// ══════════════════════════════════════════════════════════
class _FormEmpresa extends ConsumerStatefulWidget {
  final EmpresaAdmin?                  empresa;
  final Function(Map<String, dynamic>) onGuardar;
  const _FormEmpresa({this.empresa, required this.onGuardar});

  @override
  ConsumerState<_FormEmpresa> createState() => _FormEmpresaState();
}

class _FormEmpresaState extends ConsumerState<_FormEmpresa> {
  late final _nombreCtrl  = TextEditingController(
      text: widget.empresa?.nombre);
  late final _dirCtrl     = TextEditingController(
      text: widget.empresa?.direccion);
  late final _teleCtrl    = TextEditingController(
      text: widget.empresa?.telefono);
  late final _latCtrl     = TextEditingController(
      text: widget.empresa?.latitud?.toString() ?? '');
  late final _lngCtrl     = TextEditingController(
      text: widget.empresa?.longitud?.toString() ?? '');
  final      _urlMapsCtrl = TextEditingController();

  final _formKey   = GlobalKey<FormState>();
  bool  _estaActiva = true;
  bool  _cargando   = false;
  bool  _parseando  = false;
  bool? _telefonoOk;
  bool? _latitudOk;
  bool? _longitudOk;

  // Para controlar qué sección está expandida
  bool _gpsExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.empresa != null) {
      _estaActiva = widget.empresa!.estaActiva;

      final t = widget.empresa?.telefono ?? '';
      if (t.isNotEmpty) {
        _telefonoOk = Validators.telefonoEcuador(t) == null;
      }
      final lat = widget.empresa?.latitud?.toString() ?? '';
      if (lat.isNotEmpty) {
        _latitudOk  = Validators.latitud(lat)  == null;
        _gpsExpanded = true;
      }
      final lng = widget.empresa?.longitud?.toString() ?? '';
      if (lng.isNotEmpty) {
        _longitudOk = Validators.longitud(lng) == null;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _teleCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _urlMapsCtrl.dispose();
    super.dispose();
  }

  // ── Validación en tiempo real ─────────────────────────
  void _onTelefonoChange(String v) {
    if (v.isEmpty) { setState(() => _telefonoOk = null); return; }
    setState(() => _telefonoOk = Validators.telefonoEcuador(v) == null);
  }

  void _onLatitudChange(String v) {
    if (v.isEmpty) { setState(() => _latitudOk = null); return; }
    setState(() => _latitudOk = Validators.latitud(v) == null);
  }

  void _onLongitudChange(String v) {
    if (v.isEmpty) { setState(() => _longitudOk = null); return; }
    setState(() => _longitudOk = Validators.longitud(v) == null);
  }

  // ── Helpers decoración ────────────────────────────────
  Color _borde(bool? ok) {
    if (ok == null) return Colors.grey.shade300;
    return ok ? AppColores.success : AppColores.danger;
  }

  Color _fondo(bool? ok) {
    if (ok == null) return Colors.white;
    return ok
        ? AppColores.success.withOpacity(0.04)
        : AppColores.danger.withOpacity(0.04);
  }

  Widget? _sufixIcon(bool? ok) {
    if (ok == null) return null;
    return Icon(
      ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: ok ? AppColores.success : AppColores.danger,
      size:  20,
    );
  }

  InputDecoration _deco({
    required String   label,
    required IconData prefixIcono,
    bool?   ok,
    String? hint,
  }) =>
      InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(prefixIcono,
            color: ok == true
                ? AppColores.success
                : ok == false
                    ? AppColores.danger
                    : Colors.grey.shade500,
            size: 20),
        suffixIcon: _sufixIcon(ok),
        filled:     true,
        fillColor:  _fondo(ok),
        labelStyle: TextStyle(
          color: ok == true
              ? AppColores.success
              : ok == false
                  ? AppColores.danger
                  : Colors.grey.shade600,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: _borde(ok),
              width: ok != null ? 1.5 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: ok == null ? AppColores.primary : _borde(ok),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColores.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColores.danger, width: 2),
        ),
        errorStyle: const TextStyle(fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  // ── Parsear URL Google Maps ───────────────────────────
  Future<void> _parsearUrl() async {
    final url = _urlMapsCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() => _parseando = true);
    final resultado = await ref
        .read(adminOpProvider.notifier)
        .parsearUrlMaps(url);
    setState(() => _parseando = false);

    if (resultado != null) {
      final lat    = resultado['latitud'];
      final lng    = resultado['longitud'];
      final nombre = resultado['place_name'];

      setState(() {
        _latCtrl.text = lat?.toString() ?? '';
        _lngCtrl.text = lng?.toString() ?? '';
        _latitudOk    = lat != null;
        _longitudOk   = lng != null;
        _gpsExpanded  = true;
        if (_nombreCtrl.text.trim().isEmpty &&
            nombre != null &&
            (nombre as String).isNotEmpty) {
          _nombreCtrl.text = nombre;
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('¡Coordenadas extraídas correctamente!',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
            backgroundColor: AppColores.success,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
        _urlMapsCtrl.clear();
      }
    } else {
      final error = ref.read(adminOpProvider).error;
      if (context.mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(error),
          backgroundColor: AppColores.danger,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
        ref.read(adminOpProvider.notifier).resetear();
      }
    }
  }

  // ── Guardar ───────────────────────────────────────────
  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _cargando = true);
    await widget.onGuardar({
      'nombre':      _nombreCtrl.text.trim(),
      'direccion':   _dirCtrl.text.trim().isEmpty
          ? null
          : _dirCtrl.text.trim(),
      'telefono':    _teleCtrl.text.trim().isEmpty
          ? null
          : _teleCtrl.text.trim(),
      'latitud':     _latCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_latCtrl.text.trim()),
      'longitud':    _lngCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_lngCtrl.text.trim()),
      'esta_activa': _estaActiva,
    });
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion   = widget.empresa != null;
    final mediaQuery  = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle visual ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header del form ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Container(
                width:  38,
                height: 38,
                decoration: BoxDecoration(
                  color:        (esEdicion
                      ? AppColores.primary
                      : AppColores.warning).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  esEdicion
                      ? Icons.edit_rounded
                      : Icons.add_business_rounded,
                  color: esEdicion
                      ? AppColores.primary
                      : AppColores.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esEdicion ? 'Editar Empresa' : 'Nueva Empresa',
                    style: const TextStyle(
                      fontSize:   17,
                      fontWeight: FontWeight.w800,
                      color:      AppColores.textPrimary,
                    ),
                  ),
                  Text(
                    esEdicion
                        ? 'Modifica los datos de la empresa'
                        : 'Completa la información básica',
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond),
                  ),
                ],
              ),
            ]),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Cuerpo scrollable ──────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, mediaQuery.viewInsets.bottom + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Sección: Info básica ─────────────
                    _SectionLabel(
                        label: 'Información básica',
                        icon:  Icons.info_outline_rounded),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller:  _nombreCtrl,
                      decoration: _deco(
                        label:       'Nombre de la empresa *',
                        prefixIcono: Icons.business_rounded,
                        hint:        'Ej. Distribuidora Pérez',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        if (v.trim().length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _dirCtrl,
                      decoration: _deco(
                        label:       'Dirección',
                        prefixIcono: Icons.location_on_outlined,
                        hint:        'Ej. Av. Principal y Secundaria',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller:    _teleCtrl,
                      keyboardType:  TextInputType.phone,
                      maxLength:     10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged:   _onTelefonoChange,
                      decoration: _deco(
                        label:       'Teléfono',
                        prefixIcono: Icons.phone_outlined,
                        ok:          _telefonoOk,
                        hint:        '09XXXXXXXX o 07XXXXXXX',
                      ).copyWith(counterText: ''),
                      validator: (v) => Validators.telefonoEcuador(v),
                    ),

                    // ── Sección: Ubicación GPS ────────────
                    const SizedBox(height: 20),
                    _SectionLabel(
                        label: 'Ubicación GPS',
                        icon:  Icons.my_location_rounded),
                    const SizedBox(height: 10),

                    // Sub-sección: Pegar URL
                    _UrlMapsBox(
                      controller: _urlMapsCtrl,
                      parseando:  _parseando,
                      onParsear:  _parsearUrl,
                    ),
                    const SizedBox(height: 14),

                    // Toggle para coordenadas manuales
                    GestureDetector(
                      onTap: () =>
                          setState(() => _gpsExpanded = !_gpsExpanded),
                      child: Row(children: [
                        Icon(
                          _gpsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColores.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _gpsExpanded
                              ? 'Ocultar coordenadas manuales'
                              : 'Ingresar coordenadas manualmente',
                          style: const TextStyle(
                            fontSize:      13,
                            fontWeight:    FontWeight.w600,
                            color:         AppColores.primary,
                            decoration:    TextDecoration.underline,
                          ),
                        ),
                      ]),
                    ),

                    // Coordenadas expandibles
                    AnimatedCrossFade(
                      firstChild:  const SizedBox.shrink(),
                      secondChild: Column(
                        children: [
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller:   _latCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^-?\d*\.?\d*')),
                                ],
                                onChanged: _onLatitudChange,
                                decoration: _deco(
                                  label:       'Latitud',
                                  prefixIcono: Icons.swap_vert_rounded,
                                  ok:          _latitudOk,
                                  hint:        '-0.2342',
                                ),
                                validator: (v) =>
                                    Validators.latitud(v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller:   _lngCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^-?\d*\.?\d*')),
                                ],
                                onChanged: _onLongitudChange,
                                decoration: _deco(
                                  label:       'Longitud',
                                  prefixIcono: Icons.swap_horiz_rounded,
                                  ok:          _longitudOk,
                                  hint:        '-78.5249',
                                ),
                                validator: (v) =>
                                    Validators.longitud(v),
                              ),
                            ),
                          ]),
                        ],
                      ),
                      crossFadeState: _gpsExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                      sizeCurve: Curves.easeInOut,
                    ),

                    // ── Switch activa (solo edición) ──────
                    if (esEdicion) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color:        _estaActiva
                              ? AppColores.success.withOpacity(0.06)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _estaActiva
                                ? AppColores.success.withOpacity(0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: SwitchListTile(
                          value:     _estaActiva,
                          onChanged: (v) =>
                              setState(() => _estaActiva = v),
                          title: Text(
                            _estaActiva
                                ? 'Empresa activa'
                                : 'Empresa inactiva',
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color: _estaActiva
                                  ? AppColores.success
                                  : AppColores.textSecond,
                            ),
                          ),
                          subtitle: Text(
                            _estaActiva
                                ? 'Los clientes pueden ser asignados'
                                : 'No aparecerá en asignaciones',
                            style: TextStyle(
                              fontSize: 12,
                              color: _estaActiva
                                  ? AppColores.success.withOpacity(0.8)
                                  : Colors.grey.shade400,
                            ),
                          ),
                          activeColor:    AppColores.success,
                          contentPadding:
                              const EdgeInsets.fromLTRB(14, 4, 8, 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Botón guardar ─────────────────────
                    SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esEdicion
                              ? AppColores.primary
                              : AppColores.warning,
                          foregroundColor: Colors.white,
                          elevation:       0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          disabledBackgroundColor:
                              Colors.grey.shade300,
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width:  22,
                                height: 22,
                                child:  CircularProgressIndicator(
                                    color:       Colors.white,
                                    strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    esEdicion
                                        ? Icons.save_rounded
                                        : Icons.add_business_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    esEdicion
                                        ? 'Guardar cambios'
                                        : 'Crear empresa',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize:   16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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

// ══════════════════════════════════════════════════════════
//  WIDGETS DE APOYO DEL FORMULARIO
// ══════════════════════════════════════════════════════════

/// Etiqueta de sección con ícono
class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: AppColores.primary),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize:      13,
          fontWeight:    FontWeight.w700,
          color:         AppColores.primary,
          letterSpacing: 0.2,
        ),
      ),
    ]);
  }
}

/// Caja para pegar URL de Google Maps
class _UrlMapsBox extends StatelessWidget {
  final TextEditingController controller;
  final bool         parseando;
  final VoidCallback onParsear;

  const _UrlMapsBox({
    required this.controller,
    required this.parseando,
    required this.onParsear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColores.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instrucción con pasos visuales
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.share_location_rounded,
                  color: AppColores.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importar desde Google Maps',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                      color:      AppColores.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Busca la empresa en Google Maps\n'
                    '2. Toca "Compartir" → copia el enlace\n'
                    '3. Pégalo aquí y toca Extraer',
                    style: TextStyle(
                      fontSize: 11,
                      color:    AppColores.textSecond,
                      height:   1.5,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Campo + botón
          Row(children: [
            Expanded(
              child: TextField(
                controller:   controller,
                keyboardType: TextInputType.url,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText:  'https://maps.app.goo.gl/…',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond),
                  prefixIcon: const Icon(Icons.link_rounded,
                      size: 18, color: AppColores.textSecond),
                  filled:    true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColores.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: parseando ? null : onParsear,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primary,
                  foregroundColor: Colors.white,
                  elevation:       0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: parseando
                    ? const SizedBox(
                        width:  18,
                        height: 18,
                        child:  CircularProgressIndicator(
                            color:       Colors.white,
                            strokeWidth: 2),
                      )
                    : const Text(
                        'Extraer',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   13,
                        ),
                      ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}