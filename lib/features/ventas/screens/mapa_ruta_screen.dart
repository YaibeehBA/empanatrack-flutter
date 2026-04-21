import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/colores.dart';
import '../../../../core/network/api_client.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';
import '../shell/shell_providers.dart';
import '../widgets/ruta_header.dart';
import '../widgets/toast_alerta.dart';
import '../widgets/empresa_marker.dart';
import '../widgets/empresa_panel.dart';
import '../widgets/panel_inferior_ruta.dart';
import 'dashboard_screen.dart';
import 'stock_diario_screen.dart';

const double _kDistanciaInicio = 300.0;
const double _kDistanciaEmpresa = 150.0;

class MapaRutaScreen extends ConsumerStatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  ConsumerState<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends ConsumerState<MapaRutaScreen> {
  FaseRuta _fase = FaseRuta.cargando;
  EstadoRutaHoy? _estadoHoy;
  String? _sesionId;
  LatLng? _miPosicion;
  List<LatLng> _rutaCalles = [];
  EmpresaRuta? _empresaCercana;
  DateTime? _llegadaEmpresa;
  bool _mostrarAlerta = false;
  bool _siguiendo = true;
  bool _panelCargando = false;
  bool _mostrarMapaCompletada = false;  // Controla si mostrar mapa cuando está completada

  final _mapCtrl = MapController();
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void didUpdateWidget(MapaRutaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo reinitializar si NO está completada
    // Si ya está completada, simplemente volver a mostrar el mapa con estado actual
    if (_fase != FaseRuta.completada && _fase != FaseRuta.enRuta) {
      _inicializar();
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  INICIALIZACIÓN
  // ══════════════════════════════════════════════════════
  Future<void> _inicializar() async {
    setState(() => _fase = FaseRuta.cargando);

    // Siempre obtener posición al inicio, sin importar la fase
    await _obtenerPosicion(); // ← mueve aquí, antes del try

    try {
      final r = await ApiClient.get('/ruta-activa/estado-hoy');
      final estado = EstadoRutaHoy.fromJson(r.data);
      _estadoHoy = estado;

      // Debug: Mostrar estado de la ruta
      debugPrint('📍 Estado de ruta: tieneRuta=${estado.tieneRuta}, completada=${estado.completada}, sesionCompletada=${estado.sesionCompletada}, sesion=${estado.sesion?.id}');

      // Invalidar stock al cargar
      ref.invalidate(stockRestanteProvider);

      if (!estado.tieneRuta) {
        setState(() => _fase = FaseRuta.sinRuta);
        return;
      }

      // Si la sesión ya fue completada hoy, ir directo al dashboard
      if (estado.completada || estado.sesionCompletada) {
        _sesionId = estado.sesion?.id ?? 'completada';
        debugPrint('🎯 Ruta completada detectada. sesionId: $_sesionId, completada: ${estado.completada}');
        // Reset mostrarMapa para mostrar dashboard primero
        ref.read(mostrarMapaCompletadaProvider.notifier).state = false;
        setState(() => _fase = FaseRuta.completada);
        return;
      }

      if (!estado.stockLleno) {
        setState(() => _fase = FaseRuta.llenarStock);
        return;
      }
      if (estado.sesion == null) {
        setState(() => _fase = FaseRuta.listo);
      } else {
        _sesionId = estado.sesion!.id;
        setState(() => _fase = FaseRuta.enRuta);
      }

      // Cargar ruta y GPS solo si hay empresas con coordenadas
      _cargarRutaOSRM();
      _iniciarGPS();
      _reordenarEmpresasPorDistancia();
    } catch (e) {
      debugPrint('Error init: $e');
      setState(() => _fase = FaseRuta.sinRuta);
    }
  }

  // ══════════════════════════════════════════════════════
  //  GPS
  // ══════════════════════════════════════════════════════
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
    } catch (_) {}
  }

  void _iniciarGPS() {
    _gpsSub?.cancel();
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((pos) {
          if (!mounted) return;
          final nueva = LatLng(pos.latitude, pos.longitude);
          setState(() => _miPosicion = nueva);
          if (_siguiendo) _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
          _verificarProximidad(nueva);
        });
  }

  // ══════════════════════════════════════════════════════
  //  OSRM
  // ══════════════════════════════════════════════════════
  Future<void> _cargarRutaOSRM() async {
    if (_miPosicion == null || _estadoHoy == null) return;
    final pendientes = _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas && !e.visitada)
        .toList();
    if (pendientes.isEmpty) return;

