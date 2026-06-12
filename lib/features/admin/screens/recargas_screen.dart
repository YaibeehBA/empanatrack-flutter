import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';

// ── Modelo ────────────────────────────────────────────────
class SolicitudRecarga {
  final String recargaId;
  final String sesionId;
  final String vendedorNombre;
  final String vendedorId;
  final String estado;
  final String? notas;
  final String solicitadoEn;
  final List<Map<String, dynamic>>? productos;

  const SolicitudRecarga({
    required this.recargaId,
    required this.sesionId,
    required this.vendedorNombre,
    required this.vendedorId,
    required this.estado,
    this.notas,
    required this.solicitadoEn,
    this.productos,
  });

  factory SolicitudRecarga.fromJson(Map<String, dynamic> j) => SolicitudRecarga(
    recargaId:      j['recarga_id'],
    sesionId:       j['sesion_id'],
    vendedorNombre: j['vendedor_nombre'] ?? '',
    vendedorId:     j['vendedor_id'],
    estado:         j['estado'],
    notas:          j['notas'],
    solicitadoEn:   j['solicitado_en'],
    productos:      j['productos'] != null
        ? List<Map<String, dynamic>>.from(j['productos'])
        : null,
  );
}

// ── Provider ──────────────────────────────────────────────
class SolicitudesRecargaNotifier
    extends StateNotifier<AsyncValue<List<SolicitudRecarga>>> {
  SolicitudesRecargaNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  StreamSubscription? _wsSub;

  Future<void> _init() async {
    await _cargar();
    _escucharWs();
  }

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.get('/ruta-activa/solicitudes-recarga');
      state = AsyncValue.data(
        (r.data as List).map((s) => SolicitudRecarga.fromJson(s)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _escucharWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketService().mensajes.listen((msg) {
      if (msg['tipo'] == 'solicitud_recarga') {
        final nueva = SolicitudRecarga(
          recargaId:      msg['recarga_id'],
          sesionId:       msg['sesion_id'],
          vendedorNombre: msg['vendedor_nombre'],
          vendedorId:     msg['vendedor_id'],
          estado:         'pendiente',
          notas:          msg['notas'],
          solicitadoEn:   msg['solicitado_en'],
          productos:      msg['productos'] != null
              ? List<Map<String, dynamic>>.from(msg['productos'])
              : null,
        );
        state.whenData((lista) {
          state = AsyncValue.data([nueva, ...lista]);
        });
      }
    });
  }

  Future<void> recargar() => _cargar();

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

final solicitudesRecargaProvider =
    StateNotifierProvider<SolicitudesRecargaNotifier,
        AsyncValue<List<SolicitudRecarga>>>(
  (ref) => SolicitudesRecargaNotifier(),
);

// ══════════════════════════════════════════════════════════
//  PANTALLA
// ══════════════════════════════════════════════════════════
class RecargasScreen extends ConsumerWidget {
  const RecargasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(solicitudesRecargaProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Solicitudes de Recarga',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(solicitudesRecargaProvider.notifier).recargar(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (_, __) => Center(
          child: TextButton(
            onPressed: () =>
                ref.read(solicitudesRecargaProvider.notifier).recargar(),
            child: const Text('Reintentar'),
          ),
        ),
        data: (solicitudes) {
          if (solicitudes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📦', style: TextStyle(fontSize: 52)),
                  SizedBox(height: 16),
                  Text('Sin solicitudes pendientes',
                      style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.bold,
                          color:      AppColores.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                    'Cuando un vendedor solicite recarga\naparecerá aquí en tiempo real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColores.textSecond),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(solicitudesRecargaProvider.notifier).recargar(),
            child: ListView.builder(
              padding:     const EdgeInsets.all(16),
              itemCount:   solicitudes.length,
              itemBuilder: (_, i) => _TarjetaSolicitud(
                solicitud:  solicitudes[i],
                onResponder: () =>
                    _mostrarDialogoResponder(context, ref, solicitudes[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarDialogoResponder(
    BuildContext context,
    WidgetRef ref,
    SolicitudRecarga solicitud,
  ) {
    showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      backgroundColor:  Colors.transparent,
      builder: (_) => _FormResponder(
        solicitud:   solicitud,
        onResponder: () =>
            ref.read(solicitudesRecargaProvider.notifier).recargar(),
      ),
    );
  }
}

// ── Tarjeta solicitud ─────────────────────────────────────
class _TarjetaSolicitud extends StatelessWidget {
  final SolicitudRecarga solicitud;
  final VoidCallback     onResponder;
  const _TarjetaSolicitud({required this.solicitud, required this.onResponder});

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border(left: BorderSide(color: AppColores.warning, width: 4)),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8, offset: const Offset(0, 2),
      )],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColores.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColores.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(solicitud.vendedorNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   15,
                      color:      AppColores.textPrimary)),
              Row(children: [
                const Icon(Icons.access_time,
                    size: 11, color: AppColores.textSecond),
                const SizedBox(width: 4),
                Text(_formatFecha(solicitud.solicitadoEn),
                    style: const TextStyle(
                        fontSize: 11, color: AppColores.textSecond)),
              ]),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColores.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('PENDIENTE',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: AppColores.warning)),
          ),
        ]),

        // Productos solicitados
        const SizedBox(height: 12),
        const Text('PRODUCTOS SOLICITADOS',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: AppColores.textSecond, letterSpacing: 0.8)),
        const SizedBox(height: 8),

        if (solicitud.productos != null && solicitud.productos!.isNotEmpty)
          Container(
            padding:    const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColores.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              for (final prod in solicitud.productos!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(prod['nombre'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.textPrimary))),
                    Text('${prod['cantidad'] ?? 0} unidades',
                        style: const TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.bold,
                            color:      AppColores.accent)),
                  ]),
                ),
            ]),
          ),

        if (solicitud.notas != null && solicitud.notas!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.notes, size: 13, color: AppColores.textSecond),
              const SizedBox(width: 6),
              Expanded(child: Text(solicitud.notas!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond))),
            ]),
          ),
        ],

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton.icon(
            onPressed: onResponder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon:  const Icon(Icons.reply_rounded, size: 18),
            label: const Text('Responder solicitud',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );

  String _formatFecha(String f) {
    try {
      final dt = DateTime.parse(f).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')} — '
          '${dt.day}/${dt.month}';
    } catch (_) {
      return f;
    }
  }
}

