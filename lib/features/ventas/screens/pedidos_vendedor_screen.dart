import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/services/ubicacion_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pedidos_vendedor_provider.dart';

// ══════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL — PEDIDOS DISPONIBLES
// ══════════════════════════════════════════════════════════
class PedidosVendedorScreen extends ConsumerWidget {
  const PedidosVendedorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponiblesAsync = ref.watch(pedidosDisponiblesProvider);
    final activoAsync = ref.watch(pedidoActivoProvider);
    final wsService = WebSocketService();
    final token = ref.read(authProvider).sesion?.token ?? '';

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // ── Indicador estado WebSocket ─────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: wsService.estado == WsEstado.conectado
                  ? 'Tiempo real activo'
                  : 'Reconectando...',
              child: Icon(
                wsService.estado == WsEstado.conectado
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: wsService.estado == WsEstado.conectado
                    ? Colors.greenAccent
                    : Colors.white54,
                size: 20,
              ),
            ),
          ),
          // ── Botón refresh manual ──────────────────────
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(pedidosDisponiblesProvider.notifier).recargar();
              ref.read(pedidoActivoProvider.notifier).recargar();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(pedidosDisponiblesProvider.notifier).recargar();
          ref.read(pedidoActivoProvider.notifier).recargar();
          return Future.value();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Pedido activo (si tiene uno) ────────────
            activoAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (activo) => activo == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _SecLabel('MI PEDIDO ACTIVO'),
                        const SizedBox(height: 8),
                        _CardPedidoActivo(
                          pedido: activo,
                          token: token,
                          baseUrl: ApiClient.baseUrl,
                          onVerMapa: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _MapaEntregaScreen(
                                pedido: activo,
                                token: token,
                                baseUrl: ApiClient.baseUrl,
                              ),
                            ),
                          ),
                          onActualizar: () {
                            ref.read(pedidoActivoProvider.notifier).recargar();
                            ref
                                .read(pedidosDisponiblesProvider.notifier)
                                .recargar();
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),

            // ── Pedidos disponibles ─────────────────────
            _SecLabel('PEDIDOS DISPONIBLES'),
            const SizedBox(height: 8),

            disponiblesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _ErrorVista(
                onReintentar: () =>
                    ref.read(pedidosDisponiblesProvider.notifier).recargar(),
              ),
              data: (pedidos) => pedidos.isEmpty
                  ? const _SinPedidos()
                  : Column(
                      children: pedidos
                          .map(
                            (p) => _CardPedidoDisponible(
                              pedido: p,
                              onAceptar: () =>
                                  _confirmarAceptar(context, ref, p),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarAceptar(
    BuildContext context,
    WidgetRef ref,
    PedidoVendedor pedido,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aceptar pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColores.textPrimary,
                  fontSize: 14,
                ),
                children: [
                  const TextSpan(text: '¿Aceptar el pedido de '),
                  TextSpan(
                    text: pedido.clienteNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' por \$${pedido.total.toStringAsFixed(2)}?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColores.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColores.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColores.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solo un vendedor puede aceptar cada pedido. '
                      'Una vez aceptado desaparece para los demás.',
                      style: TextStyle(fontSize: 12, color: AppColores.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          Consumer(
            builder: (ctx, ref2, _) {
              final state = ref2.watch(aceptarPedidoProvider);
              ref2.listen<AceptarPedidoState>(aceptarPedidoProvider, (_, next) {
                if (next.exitoso) {
                  Navigator.pop(ctx);
                  ref.read(pedidosDisponiblesProvider.notifier).recargar();
                  ref.read(pedidoActivoProvider.notifier).recargar();
                  ref2.read(aceptarPedidoProvider.notifier).resetear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Pedido aceptado'),
                      backgroundColor: AppColores.success,
                    ),
                  );
                }
                if (next.error != null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(next.error!),
                      backgroundColor: AppColores.danger,
                    ),
                  );
                  ref2.read(aceptarPedidoProvider.notifier).resetear();
                }
              });
              return ElevatedButton(
                onPressed: state.cargando
                    ? null
                    : () => ref2
                          .read(aceptarPedidoProvider.notifier)
                          .aceptar(pedido.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: state.cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Aceptar'),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD PEDIDO DISPONIBLE
// ══════════════════════════════════════════════════════════
class _CardPedidoDisponible extends StatelessWidget {
  final PedidoVendedor pedido;
  final VoidCallback onAceptar;
  const _CardPedidoDisponible({required this.pedido, required this.onAceptar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColores.primary.withOpacity(0.12),
                child: Text(
                  pedido.clienteNombre.isNotEmpty
                      ? pedido.clienteNombre[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColores.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.clienteNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.textPrimary,
                      ),
                    ),
                    Text(
                      _formatFecha(DateTime.parse(pedido.creadoEn)),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColores.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          ...pedido.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 5,
                    color: AppColores.textSecond,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item['cantidad']}x ${item['nombre']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColores.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColores.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Chips info
          Row(
            children: [
              _InfoChip(
                icono: pedido.tipoPago == 'transferencia'
                    ? Icons.account_balance
                    : Icons.delivery_dining,
                texto: pedido.tipoPago == 'transferencia'
                    ? 'Transferencia'
                    : 'Contraentrega',
                color: pedido.tipoPago == 'transferencia'
                    ? AppColores.accent
                    : AppColores.warning,
              ),
              const SizedBox(width: 8),
              if (pedido.tieneCoordenadas)
                const _InfoChip(
                  icono: Icons.location_on,
                  texto: 'Con GPS',
                  color: AppColores.success,
                )
              else if (pedido.direccionEntrega != null)
                const _InfoChip(
                  icono: Icons.location_on_outlined,
                  texto: 'Con dirección',
                  color: AppColores.primary,
                ),
            ],
          ),

          if (pedido.notas != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notes,
                    size: 14,
                    color: AppColores.textSecond,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pedido.notas!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textSecond,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Botón aceptar
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onAceptar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'Aceptar pedido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD PEDIDO ACTIVO
// ══════════════════════════════════════════════════════════
class _CardPedidoActivo extends ConsumerWidget {
  final PedidoVendedor pedido;
  final String token;
  final String baseUrl;
  final VoidCallback onVerMapa;
  final VoidCallback onActualizar;

  const _CardPedidoActivo({
    required this.pedido,
    required this.token,
    required this.baseUrl,
    required this.onVerMapa,
    required this.onActualizar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.primary, AppColores.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColores.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pedido en curso',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      pedido.clienteNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              pedido.estado == 'aceptado'
                  ? '✅ Aceptado — preparando entrega'
                  : '🚚 En camino',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (pedido.direccionEntrega != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pedido.direccionEntrega!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          Row(
            children: [
              // Botón ver mapa
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pedido.tieneCoordenadas ? onVerMapa : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Ver ruta', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),

              // Botón marcar en camino / entregado
              Expanded(
                child: Consumer(
                  builder: (ctx, ref2, _) {
                    final state = ref2.watch(aceptarPedidoProvider);
                    return ElevatedButton.icon(
                      onPressed: state.cargando
                          ? null
                          : () => _cambiarEstado(ctx, ref2),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pedido.estado == 'aceptado'
                            ? AppColores.warning
                            : AppColores.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        pedido.estado == 'aceptado'
                            ? Icons.directions_bike
                            : Icons.check_circle,
                        size: 16,
                      ),
                      label: Text(
                        pedido.estado == 'aceptado' ? 'En camino' : 'Entregado',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cambiarEstado(BuildContext context, WidgetRef ref) {
    final nuevoEstado = pedido.estado == 'aceptado' ? 'en_camino' : 'entregado';
    final label = nuevoEstado == 'en_camino' ? 'en camino' : 'entregado';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Marcar como $label'),
        content: Text(
          '¿Confirmas que el pedido de '
          '${pedido.clienteNombre} está $label?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(aceptarPedidoProvider.notifier)
                  .actualizarEstado(pedido.id, nuevoEstado);
              onActualizar();
              ref.read(aceptarPedidoProvider.notifier).resetear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MAPA DE ENTREGA
// ══════════════════════════════════════════════════════════
class _MapaEntregaScreen extends StatefulWidget {
  final PedidoVendedor pedido;
  final String token;
  final String baseUrl;

  const _MapaEntregaScreen({
    required this.pedido,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<_MapaEntregaScreen> createState() => _MapaEntregaScreenState();
}

class _MapaEntregaScreenState extends State<_MapaEntregaScreen> {
  final _mapCtrl = MapController();
  LatLng? _miPosicion;
  List<LatLng> _rutaCalles = [];
  double? _distanciaMetros;
  bool _cargando = true;
  bool _cercaDelFin = false;
  bool _siguiendoVendedor = true;
  static const double _alerta = 500;

  final _ubicSvc = UbicacionVendedorService();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _ubicSvc.detener();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _obtenerPosicion();
    if (_miPosicion != null) await _cargarRutaOSRM();
    if (mounted) setState(() => _cargando = false);

    // Iniciar envío de ubicación en tiempo real
    await _ubicSvc.iniciar(
      token: widget.token,
      baseUrl: widget.baseUrl,
      pedidoId: widget.pedido.id,
    );

    // Actualizar marcador al moverse
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final nueva = LatLng(pos.latitude, pos.longitude);
      setState(() => _miPosicion = nueva);

      // Seguir al vendedor en el mapa
      if (_siguiendoVendedor) {
        _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
      }

      // Verificar cercanía
      if (widget.pedido.tieneCoordenadas) {
        _verificarCercania(
          LatLng(widget.pedido.latitudEntrega!, widget.pedido.longitudEntrega!),
        );
      }
    });
  }

  Future<void> _obtenerPosicion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever)
        return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _miPosicion = LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      print('❌ [GPS] $e');
    }
  }

  Future<void> _cargarRutaOSRM() async {
    if (_miPosicion == null || !widget.pedido.tieneCoordenadas) return;

    final origen = _miPosicion!;
    final destino = LatLng(
      widget.pedido.latitudEntrega!,
      widget.pedido.longitudEntrega!,
    );

    final url =
        'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
        '${origen.longitude},${origen.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson';

    print('🗺️ [OSRM] Llamando: $url');

    try {
      final r = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EmpanaTrack/1.0'})
          .timeout(const Duration(seconds: 15));

      print('🗺️ [OSRM] Status: ${r.statusCode}');

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          final puntos = coords
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
          final dist = routes[0]['distance'] as num? ?? 0;
          if (mounted) {
            setState(() {
              _rutaCalles = puntos;
              _distanciaMetros = dist.toDouble();
            });
          }
          print(
            '✅ [OSRM] Ruta con ${puntos.length} puntos, '
            '${dist.toStringAsFixed(0)}m',
          );
          _ajustarZoom(origen, destino);
          _verificarCercania(destino);
        }
      } else {
        print('❌ [OSRM] Error ${r.statusCode}: ${r.body}');
        if (mounted) setState(() => _rutaCalles = [origen, destino]);
        _ajustarZoom(origen, destino);
      }
    } catch (e) {
      print('❌ [OSRM] Excepción: $e');
      if (mounted) setState(() => _rutaCalles = [origen, destino]);
      _ajustarZoom(origen, destino);
    }
  }

  void _ajustarZoom(LatLng o, LatLng d) {
    final minLat = min(o.latitude, d.latitude);
    final maxLat = max(o.latitude, d.latitude);
    final minLng = min(o.longitude, d.longitude);
    final maxLng = max(o.longitude, d.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(minLat - 0.003, minLng - 0.003),
              LatLng(maxLat + 0.003, maxLng + 0.003),
            ),
            padding: const EdgeInsets.all(60),
          ),
        );
      } catch (_) {}
    });
  }

  void _verificarCercania(LatLng destino) {
    if (_miPosicion == null) return;
    final dist = _haversine(
      _miPosicion!.latitude,
      _miPosicion!.longitude,
      destino.latitude,
      destino.longitude,
    );
    if (dist <= _alerta && mounted && !_cercaDelFin) {
      setState(() => _cercaDelFin = true);
    }
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    final dLat = _rad(la2 - la1);
    final dLon = _rad(lo2 - lo1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(la1)) * cos(_rad(la2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  String _formatDist() {
    if (_distanciaMetros == null) return '';
    return _distanciaMetros! < 1000
        ? '${_distanciaMetros!.toStringAsFixed(0)} m'
        : '${(_distanciaMetros! / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final destino = widget.pedido.tieneCoordenadas
        ? LatLng(widget.pedido.latitudEntrega!, widget.pedido.longitudEntrega!)
        : null;
    final centro = _miPosicion ?? destino ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Ruta — ${widget.pedido.clienteNombre}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Toggle seguir/libre
          IconButton(
            icon: Icon(
              _siguiendoVendedor ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            tooltip: _siguiendoVendedor
                ? 'Siguiendo tu posición'
                : 'Vista libre',
            onPressed: () =>
                setState(() => _siguiendoVendedor = !_siguiendoVendedor),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _cargando = true;
                _rutaCalles = [];
                _cercaDelFin = false;
              });
              await _obtenerPosicion();
              await _cargarRutaOSRM();
              if (mounted) setState(() => _cargando = false);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 15,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _siguiendoVendedor) {
                  setState(() => _siguiendoVendedor = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.empanatrack.app',
              ),

              // Ruta real por calles
              if (_rutaCalles.length > 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _rutaCalles,
                      color: Colors.white,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                    ),
                    Polyline(
                      points: _rutaCalles,
                      color: AppColores.primary,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),

              // Fallback punteado
              if (_rutaCalles.length == 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _rutaCalles,
                      color: AppColores.primary.withOpacity(0.5),
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      pattern: StrokePattern.dashed(segments: const [8, 4]),
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // Posición vendedor (tiempo real)
                  if (_miPosicion != null)
                    Marker(
                      point: _miPosicion!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColores.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColores.primary.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bike,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                  // Destino cliente
                  if (destino != null)
                    Marker(
                      point: destino,
                      width: 60,
                      height: 70,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColores.danger,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.pedido.clienteNombre.split(' ').first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: AppColores.danger,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Spinner
          if (_cargando)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculando ruta...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Alerta cerca
          if (_cercaDelFin && !_cargando)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColores.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColores.success.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Estás cerca!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'A menos de 500m del cliente.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Botón volver a centrar (cuando está en vista libre)
          if (!_siguiendoVendedor && _miPosicion != null)
            Positioned(
              right: 16,
              bottom: 180,
              child: FloatingActionButton.small(
                onPressed: () {
                  setState(() => _siguiendoVendedor = true);
                  _mapCtrl.move(_miPosicion!, _mapCtrl.camera.zoom);
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.gps_fixed, color: AppColores.primary),
              ),
            ),

          // Panel inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: AppColores.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.pedido.clienteNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColores.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '\$${widget.pedido.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColores.primary,
                        ),
                      ),
                    ],
                  ),
                  if (widget.pedido.direccionEntrega != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColores.textSecond,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.pedido.direccionEntrega!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.textSecond,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (widget.pedido.tipoPago == 'contraentrega'
                                      ? AppColores.success
                                      : AppColores.primary)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.pedido.tipoPago == 'contraentrega'
                                  ? Icons.payments_outlined
                                  : Icons.account_balance_outlined,
                              size: 14,
                              color: widget.pedido.tipoPago == 'contraentrega'
                                  ? AppColores.success
                                  : AppColores.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.pedido.tipoPago == 'contraentrega'
                                  ? 'Cobrar al entregar'
                                  : 'Ya fue pagado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.pedido.tipoPago == 'contraentrega'
                                    ? AppColores.success
                                    : AppColores.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_distanciaMetros != null) ...[
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              size: 14,
                              color: AppColores.textSecond,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDist(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColores.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════
String _formatFecha(DateTime fecha) {
  final ahora = DateTime.now();
  final diff = ahora.difference(fecha);

  if (diff.inMinutes < 1) return 'Justo ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';

  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';
}

// ══════════════════════════════════════════════════════════
//  WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════
class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);
  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: AppColores.textSecond,
      letterSpacing: 1.0,
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _InfoChip({
    required this.icono,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Column(
        children: [
          Text('📭', style: TextStyle(fontSize: 52)),
          SizedBox(height: 16),
          Text(
            'Sin pedidos disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColores.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando un cliente haga un pedido\naparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColores.textSecond),
          ),
        ],
      ),
    ),
  );
}

class _ErrorVista extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorVista({required this.onReintentar});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        const Text(
          'Error al cargar pedidos',
          style: TextStyle(color: AppColores.textSecond),
        ),
        ElevatedButton(
          onPressed: onReintentar,
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}