    final puntos = [
      _miPosicion!,
      ...pendientes.map((e) => LatLng(e.latitud!, e.longitud!)),
    ];
    final coords = puntos.map((p) => '${p.longitude},${p.latitude}').join(';');

    try {
      final r = await http
          .get(
            Uri.parse(
              'https://routing.openstreetmap.de/routed-foot'
              '/route/v1/foot/$coords'
              '?overview=full&geometries=geojson',
            ),
            headers: {'User-Agent': 'EmpanaTrack/1.0'},
          )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final routes = jsonDecode(r.body)['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final raw = routes[0]['geometry']['coordinates'] as List;
          final pts = raw
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
          if (mounted) setState(() => _rutaCalles = pts);
          _ajustarZoom(puntos);
        }
      }
    } catch (_) {}
  }

  void _ajustarZoom(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(minLat - 0.003, minLng - 0.003),
              LatLng(maxLat + 0.003, maxLng + 0.003),
            ),
            padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
          ),
        );
      } catch (_) {}
    });
  }

  // ══════════════════════════════════════════════════════
  //  REORDENAR POR DISTANCIA (nearest-neighbor)
  // ══════════════════════════════════════════════════════
  void _reordenarEmpresasPorDistancia() {
    if (_miPosicion == null || _estadoHoy == null) return;

    final pendientes = _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas && !e.visitada)
        .toList();
    if (pendientes.length < 2) return;

    final List<EmpresaRuta> ordenadas = [];
    final List<EmpresaRuta> restantes = List.from(pendientes);
    LatLng posActual = _miPosicion!;

    while (restantes.isNotEmpty) {
      restantes.sort((a, b) {
        final da = _haversine(
          posActual.latitude,
          posActual.longitude,
          a.latitud!,
          a.longitud!,
        );
        final db = _haversine(
          posActual.latitude,
          posActual.longitude,
          b.latitud!,
          b.longitud!,
        );
        return da.compareTo(db);
      });
      final siguiente = restantes.removeAt(0);
      ordenadas.add(siguiente);
      posActual = LatLng(siguiente.latitud!, siguiente.longitud!);
    }

    final visitadas = _estadoHoy!.empresas.where((e) => e.visitada).toList();
    final nuevasEmpresas = [...visitadas, ...ordenadas];

    setState(() {
      _estadoHoy = EstadoRutaHoy(
        tieneRuta: _estadoHoy!.tieneRuta,
        stockLleno: _estadoHoy!.stockLleno,
        asignacionId: _estadoHoy!.asignacionId,
        rutaId: _estadoHoy!.rutaId,
        rutaNombre: _estadoHoy!.rutaNombre,
        turno: _estadoHoy!.turno,
        sesion: _estadoHoy!.sesion,
        empresas: nuevasEmpresas,
        total: _estadoHoy!.total,
        visitadas: _estadoHoy!.visitadas,
        completada: _estadoHoy!.completada,
      );
    });
  }

  // ══════════════════════════════════════════════════════
  //  PROXIMIDAD
  // ══════════════════════════════════════════════════════
  void _verificarProximidad(LatLng pos) {
    if (_estadoHoy == null || _fase != FaseRuta.enRuta) return;

    for (final emp in _estadoHoy!.empresas.where(
      (e) => e.tieneCoordenadas && !e.visitada,
    )) {
      final dist = _haversine(
        pos.latitude,
        pos.longitude,
        emp.latitud!,
        emp.longitud!,
      );

      if (dist <= _kDistanciaEmpresa) {
        if (_empresaCercana?.id != emp.id) {
          setState(() {
            _empresaCercana = emp;
            _llegadaEmpresa = DateTime.now();
          });
          _registrarLlegada(emp);
        }
        return;
      }
    }

    if (_empresaCercana != null) {
      setState(() {
        _empresaCercana = null;
        _llegadaEmpresa = null;
      });
    }
  }

  Future<void> _registrarLlegada(EmpresaRuta emp) async {
    if (_sesionId == null || _miPosicion == null) return;
    await ref
        .read(rutaAccionProvider.notifier)
        .registrarLlegada(
          sesionId: _sesionId!,
          empresaId: emp.id,
          lat: _miPosicion!.latitude,
          lng: _miPosicion!.longitude,
        );
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    final dLat = _rad(la2 - la1), dLon = _rad(lo2 - lo1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(la1)) * cos(_rad(la2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  // ══════════════════════════════════════════════════════
  //  ACCIONES
  // ══════════════════════════════════════════════════════
  Future<void> _iniciarRuta() async {
    if (_miPosicion == null || _estadoHoy == null) return;

    final primera = _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas)
        .firstOrNull;

    if (primera != null) {
      final dist = _haversine(
        _miPosicion!.latitude,
        _miPosicion!.longitude,
        primera.latitud!,
        primera.longitud!,
      );
      if (dist > _kDistanciaInicio) {
        setState(() => _mostrarAlerta = true);
        return;
      }
    }

    setState(() => _panelCargando = true);
    final sesionId = await ref
        .read(rutaAccionProvider.notifier)
        .iniciarRuta(
          asignacionId: _estadoHoy!.asignacionId!,
          lat: _miPosicion!.latitude,
          lng: _miPosicion!.longitude,
        );

    if (sesionId != null && mounted) {
      setState(() {
        _sesionId = sesionId;
        _fase = FaseRuta.enRuta;
        _mostrarAlerta = false;
        _panelCargando = false;
      });
      _iniciarGPS();
    } else {
      setState(() => _panelCargando = false);
    }
  }

  Future<void> _marcarVisitada() async {
    if (_empresaCercana == null || _sesionId == null || _miPosicion == null)
      return;

    setState(() => _panelCargando = true);
    if (!mounted) return;

    final error = await ref
        .read(rutaAccionProvider.notifier)
        .marcarVisitada(
          sesionId: _sesionId!,
          empresaId: _empresaCercana!.id,
          lat: _miPosicion!.latitude,
          lng: _miPosicion!.longitude,
        );

    if (!mounted) return;

    if (error != null) {
      _mostrarSnack(error, error: true);
      setState(() => _panelCargando = false);
      return;
    }

    _estadoHoy = _estadoHoy!.marcarVisitada(_empresaCercana!.id);
    setState(() {
      _empresaCercana = null;
      _llegadaEmpresa = null;
      _panelCargando = false;
    });

    _reordenarEmpresasPorDistancia();
    _cargarRutaOSRM();

    // Invalidar stock después de marcar visitada
    ref.invalidate(stockRestanteProvider);

    if (_estadoHoy!.completada) await _completarRuta();
  }

  Future<void> _completarRuta() async {
    if (_sesionId == null) return;

    final success = await ref
        .read(rutaAccionProvider.notifier)
        .completarRuta(_sesionId!);

    if (!success) {
      if (mounted) {
        _mostrarSnack(
          'Error al finalizar ruta. Intenta de nuevo.',
          error: true,
        );
      }
      return;
    }

    // Invalidar todos los providers relacionados con la ruta
    // para que se recarguen desde el servidor
    ref.invalidate(estadoRutaHoyProvider);
    ref.invalidate(stockRestanteProvider);
    ref.invalidate(stockHoyProvider);

    if (mounted) setState(() => _fase = FaseRuta.completada);
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColores.danger : AppColores.success,
      ),
    );
  }

  Future<void> _abrirNuevaVenta() async {
    await context.push('/nueva-venta');
    // Al volver de la venta, refrescar stock restante
    if (mounted) {
      ref.invalidate(stockRestanteProvider);
    }
  }

  Widget _buildCompletada() {
    // No invalidar aquí — causa flutter error "setState during build"
    // La invalidación se hace en initState después de _inicializar
    return DashboardScreen(sesionId: _sesionId);
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Watch el provider para cambios desde dashboard
    final mostrarMapa = ref.watch(mostrarMapaCompletadaProvider);
    _mostrarMapaCompletada = mostrarMapa;
    
    switch (_fase) {
      case FaseRuta.cargando:
        return _scaffoldCargando();
      case FaseRuta.sinRuta:
        return _scaffoldSinRuta();
      case FaseRuta.llenarStock:
        return StockDiarioScreen(
          onStockConfirmado: () {
            _estadoHoy = EstadoRutaHoy(
              tieneRuta: _estadoHoy!.tieneRuta,
              stockLleno: true,
              asignacionId: _estadoHoy!.asignacionId,
              rutaId: _estadoHoy!.rutaId,
              rutaNombre: _estadoHoy!.rutaNombre,
              turno: _estadoHoy!.turno,
              sesion: _estadoHoy!.sesion,
              empresas: _estadoHoy!.empresas,
              total: _estadoHoy!.total,
              visitadas: _estadoHoy!.visitadas,
              completada: _estadoHoy!.completada,
            );
            setState(() => _fase = FaseRuta.listo);
            _obtenerPosicion();
            _cargarRutaOSRM();
          },
        );
      case FaseRuta.completada:
        // Si el usuario pidió ver el mapa, mostrar mapa completada
        // Si no, mostrar dashboard
        if (_mostrarMapaCompletada) {
          return _scaffoldMapa();
        } else {
          return _buildCompletada();
        }
      default:
        return _scaffoldMapa();
    }
  }

  Widget _scaffoldCargando() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _scaffoldSinRuta() => Scaffold(
    backgroundColor: AppColores.background,
    appBar: AppBar(
      backgroundColor: AppColores.primary,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      title: const Text(
        'Mi Ruta',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _inicializar),
      ],
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🗺️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 20),
            Text(
              'Sin ruta asignada hoy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColores.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'El administrador aún no te ha asignado una ruta para hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColores.textSecond, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );

  // ── MAPA ──────────────────────────────────────────────
  Widget _scaffoldMapa() {
    final enRuta = _fase == FaseRuta.enRuta;
    final completada = _fase == FaseRuta.completada;  // ✅ NUEVO
    final centro = _miPosicion ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Mapa base
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 14,
              onPositionChanged: (_, gesture) {
                if (gesture && _siguiendo) {
                  setState(() => _siguiendo = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.empanatrack.app',
              ),
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
                      color: const Color(0xFF1A73E8),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final emp in _estadoHoy?.empresas ?? [])
                    if (emp.tieneCoordenadas)
                      Marker(
                        point: LatLng(emp.latitud!, emp.longitud!),
                        width: 150,
                        height: 65,
                        child: EmpresaMarker(
                          empresa: emp,
                          esCercana: _empresaCercana?.id == emp.id,
                        ),
                      ),
                  if (_miPosicion != null)
                    Marker(
                      point: _miPosicion!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A73E8).withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RutaHeader(estado: _estadoHoy),
          ),

          // Toast alerta
          if (_mostrarAlerta)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: ToastAlerta(
                titulo: 'Debes estar en el punto de inicio',
                subtitulo:
                    'Dirígete a '
                    '${_estadoHoy?.empresas.firstOrNull?.nombre ?? "la primera empresa"}'
                    ' para comenzar.',
                onCerrar: () => setState(() => _mostrarAlerta = false),
              ),
            ),

          // Panel inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _empresaCercana != null && enRuta
                ? EmpresaPanel(
                    empresa: _empresaCercana!,
                    llegadaEn: _llegadaEmpresa,
                    cargando: _panelCargando,
                    onNuevaVenta: _abrirNuevaVenta,
                    onRegistrarCobro: () =>
                        context.push('/cobros/${_empresaCercana!.id}'),
                    onMarcarVisitada: _marcarVisitada,
                  )
                : completada
                    // Panel para ruta completada - solo mostrar resumen y botón volver
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColores.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColores.success,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColores.success,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ruta Completada',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Empresas visitadas: ${_estadoHoy?.visitadas}/${_estadoHoy?.total}',
                                            style: TextStyle(
                                              color: AppColores.textSecond,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColores.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    // Volver al dashboard
                                    ref.read(mostrarMapaCompletadaProvider.notifier).state = false;
                                  },
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.dashboard_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Ver Resumen del Día'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Consumer(
                        builder: (ctx, ref, _) {
                          final stockAsync = ref.watch(stockRestanteProvider);
                          final sinStock = stockAsync.maybeWhen(
                            data: (s) => s.sinStock,
                            orElse: () => false,
                          );
                          return PanelInferiorRuta(
                            estado: _estadoHoy,
                            enRuta: enRuta,
                            cargando: _panelCargando,
                            sinStock: sinStock && enRuta,
                            onIniciarRuta: _iniciarRuta,
                            onNuevaVenta: _abrirNuevaVenta,
                            onFinalizarRuta: _completarRuta,
                          );
                        },
                      ),
          ),

          // Botón recentrar
          if (!_siguiendo && _miPosicion != null)
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'centrar',
                backgroundColor: Colors.white,
                onPressed: () {
                  setState(() => _siguiendo = true);
                  _mapCtrl.move(_miPosicion!, _mapCtrl.camera.zoom);
                },
                child: const Icon(Icons.gps_fixed, color: Color(0xFF1A73E8)),
              ),
            ),
        ],
      ),
    );
  }
}
