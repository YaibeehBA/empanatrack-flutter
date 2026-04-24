import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/ubicacion_service.dart';
import '../models/pedido_models.dart';
import '../providers/pedidos_providers.dart';
import '../../auth/providers/auth_provider.dart';

class MapaEntregaScreen extends ConsumerStatefulWidget {
  final PedidoBase pedido;
  const MapaEntregaScreen({super.key, required this.pedido});

  @override
  ConsumerState<MapaEntregaScreen> createState() =>
      _MapaEntregaScreenState();
}

class _MapaEntregaScreenState
    extends ConsumerState<MapaEntregaScreen> {

  final _mapCtrl  = MapController();
  final _ubicSvc  = UbicacionVendedorService();

  LatLng?      _miPosicion;
  List<LatLng> _rutaCalles     = [];
  bool         _cargando       = true;
  bool         _cercaDelFin    = false;
  bool         _siguiendo      = true;
  double?      _distanciaMetros;
  double?      _minutosEstimados;

  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _ubicSvc.detener();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _obtenerPosicion();
    if (_miPosicion != null) {
      await _cargarRutaOSRM();
      await _calcularTiempoEstimado();
    }
    if (mounted) setState(() => _cargando = false);

    // Iniciar transmisión GPS al cliente
    final token   = ref.read(authProvider).sesion?.token ?? '';
    final baseUrl = ApiClient.baseUrl;
    await _ubicSvc.iniciar(
        token: token, baseUrl: baseUrl,
        pedidoId: widget.pedido.id);

    // GPS stream para actualizar marcador y ruta
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((pos) async {
      if (!mounted) return;
      final nueva = LatLng(pos.latitude, pos.longitude);
      setState(() => _miPosicion = nueva);
      if (_siguiendo) _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
      _verificarCercania();
      // Recalcular tiempo cada 30 segundos de movimiento
      await _calcularTiempoEstimado();
    });
  }

  Future<void> _obtenerPosicion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() =>
            _miPosicion = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _cargarRutaOSRM() async {
    if (_miPosicion == null ||
        !widget.pedido.tieneCoordenadas) return;

    final origen  = _miPosicion!;
    final destino = LatLng(widget.pedido.latitudEntrega!,
                           widget.pedido.longitudEntrega!);
    final url =
        'https://routing.openstreetmap.de/routed-foot'
        '/route/v1/foot/'
        '${origen.longitude},${origen.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final r = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'EmpanaTrack/1.0'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final routes = jsonDecode(r.body)['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final raw = routes[0]['geometry']['coordinates'] as List;
          final pts = raw.map((c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          )).toList();
          final dist = routes[0]['distance'] as num? ?? 0;
          if (mounted) {
            setState(() {
              _rutaCalles     = pts;
              _distanciaMetros = dist.toDouble();
            });
          }
          _ajustarZoom(origen, destino);
          _verificarCercania();
        }
      }
    } catch (_) {}
  }

  Future<void> _calcularTiempoEstimado() async {
    if (_miPosicion == null ||
        !widget.pedido.tieneCoordenadas) return;
    try {
      final r = await ApiClient.get(
        '/pedidos/${widget.pedido.id}/tiempo-estimado',
        params: {
          'lat_rep': _miPosicion!.latitude,
          'lng_rep': _miPosicion!.longitude,
        },
      );
      final tiempo = TiempoEstimado.fromJson(r.data);
      if (mounted) {
        setState(() => _minutosEstimados = tiempo.minutos);
      }
    } catch (_) {}
  }

  void _ajustarZoom(LatLng o, LatLng d) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(min(o.latitude, d.latitude)   - 0.003,
                   min(o.longitude, d.longitude) - 0.003),
            LatLng(max(o.latitude, d.latitude)   + 0.003,
                   max(o.longitude, d.longitude) + 0.003),
          ),
          padding: const EdgeInsets.all(60),
        ));
      } catch (_) {}
    });
  }

  void _verificarCercania() {
    if (_miPosicion == null || !widget.pedido.tieneCoordenadas) return;
    final dist = _haversine(
      _miPosicion!.latitude,  _miPosicion!.longitude,
      widget.pedido.latitudEntrega!,
      widget.pedido.longitudEntrega!,
    );
    if (dist <= 500 && mounted && !_cercaDelFin) {
      setState(() => _cercaDelFin = true);
    }
  }

  double _haversine(double la1, double lo1,
                    double la2, double lo2) {
    const r    = 6371000.0;
    final dLat = _rad(la2 - la1), dLon = _rad(lo2 - lo1);
    final a    = sin(dLat/2)*sin(dLat/2) +
        cos(_rad(la1))*cos(_rad(la2))*sin(dLon/2)*sin(dLon/2);
    return r * 2 * atan2(sqrt(a), sqrt(1-a));
  }
  double _rad(double d) => d * pi / 180;

  String _formatDist() {
    if (_distanciaMetros == null) return '';
    return _distanciaMetros! < 1000
        ? '${_distanciaMetros!.toStringAsFixed(0)} m'
        : '${(_distanciaMetros!/1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final destino = widget.pedido.tieneCoordenadas
        ? LatLng(widget.pedido.latitudEntrega!,
                 widget.pedido.longitudEntrega!)
        : null;
    final centro = _miPosicion ?? destino
        ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: Text('Entrega — ${widget.pedido.clienteNombre}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () async {
              setState(() { _cargando = true; _rutaCalles = []; });
              await _obtenerPosicion();
              await _cargarRutaOSRM();
              await _calcularTiempoEstimado();
              if (mounted) setState(() => _cargando = false);
            },
          ),
          // Toggle seguir
          IconButton(
            icon: Icon(_siguiendo
                ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () =>
                setState(() => _siguiendo = !_siguiendo),
          ),
        ],
      ),
      body: Stack(children: [

        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: centro,
            initialZoom:   15,
            onPositionChanged: (_, gesture) {
              if (gesture && _siguiendo) {
                setState(() => _siguiendo = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.empanatrack.app',
            ),
            // Ruta por calles
            if (_rutaCalles.length > 2)
              PolylineLayer(polylines: [
                Polyline(points: _rutaCalles,
                    color: Colors.white, strokeWidth: 7,
                    strokeCap: StrokeCap.round),
                Polyline(points: _rutaCalles,
                    color: AppColores.primary, strokeWidth: 5,
                    strokeCap: StrokeCap.round),
              ]),
            MarkerLayer(markers: [
              // Posición repartidor
              if (_miPosicion != null)
                Marker(
                  point:  _miPosicion!,
                  width:  24, height: 24,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color:  AppColores.primary,
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(
                          color: AppColores.primary.withOpacity(0.4),
                          blurRadius: 6, spreadRadius: 1)],
                    ),
                  ),
                ),
              // Destino
              if (destino != null)
                Marker(
                  point:  destino,
                  width:  60, height: 70,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColores.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.pedido.clienteNombre
                            .split(' ').first,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.location_on,
                        color: AppColores.danger, size: 28),
                  ]),
                ),
            ]),
          ],
        ),

        // Spinner cargando ruta
        if (_cargando)
          Positioned(top: 16, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8)]),
              child: const Row(mainAxisSize: MainAxisSize.min,
                  children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Calculando ruta...',
                    style: TextStyle(fontSize: 12)),
              ]),
            )),
          ),

        // Alerta cerca
        if (_cercaDelFin && !_cargando)
          Positioned(top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColores.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: AppColores.success.withOpacity(0.4),
                      blurRadius: 8)]),
              child: const Row(children: [
                Text('🎯', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Estás cerca!',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('A menos de 500m del cliente.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                )),
              ]),
            ),
          ),

        // Botón recentrar
        if (!_siguiendo && _miPosicion != null)
          Positioned(right: 16, bottom: 200,
            child: FloatingActionButton.small(
              heroTag:         'centrar_entrega',
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() => _siguiendo = true);
                _mapCtrl.move(_miPosicion!, _mapCtrl.camera.zoom);
              },
              child: const Icon(Icons.my_location_rounded,
                  color: AppColores.primary),
            ),
          ),

        // Panel inferior — info pedido + tiempo estimado
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
              boxShadow: [BoxShadow(
                  color: Colors.black26, blurRadius: 12,
                  offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.person_outline,
                      color: AppColores.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                      widget.pedido.clienteNombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColores.textPrimary))),
                  Text('\$${widget.pedido.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColores.primary)),
                ]),
                if (widget.pedido.direccionEntrega != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColores.textSecond),
                    const SizedBox(width: 4),
                    Expanded(child: Text(
                        widget.pedido.direccionEntrega!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.textSecond))),
                  ]),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  // Tipo pago
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (widget.pedido.tipoPago == 'contraentrega'
                              ? AppColores.success : AppColores.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(
                        widget.pedido.tipoPago == 'contraentrega'
                            ? Icons.payments_outlined
                            : Icons.account_balance_outlined,
                        size: 14,
                        color: widget.pedido.tipoPago == 'contraentrega'
                            ? AppColores.success : AppColores.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.pedido.tipoPago == 'contraentrega'
                            ? 'Cobrar al entregar'
                            : 'Ya fue pagado',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: widget.pedido.tipoPago == 'contraentrega'
                              ? AppColores.success : AppColores.primary,
                        ),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  // Distancia + tiempo estimado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_distanciaMetros != null)
                        Row(children: [
                          const Icon(Icons.directions_walk,
                              size: 13, color: AppColores.textSecond),
                          const SizedBox(width: 3),
                          Text(_formatDist(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.textSecond)),
                        ]),
                      if (_minutosEstimados != null)
                        Row(children: [
                          const Icon(Icons.access_time,
                              size: 13, color: AppColores.primary),
                          const SizedBox(width: 3),
                          Text(
                            '~${_minutosEstimados!.round()} min',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColores.primary),
                          ),
                        ]),
                    ],
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}