// ── Formulario de respuesta ───────────────────────────────
class _FormResponder extends ConsumerStatefulWidget {
  final SolicitudRecarga solicitud;
  final VoidCallback     onResponder;
  const _FormResponder({required this.solicitud, required this.onResponder});

  @override
  ConsumerState<_FormResponder> createState() => _FormResponderState();
}

class _FormResponderState extends ConsumerState<_FormResponder> {
  final _latCtrl   = TextEditingController();
  final _lngCtrl   = TextEditingController();
  final _dirCtrl   = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _cargando = false;

  // ✅ Mapa editable de cantidades: productoId → cantidad
  late Map<String, int> _cantidades;

  @override
  void initState() {
    super.initState();
    // Inicializar con las cantidades solicitadas
    _cantidades = {
      for (final p in widget.solicitud.productos ?? [])
        (p['producto_id'] as String): (p['cantidad'] as num).toInt(),
    };
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _dirCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _responder(String accion) async {
    if (accion == 'aceptar') {
      if (_latCtrl.text.trim().isEmpty || _lngCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Ingresa latitud y longitud del punto de recarga'),
          backgroundColor: AppColores.danger,
        ));
        return;
      }
    }

    setState(() => _cargando = true);
    try {
      // ✅ CLAVE: siempre mandar productos con las cantidades (editadas o no)
      final productosPayload = (widget.solicitud.productos ?? []).map((p) => {
        'producto_id': p['producto_id'],
        'nombre':      p['nombre'],
        'cantidad':    _cantidades[p['producto_id'] as String] ?? p['cantidad'],
        'precio':      p['precio'],
      }).toList();

      await ApiClient.post(
        '/ruta-activa/responder-recarga',
        data: {
          'recarga_id': widget.solicitud.recargaId,
          'accion':     accion,
          'productos':  productosPayload, // ✅ siempre incluido
          if (accion == 'aceptar') ...{
            'lat_recarga': double.tryParse(_latCtrl.text.trim()),
            'lng_recarga': double.tryParse(_lngCtrl.text.trim()),
            'direccion_recarga': _dirCtrl.text.trim().isEmpty
                ? null : _dirCtrl.text.trim(),
          },
          'notas_admin': _notasCtrl.text.trim().isEmpty
              ? null : _notasCtrl.text.trim(),
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onResponder();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accion == 'aceptar'
              ? '✅ Recarga aprobada — vendedor notificado'
              : '❌ Solicitud rechazada'),
          backgroundColor: accion == 'aceptar'
              ? AppColores.success : AppColores.danger,
        ));
      }
    } catch (e) {
      setState(() => _cargando = false);
      final msg = RegExp(r'"detail":"([^"]+)"')
          .firstMatch(e.toString())?.group(1) ?? 'Error al responder';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColores.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
      20, 16, 20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize:      MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),

          Text('Responder a ${widget.solicitud.vendedorNombre}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                  color:      AppColores.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Puedes ajustar las cantidades antes de aprobar.',
            style: TextStyle(fontSize: 12, color: AppColores.textSecond),
          ),
          const SizedBox(height: 16),

          // ✅ Productos editables
          if (widget.solicitud.productos != null &&
              widget.solicitud.productos!.isNotEmpty) ...[
            const Text('PRODUCTOS A APROBAR',
                style: TextStyle(
                    fontSize:    10,
                    fontWeight:  FontWeight.bold,
                    color:       AppColores.textSecond,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Container(
              padding:    const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                for (final prod in widget.solicitud.productos!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod['nombre'] ?? '',
                              style: const TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                  color:      AppColores.textPrimary)),
                          Text('Solicitó: ${prod['cantidad']}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color:    AppColores.textSecond)),
                        ],
                      )),
                      // Control cantidad
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _BtnCant(
                          icono: Icons.remove,
                          color: (_cantidades[prod['producto_id']] ?? 0) > 0
                              ? AppColores.danger : Colors.grey,
                          onTap: (_cantidades[prod['producto_id']] ?? 0) > 0
                              ? () => setState(() =>
                                  _cantidades[prod['producto_id'] as String] =
                                      (_cantidades[prod['producto_id']] ?? 0) - 1)
                              : null,
                        ),
                        SizedBox(
                          width: 36,
                          child: Center(child: Text(
                            '${_cantidades[prod['producto_id']] ?? 0}',
                            style: const TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                                color:      AppColores.primary),
                          )),
                        ),
                        _BtnCant(
                          icono: Icons.add,
                          color: AppColores.primary,
                          onTap: () => setState(() =>
                              _cantidades[prod['producto_id'] as String] =
                                  (_cantidades[prod['producto_id']] ?? 0) + 1),
                        ),
                      ]),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Coordenadas
          const Text('PUNTO DE RECARGA *',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold,
                  color: AppColores.textSecond, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller:   _latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Latitud', hintText: '-1.6654',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColores.background,
                isDense: true,
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller:   _lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Longitud', hintText: '-78.6543',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColores.background,
                isDense: true,
              ),
            )),
          ]),
          const SizedBox(height: 10),

          TextField(
            controller: _dirCtrl,
            decoration: InputDecoration(
              labelText:  'Dirección (opcional)',
              hintText:   'Ej: Av. Principal y Calle 5',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: AppColores.background,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            decoration: InputDecoration(
              labelText:  'Notas para el vendedor (opcional)',
              hintText:   'Ej: Pregunta por Carlos en bodega',
              prefixIcon: const Icon(Icons.notes_rounded),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: AppColores.background,
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),

          // Botones
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _cargando ? null : () => _responder('rechazar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColores.danger,
                side:  BorderSide(color: AppColores.danger.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Rechazar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _cargando ? null : () => _responder('aceptar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _cargando
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Aprobar recarga',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
    ),
  );
}

class _BtnCant extends StatelessWidget {
  final IconData      icono;
  final Color         color;
  final VoidCallback? onTap;
  const _BtnCant({required this.icono, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(onTap == null ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: color.withOpacity(onTap == null ? 0.1 : 0.2)),
      ),
      child: Icon(icono, size: 14,
          color: onTap == null ? Colors.grey.shade300 : color),
    ),
  );
}
