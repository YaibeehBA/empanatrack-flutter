import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/ubicacion_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pedidos_cliente_provider.dart';

class TrackingPedidoScreen extends ConsumerStatefulWidget {
  final PedidoCliente pedido;
  const TrackingPedidoScreen({super.key, required this.pedido});

  @override
  ConsumerState<TrackingPedidoScreen> createState() =>
      _TrackingPedidoScreenState();
}

class _TrackingPedidoScreenState
    extends ConsumerState<TrackingPedidoScreen> {
  final _mapCtrl   = MapController();
  final _trackSvc  = TrackingClienteService();

  LatLng? _posVendedor;
  List<LatLng> _ruta = [];
  bool    _cargandoRuta = false;
  bool    _cercano      = false;
  static const double _alerta = 500;

  @override
  void initState() {
    super.initState();
    _conectarTracking();
  }

  @override
  void dispose() {
    _trackSvc.dispose();
    super.dispose();
  }

  Future<void> _conectarTracking() async {
    final token = ref.read(authProvider).sesion?.token ?? '';
    await _trackSvc.conectar(
      token:    token,
      baseUrl:  ApiClient.baseUrl,
      pedidoId: widget.pedido.id,
    );

    // Escuchar posición del vendedor
    _trackSvc.posicionVendedor.listen((pos) async {
      if (!mounted) return;
      setState(() => _posVendedor = pos);

      // Centrar mapa en el vendedor
      _mapCtrl.move(pos, _mapCtrl.camera.zoom);

      // Verificar cercanía si tenemos coordenadas del cliente
      if (widget.pedido.latitudEntrega != null) {
        final dist = _haversine(
          pos.latitude, pos.longitude,
          widget.pedido.latitudEntrega!,
          widget.pedido.longitudEntrega!,
        );
        if (dist <= _alerta && !_cercano) {
          setState(() => _cercano = true);
        }
      }

      // Recalcular ruta cada vez que el vendedor se mueve
      if (widget.pedido.latitudEntrega != null) {
        await _cargarRuta(pos);
      }
    });
  }

  Future<void> _cargarRuta(LatLng origen) async {
    if (widget.pedido.latitudEntrega == null) return;
    if (_cargandoRuta) return;

    final destino = LatLng(
      widget.pedido.latitudEntrega!,
      widget.pedido.longitudEntrega!,
    );

    _cargandoRuta = true;
    final url =
        'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
        '${origen.longitude},${origen.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final r = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'EmpanaTrack/1.0'})
          .timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        final data   = jsonDecode(r.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          final puntos = coords.map((c) => LatLng(
            (c[1] as num).toDouble(), (c[0] as num).toDouble(),
          )).toList();
          if (mounted) setState(() => _ruta = puntos);
        }
      }
    } catch (_) {}
    _cargandoRuta = false;
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    final dLat = _rad(la2 - la1);
    final dLon = _rad(lo2 - lo1);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_rad(la1))*cos(_rad(la2))*sin(dLon/2)*sin(dLon/2);
    return r * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  double _rad(double d) => d * pi / 180;

  @override
  Widget build(BuildContext context) {
    final destino = widget.pedido.latitudEntrega != null
        ? LatLng(widget.pedido.latitudEntrega!,
            widget.pedido.longitudEntrega!)
        : null;

    final centro = _posVendedor ?? destino ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Tu pedido en camino',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(children: [

        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
              initialCenter: centro, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.empanatrack.app',
            ),

            // Ruta por calles
            if (_ruta.length > 2)
              PolylineLayer(polylines: [
                Polyline(points: _ruta, color: Colors.white,
                    strokeWidth: 7, strokeCap: StrokeCap.round),
                Polyline(points: _ruta, color: AppColores.success,
                    strokeWidth: 5, strokeCap: StrokeCap.round),
              ]),

            MarkerLayer(markers: [
              // Vendedor (se mueve en tiempo real)
              if (_posVendedor != null)
                Marker(
                  point: _posVendedor!, width: 52, height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color:  AppColores.success,
                      shape:  BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(
                          color: AppColores.success.withOpacity(0.5),
                          blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.delivery_dining,
                        color: Colors.white, size: 26),
                  ),
                ),

              // Mi ubicación (cliente)
              if (destino != null)
                Marker(
                  point: destino, width: 52, height: 60,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        AppColores.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Yo',
                          style: TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.home, color: AppColores.primary, size: 28),
                  ]),
                ),
            ]),
          ],
        ),

        // Sin señal del vendedor
        if (_posVendedor == null)
          Positioned(top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8)],
              ),
              child: const Row(children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text(
                  'Esperando ubicación del repartidor...',
                  style: TextStyle(fontSize: 13),
                )),
              ]),
            ),
          ),

        // Alerta cerca
        if (_cercano)
          Positioned(top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColores.success,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: AppColores.success.withOpacity(0.4),
                    blurRadius: 8)],
              ),
              child: const Row(children: [
                Text('🎉', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Tu pedido está cerca!',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('El repartidor está a menos de 500m.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                )),
              ]),
            ),
          ),

        // Panel inferior info pedido
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
              boxShadow: [BoxShadow(
                  color: Colors.black26, blurRadius: 12,
                  offset: Offset(0, -2))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColores.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining,
                      color: AppColores.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pedido.vendedorNombre != null
                          ? '${widget.pedido.vendedorNombre} está en camino'
                          : 'Pedido en camino',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14,
                          color: AppColores.textPrimary),
                    ),
                    Text(
                      '\$${widget.pedido.total.toStringAsFixed(2)} — '
                      '${widget.pedido.tipoPago == 'contraentrega'
                          ? 'Paga al recibir' : 'Ya pagado'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColores.textSecond),
                    ),
                  ],
                )),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}