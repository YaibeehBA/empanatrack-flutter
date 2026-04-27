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
import '../../auth/providers/auth_provider.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';
import '../shell/shell_providers.dart';
import '../../../core/services/ubicacion_service.dart';
import '../widgets/ruta_header.dart';
import '../widgets/toast_alerta.dart';
import '../widgets/empresa_marker.dart';
import '../widgets/empresa_panel.dart';
import '../widgets/panel_inferior_ruta.dart';
import 'dashboard_screen.dart';
import 'stock_diario_screen.dart';
import '../providers/reporte_provider.dart';
import '../providers/pedidos_vendedor_provider.dart';
import '../providers/ventas_provider.dart';

// ─────────────────────────────────────────────────────────
//  RADIOS
//  _kDistanciaInicio   → debes estar aquí para INICIAR ruta
//  _kDistanciaEmpresa  → debes estar aquí para ver panel
//                        de empresa y poder vender/marcar
// ─────────────────────────────────────────────────────────
const double _kDistanciaInicio = 30.0; // metros
const double _kDistanciaEmpresa = 30.0; // metros — mismo criterio

class MapaRutaScreen extends ConsumerStatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  ConsumerState<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends ConsumerState<MapaRutaScreen> {
  // ── Estado ────────────────────────────────────────────
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
  bool _optimizacionLista = false;
  bool _viendoResumen = false;

  // Primera empresa del orden optimizado.
  // El vendedor DEBE estar a ≤30 m de este punto para iniciar.
  EmpresaRuta? _puntoInicioOptimo;

  final _mapCtrl = MapController();
  StreamSubscription<Position>? _gpsSub;

  // ── Distancia en tiempo real al punto de inicio ───────
  double? get _distanciaAlInicio {
    if (_miPosicion == null || _puntoInicioOptimo == null) return null;
    if (_puntoInicioOptimo!.latitud == null ||
        _puntoInicioOptimo!.longitud == null)
      return null;
    return _haversine(
      _miPosicion!.latitude,
      _miPosicion!.longitude,
      _puntoInicioOptimo!.latitud!,
      _puntoInicioOptimo!.longitud!,
    );
  }

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    UbicacionRutaVendedorService().detener();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  INICIALIZACIÓN
  // ══════════════════════════════════════════════════════
  Future<void> _inicializar() async {
    setState(() {
      _fase = FaseRuta.cargando;
      _rutaCalles = [];
      _empresaCercana = null;
      _llegadaEmpresa = null;
      _optimizacionLista = false;
      _puntoInicioOptimo = null;
      _viendoResumen = false;
    });

    await _obtenerPosicion();

    try {
      final r = await ApiClient.get('/ruta-activa/estado-hoy');
      final estado = EstadoRutaHoy.fromJson(r.data);
      _estadoHoy = estado;

      ref.invalidate(stockRestanteProvider);

      if (!estado.tieneRuta) {
        setState(() => _fase = FaseRuta.sinRuta);
        return;
      }

      if (estado.sesionCompletada) {
        _sesionId = estado.sesion?.id;
        setState(() => _fase = FaseRuta.completada);
        return;
      }

      if (!estado.stockLleno) {
        setState(() => _fase = FaseRuta.llenarStock);
        return;
      }

     if (estado.sesion == null) {
        setState(() => _fase = FaseRuta.listo);
      } 
      else {
        _sesionId = estado.sesion!.id;
        setState(() => _fase = FaseRuta.enRuta);
      
      final sesion = ref.read(authProvider).sesion;
        if (sesion != null) {
          UbicacionRutaVendedorService().iniciar(
            token: sesion.token,
            baseUrl: ApiClient.baseUrl,
            sesionId: _sesionId!,
          );
        }
      }

      _iniciarGPS();
      await _optimizarYTrazarRuta();
    } catch (e) {
      debugPrint('Error init: $e');
      if (mounted) setState(() => _fase = FaseRuta.sinRuta);
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
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final nueva = LatLng(pos.latitude, pos.longitude);
        setState(() => _miPosicion = nueva);
        if (_siguiendo) _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
        _verificarProximidad(nueva);
        
        // ← NUEVO: transmitir posición para clientes
        if (_fase == FaseRuta.enRuta && _sesionId != null) {
          UbicacionRutaVendedorService()
              .enviarPosicion(pos.latitude, pos.longitude);
        }
      });
}

  // ══════════════════════════════════════════════════════
  //  OPTIMIZACIÓN DE RUTA
  // ══════════════════════════════════════════════════════
  Future<void> _optimizarYTrazarRuta() async {
    if (_miPosicion == null || _estadoHoy == null) return;

    if (mounted) setState(() => _optimizacionLista = false);

    final pendientes = _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas && !e.visitada)
        .toList();

    if (pendientes.isEmpty) {
      if (mounted) setState(() => _optimizacionLista = true);
      return;
    }

    if (pendientes.length == 1) {
      if (mounted)
        setState(() {
          _puntoInicioOptimo = pendientes[0];
          _optimizacionLista = true;
        });
      await _trazarSegmento(
        _miPosicion!,
        LatLng(pendientes[0].latitud!, pendientes[0].longitud!),
      );
      return;
    }

    final ordenOptimo = await _calcularMejorRutaCompleta(pendientes);
    final ordenFinal = ordenOptimo ?? _nearestNeighborLocal(pendientes);

    if (!mounted) return;

    if (ordenFinal.isNotEmpty) {
      setState(() {
        _puntoInicioOptimo = ordenFinal.first;
        _optimizacionLista = true;
      });
    }

    final visitadas = _estadoHoy!.empresas.where((e) => e.visitada).toList();
    setState(() {
      _estadoHoy = EstadoRutaHoy(
        tieneRuta: _estadoHoy!.tieneRuta,
        stockLleno: _estadoHoy!.stockLleno,
        asignacionId: _estadoHoy!.asignacionId,
        rutaId: _estadoHoy!.rutaId,
        rutaNombre: _estadoHoy!.rutaNombre,
        turno: _estadoHoy!.turno,
        sesion: _estadoHoy!.sesion,
        empresas: [...visitadas, ...ordenFinal],
        total: _estadoHoy!.total,
        visitadas: _estadoHoy!.visitadas,
        completada: _estadoHoy!.completada,
        sesionCompletada: _estadoHoy!.sesionCompletada,
      );
    });

    await _trazarRutaSegmentada(ordenFinal);
  }

  Future<List<EmpresaRuta>?> _calcularMejorRutaCompleta(
    List<EmpresaRuta> empresas,
  ) async {
    try {
      final puntos = [
        _miPosicion!,
        ...empresas.map((e) => LatLng(e.latitud!, e.longitud!)),
      ];
      final coords = puntos
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final url =
          'https://routing.openstreetmap.de/routed-foot'
          '/table/v1/foot/$coords?annotations=duration';

      final r = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EmpanaTrack/1.0'})
          .timeout(const Duration(seconds: 20));

      if (r.statusCode != 200) return null;

      final data = jsonDecode(r.body);
      final durations = data['durations'] as List?;
      if (durations == null || durations.isEmpty) return null;

      final matrix = durations
          .map(
            (row) => (row as List)
                .map((d) => (d as num?)?.toDouble() ?? double.infinity)
                .toList(),
          )
          .toList();

      List<EmpresaRuta>? mejorOrden;
      double mejorCosto = double.infinity;

      for (int inicioIdx = 0; inicioIdx < empresas.length; inicioIdx++) {
        final costoAlInicio = matrix[0][inicioIdx + 1];
        if (costoAlInicio == double.infinity) continue;

        final orden = <int>[inicioIdx];
        final resto = List<int>.generate(empresas.length, (i) => i)
          ..remove(inicioIdx);
        double costo = costoAlInicio;
        int actual = inicioIdx;

        while (resto.isNotEmpty) {
          int mejorSig = resto[0];
          double mejorT = double.infinity;
          for (final sig in resto) {
            final t = matrix[actual + 1][sig + 1];
            if (t < mejorT) {
              mejorT = t;
              mejorSig = sig;
            }
          }
          costo += mejorT;
          orden.add(mejorSig);
          resto.remove(mejorSig);
          actual = mejorSig;
        }

        if (costo < mejorCosto) {
          mejorCosto = costo;
          mejorOrden = orden.map((i) => empresas[i]).toList();
        }
      }
      return mejorOrden;
    } catch (e) {
      debugPrint('❌ OSRM Table error: $e');
      return null;
    }
  }

  List<EmpresaRuta> _nearestNeighborLocal(List<EmpresaRuta> empresas) {
    if (empresas.isEmpty) return [];

    List<EmpresaRuta>? mejorOrden;
    double mejorCosto = double.infinity;

    for (int inicioIdx = 0; inicioIdx < empresas.length; inicioIdx++) {
      final costoAlInicio = _haversine(
        _miPosicion!.latitude,
        _miPosicion!.longitude,
        empresas[inicioIdx].latitud!,
        empresas[inicioIdx].longitud!,
      );
      final orden = <int>[inicioIdx];
      final resto = List<int>.generate(empresas.length, (i) => i)
        ..remove(inicioIdx);
      double costo = costoAlInicio;
      int actual = inicioIdx;

      while (resto.isNotEmpty) {
        int mejorSig = resto[0];
        double mejorD = double.infinity;
        for (final sig in resto) {
          final d = _haversine(
            empresas[actual].latitud!,
            empresas[actual].longitud!,
            empresas[sig].latitud!,
            empresas[sig].longitud!,
          );
          if (d < mejorD) {
            mejorD = d;
            mejorSig = sig;
          }
        }
        costo += mejorD;
        orden.add(mejorSig);
        resto.remove(mejorSig);
        actual = mejorSig;
      }

      if (costo < mejorCosto) {
        mejorCosto = costo;
        mejorOrden = orden.map((i) => empresas[i]).toList();
      }
    }
    return mejorOrden ?? empresas;
  }

  Future<void> _trazarRutaSegmentada(
    List<EmpresaRuta> empresasOrdenadas,
  ) async {
    if (_miPosicion == null) return;

    final List<LatLng> rutaCompleta = [];
    LatLng origen = _miPosicion!;

    for (final emp in empresasOrdenadas) {
      final destino = LatLng(emp.latitud!, emp.longitud!);
      final segmento = await _trazarSegmentoCalles(origen, destino);

      if (segmento.isNotEmpty) {
        final seg = List<LatLng>.from(segmento);
        if (rutaCompleta.isNotEmpty && seg.isNotEmpty) seg.removeAt(0);
        rutaCompleta.addAll(seg);
      } else {
        if (rutaCompleta.isEmpty) rutaCompleta.add(origen);
        rutaCompleta.add(destino);
      }
      origen = destino;
    }

    if (mounted && rutaCompleta.isNotEmpty) {
      setState(() => _rutaCalles = rutaCompleta);
      _ajustarZoom([
        _miPosicion!,
        ...empresasOrdenadas.map((e) => LatLng(e.latitud!, e.longitud!)),
      ]);
    }
  }

  Future<List<LatLng>> _trazarSegmentoCalles(
    LatLng origen,
    LatLng destino,
  ) async {
    final url =
        'https://routing.openstreetmap.de/routed-foot'
        '/route/v1/foot/'
        '${origen.longitude},${origen.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson';

    for (int intento = 0; intento < 3; intento++) {
      try {
        final r = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'EmpanaTrack/1.0'})
            .timeout(const Duration(seconds: 12));

        if (r.statusCode == 200) {
          final data = jsonDecode(r.body);
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final raw = routes[0]['geometry']['coordinates'] as List;
            return raw
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
          }
        }
      } catch (_) {
        if (intento < 2) await Future.delayed(Duration(seconds: intento + 1));
      }
    }
    return [];
  }

  Future<void> _trazarSegmento(LatLng origen, LatLng destino) async {
    final pts = await _trazarSegmentoCalles(origen, destino);
    if (mounted) {
      setState(() => _rutaCalles = pts.isNotEmpty ? pts : [origen, destino]);
      _ajustarZoom([origen, destino]);
    }
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
  //  PROXIMIDAD
  //
  //  Solo muestra el panel de empresa cuando el vendedor
  //  está a ≤ _kDistanciaEmpresa (30 m) de ella.
  //  Así se evita que al reentrar con sesión activa ya
  //  aparezca el panel sin haberse movido hasta la empresa.
  // ══════════════════════════════════════════════════════
  void _verificarProximidad(LatLng pos) {
    if (_estadoHoy == null || _fase != FaseRuta.enRuta) return;

    EmpresaRuta? empCercana;
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
        empCercana = emp;
        break;
      }
    }

    if (empCercana == null) {
      if (_empresaCercana != null) {
        setState(() {
          _empresaCercana = null;
          _llegadaEmpresa = null;
        });
      }
      return;
    }

    if (_empresaCercana?.id != empCercana.id) {
      final llegadaBackend = empCercana.llegadaDateTime;
      final llegada = llegadaBackend ?? DateTime.now();
      setState(() {
        _empresaCercana = empCercana;
        _llegadaEmpresa = llegada;
      });
      if (llegadaBackend == null) _registrarLlegada(empCercana);
    }
  }

  Future<void> _registrarLlegada(EmpresaRuta emp) async {
    if (_sesionId == null || _miPosicion == null) return;

    final ok = await ref
        .read(rutaAccionProvider.notifier)
        .registrarLlegada(
          sesionId: _sesionId!,
          empresaId: emp.id,
          lat: _miPosicion!.latitude,
          lng: _miPosicion!.longitude,
        );

    if (ok && mounted) {
      final ahora = DateTime.now().toIso8601String();
      final nuevas = _estadoHoy!.empresas
          .map((e) => e.id == emp.id ? e.copyWith(llegadaEn: ahora) : e)
          .toList();
      setState(() {
        _estadoHoy = EstadoRutaHoy(
          tieneRuta: _estadoHoy!.tieneRuta,
          stockLleno: _estadoHoy!.stockLleno,
          asignacionId: _estadoHoy!.asignacionId,
          rutaId: _estadoHoy!.rutaId,
          rutaNombre: _estadoHoy!.rutaNombre,
          turno: _estadoHoy!.turno,
          sesion: _estadoHoy!.sesion,
          empresas: nuevas,
          total: _estadoHoy!.total,
          visitadas: _estadoHoy!.visitadas,
          completada: _estadoHoy!.completada,
          sesionCompletada: _estadoHoy!.sesionCompletada,
        );
        _llegadaEmpresa = DateTime.now();
      });
    }
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

    // GUARDIA 1 — OSRM aún calculando
    final hayEmpresas = _estadoHoy!.empresas.any(
      (e) => e.tieneCoordenadas && !e.visitada,
    );
    if (hayEmpresas && !_optimizacionLista) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    // GUARDIA 2 — no hay punto de inicio calculado
    final puntoInicio = _puntoInicioOptimo;
    if (puntoInicio == null ||
        puntoInicio.latitud == null ||
        puntoInicio.longitud == null) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    // GUARDIA 3 — está a más de 30 m del punto de inicio
    final dist = _haversine(
      _miPosicion!.latitude,
      _miPosicion!.longitude,
      puntoInicio.latitud!,
      puntoInicio.longitud!,
    );
    if (dist > _kDistanciaInicio) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    // ── Todo OK: iniciar ──────────────────────────────
    setState(() {
      _mostrarAlerta = false;
      _panelCargando = true;
    });

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

    ref.invalidate(stockRestanteProvider);
    await _optimizarYTrazarRuta();
    if (_estadoHoy!.completada) await _completarRuta();
  }

  Future<void> _completarRuta() async {
    if (_sesionId == null) return;
    UbicacionRutaVendedorService().detener();
    final success = await ref
        .read(rutaAccionProvider.notifier)
        .completarRuta(_sesionId!);

    if (!success) {
      if (mounted) _mostrarSnack('Error al finalizar ruta.', error: true);
      return;
    }

    ref.invalidate(estadoRutaHoyProvider);
    ref.invalidate(stockRestanteProvider);
    ref.invalidate(stockHoyProvider);

    final hoy = _fmtHoy();
    final rango = RangoFechas(desde: hoy, hasta: hoy);
    ref.invalidate(resumenPorFechasProvider(rango));
    ref.invalidate(historialPorFechasProvider(rango));
    ref.invalidate(pedidosHistorialProvider(rango));

    if (mounted) setState(() => _fase = FaseRuta.completada);
  }

  String _fmtHoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
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
    if (mounted) ref.invalidate(stockRestanteProvider);
  }

  void _irAlResumen() {
    setState(() => _fase = FaseRuta.completada);
  }

  void _irAlDashboard() {
    context.go('/dashboard');
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
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
              sesionCompletada: _estadoHoy!.sesionCompletada,
            );
            setState(() => _fase = FaseRuta.listo);
            _obtenerPosicion().then((_) => _optimizarYTrazarRuta());
          },
        );
  case FaseRuta.completada:
  _viendoResumen = true;
  return DashboardScreen(
    sesionId: _sesionId,
    onVolverAlMapa: () async {
      // Recargar el estado actualizado desde el backend
      try {
        final r = await ApiClient.get('/ruta-activa/estado-hoy');
        final nuevoEstado = EstadoRutaHoy.fromJson(r.data);
        _estadoHoy = nuevoEstado;
        _sesionId = nuevoEstado.sesion?.id;
      } catch (e) {
        debugPrint('Error recargando estado: $e');
      }
      
      setState(() {
        _fase = FaseRuta.enRuta;
        _viendoResumen = true;  // Mantener true para que el botón muestre "Ver resumen"
      });
    },
  );
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
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

  // ══════════════════════════════════════════════════════
  //  MAPA PRINCIPAL
  // ══════════════════════════════════════════════════════
  Widget _scaffoldMapa() {
    final enRuta = _fase == FaseRuta.enRuta;
    final centro = _miPosicion ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 14,
              onPositionChanged: (_, gesture) {
                if (gesture && _siguiendo) setState(() => _siguiendo = false);
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
                      color: AppColores.primary,
                      strokeWidth: 4,
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
                        width: 160,
                        height: 65,
                        child: EmpresaMarker(
                          empresa: emp,
                          esCercana: _empresaCercana?.id == emp.id,
                          esInicio: !enRuta && _puntoInicioOptimo?.id == emp.id,
                        ),
                      ),

                  if (_miPosicion != null)
                    Marker(
                      point: _miPosicion!,
                      width: 24,
                      height: 24,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColores.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColores.primary.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header progreso
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
                titulo: !_optimizacionLista
                    ? 'Calculando ruta óptima…'
                    : 'Debes estar en el punto de inicio',
                subtitulo: !_optimizacionLista
                    ? 'Espera un momento mientras se calcula la mejor ruta.'
                    : _puntoInicioOptimo != null
                    ? 'Dirígete a ${_puntoInicioOptimo!.nombre}. '
                          'Debes estar a menos de ${_kDistanciaInicio.toInt()} m.'
                    : 'Dirígete al punto de inicio para comenzar.',
                onCerrar: () => setState(() => _mostrarAlerta = false),
              ),
            ),

          // Panel inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPanelInferior(enRuta),
          ),

          // Botón recentrar GPS
          if (!_siguiendo && _miPosicion != null)
            Positioned(
              right: 16,
              bottom: 180,
              child: FloatingActionButton.small(
                heroTag: 'centrar',
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  setState(() => _siguiendo = true);
                  _mapCtrl.move(_miPosicion!, _mapCtrl.camera.zoom);
                },
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppColores.primary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Panel inferior ────────────────────────────────────
  Widget _buildPanelInferior(bool enRuta) {
    if (_empresaCercana != null && enRuta) {
      return EmpresaPanel(
        empresa: _empresaCercana!,
        llegadaEn: _llegadaEmpresa,
        cargando: _panelCargando,
        onNuevaVenta: _abrirNuevaVenta,
        onRegistrarCobro: () => context.push('/cobros/${_empresaCercana!.id}'),
        onMarcarVisitada: _marcarVisitada,
      );
    }

    return Consumer(
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
          puntoInicio: _puntoInicioOptimo,
          distanciaAlInicio: _distanciaAlInicio,
          optimizacionLista: _optimizacionLista,
          viendoResumen: _viendoResumen,
          onIniciarRuta: _iniciarRuta,
          onNuevaVenta: _abrirNuevaVenta,
          onFinalizarRuta: _completarRuta,
   onVerResumen: () {
  // Si la ruta está completada, ir al resumen (DashboardScreen)
  if ((_estadoHoy?.sesionCompletada ?? false) || (_estadoHoy?.completada ?? false)) {
    setState(() {
      _fase = FaseRuta.completada;
      _viendoResumen = true;
    });
  } else {
    setState(() => _fase = FaseRuta.completada);
  }
}
        );
      },
    );
  }
}