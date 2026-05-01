import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/colores.dart';
import '../../../../core/network/api_client.dart';

import '../../../core/services/ubicacion_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ruta_activa_models.dart';
// ✅ CORREGIDO: eliminado "hide reservasEmpresaProvider"
//    reservasEmpresaProvider vive únicamente en pedidos_vendedor_provider.dart
import '../providers/ruta_activa_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/pedidos_vendedor_provider.dart' as ped;
import '../providers/ventas_provider.dart';

import '../widgets/empresa_marker.dart';
import '../widgets/empresa_panel.dart';
import '../widgets/panel_inferior_ruta.dart';
import '../widgets/ruta_header.dart';
import '../widgets/toast_alerta.dart';
import 'dashboard_screen.dart';
import 'entregar_reserva_screen.dart';
import 'stock_diario_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES
// ─────────────────────────────────────────────────────────────────────────────

const double _kDistanciaInicio  = 30.0;
const double _kDistanciaEmpresa = 30.0;

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS LOCALES
// ─────────────────────────────────────────────────────────────────────────────

class _ParadaRuta {
  final String  empresaId;
  final String  nombre;
  final String? direccion;
  final double  latitud;
  final double  longitud;
  final double  distanciaDesdeAnterior;
  final bool    esInicio;
  final bool    esFin;

  const _ParadaRuta({
    required this.empresaId,
    required this.nombre,
    this.direccion,
    required this.latitud,
    required this.longitud,
    required this.distanciaDesdeAnterior,
    required this.esInicio,
    required this.esFin,
  });

  factory _ParadaRuta.fromJson(Map<String, dynamic> j) => _ParadaRuta(
        empresaId:              j['empresa_id'] as String,
        nombre:                 j['nombre']     as String,
        direccion:              j['direccion']  as String?,
        latitud:                (j['latitud']   as num).toDouble(),
        longitud:               (j['longitud']  as num).toDouble(),
        distanciaDesdeAnterior: (j['distancia_desde_anterior'] as num).toDouble(),
        esInicio:               j['es_inicio']  as bool,
        esFin:                  j['es_fin']     as bool,
      );

  LatLng get latLng => LatLng(latitud, longitud);
}

class _RutaCalculada {
  final List<_ParadaRuta> paradas;
  final List<LatLng>      polilinea;
  final double            distanciaTotal;
  final double            tiempoMinutos;
  final String            fuente;

  const _RutaCalculada({
    required this.paradas,
    required this.polilinea,
    required this.distanciaTotal,
    required this.tiempoMinutos,
    required this.fuente,
  });

  factory _RutaCalculada.fromJson(Map<String, dynamic> j) {
    final paradas = (j['paradas'] as List)
        .map((p) => _ParadaRuta.fromJson(p as Map<String, dynamic>))
        .toList();

    final polilinea = (j['puntos_polilinea'] as List).map((p) {
      final m = p as Map<String, dynamic>;
      return LatLng(
        (m['latitud']  as num).toDouble(),
        (m['longitud'] as num).toDouble(),
      );
    }).toList();

    return _RutaCalculada(
      paradas:        paradas,
      polilinea:      polilinea,
      distanciaTotal: (j['distancia_total'] as num).toDouble(),
      tiempoMinutos:  (j['tiempo_minutos']  as num).toDouble(),
      fuente:         j['fuente'] as String,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA
// ─────────────────────────────────────────────────────────────────────────────

class MapaRutaScreen extends ConsumerStatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  ConsumerState<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends ConsumerState<MapaRutaScreen> {

  // ── Estado ────────────────────────────────────────────────────────────────
  FaseRuta        _fase              = FaseRuta.cargando;
  EstadoRutaHoy?  _estadoHoy;
  String?         _sesionId;
  LatLng?         _miPosicion;
  List<LatLng>    _rutaCalles        = [];
  EmpresaRuta?    _empresaCercana;
  DateTime?       _llegadaEmpresa;
  bool            _mostrarAlerta     = false;
  bool            _siguiendo         = true;
  bool            _panelCargando     = false;
  bool            _optimizacionLista = false;
  bool            _viendoResumen     = false;

  EmpresaRuta?    _puntoInicioOptimo;

  final _mapCtrl = MapController();
  StreamSubscription<Position>? _gpsSub;

  // ── Distancia al punto de inicio ──────────────────────────────────────────
  double? get _distanciaAlInicio {
    if (_miPosicion == null || _puntoInicioOptimo == null) return null;
    if (_puntoInicioOptimo!.latitud  == null ||
        _puntoInicioOptimo!.longitud == null) return null;
    return _haversine(
      _miPosicion!.latitude,  _miPosicion!.longitude,
      _puntoInicioOptimo!.latitud!, _puntoInicioOptimo!.longitud!,
    );
  }

  // ── Ciclo de vida ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Activar el notifier WS del mapa (escucha reservas en tiempo real)
    ref.read(ped.reservasMapaProvider);
    _inicializar();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    UbicacionRutaVendedorService().detener();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INICIALIZACIÓN
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _inicializar() async {
    setState(() {
      _fase              = FaseRuta.cargando;
      _rutaCalles        = [];
      _empresaCercana    = null;
      _llegadaEmpresa    = null;
      _optimizacionLista = false;
      _puntoInicioOptimo = null;
      _viendoResumen     = false;
    });

    await _obtenerPosicion();

    try {
      final r      = await ApiClient.get('/ruta-activa/estado-hoy');
      final estado = EstadoRutaHoy.fromJson(r.data);
      _estadoHoy   = estado;

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
      } else {
        _sesionId = estado.sesion!.id;
        setState(() => _fase = FaseRuta.enRuta);

        final sesion = ref.read(authProvider).sesion;
        if (sesion != null) {
          UbicacionRutaVendedorService().iniciar(
            token:    sesion.token,
            baseUrl:  ApiClient.baseUrl,
            sesionId: _sesionId!,
          );
        }
      }

      _iniciarGPS();
      await _cargarRutaDesdeBackend();

    } catch (e) {
      debugPrint('Error init: $e');
      if (mounted) setState(() => _fase = FaseRuta.sinRuta);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RUTA CALCULADA POR EL BACKEND
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _cargarRutaDesdeBackend() async {
    final rutaId = _estadoHoy?.rutaId;
    if (rutaId == null) {
      if (mounted) setState(() => _optimizacionLista = true);
      return;
    }

    final pendientes = _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas && !e.visitada)
        .toList();

    if (pendientes.isEmpty) {
      if (mounted) setState(() => _optimizacionLista = true);
      return;
    }

    if (mounted) setState(() => _optimizacionLista = false);

    try {
      final r         = await ApiClient.get('/rutas/calcular/$rutaId');
      final calculada = _RutaCalculada.fromJson(r.data as Map<String, dynamic>);

      if (!mounted) return;

      final visitadas = _estadoHoy!.empresas.where((e) => e.visitada).toList();
      final ordenadas = calculada.paradas
          .map((p) => _estadoHoy!.empresas
              .firstWhere((e) => e.id == p.empresaId,
                  orElse: () => EmpresaRuta(
                    id:        p.empresaId,
                    nombre:    p.nombre,
                    direccion: p.direccion,
                    latitud:   p.latitud,
                    longitud:  p.longitud,
                    orden:     0,
                    visitada:  false,
                  )))
          .where((e) => !e.visitada)
          .toList();

      setState(() {
        _puntoInicioOptimo = ordenadas.isNotEmpty ? ordenadas.first : null;
        _optimizacionLista = true;

        _estadoHoy = EstadoRutaHoy(
          tieneRuta:        _estadoHoy!.tieneRuta,
          stockLleno:       _estadoHoy!.stockLleno,
          asignacionId:     _estadoHoy!.asignacionId,
          rutaId:           _estadoHoy!.rutaId,
          rutaNombre:       _estadoHoy!.rutaNombre,
          turno:            _estadoHoy!.turno,
          sesion:           _estadoHoy!.sesion,
          empresas:         [...visitadas, ...ordenadas],
          total:            _estadoHoy!.total,
          visitadas:        _estadoHoy!.visitadas,
          completada:       _estadoHoy!.completada,
          sesionCompletada: _estadoHoy!.sesionCompletada,
        );

        _rutaCalles = calculada.polilinea;
      });

      debugPrint(
        '✅ Ruta cargada: ${calculada.paradas.length} paradas, '
        '${calculada.polilinea.length} puntos, fuente=${calculada.fuente}',
      );

      if (calculada.polilinea.isNotEmpty) {
        final puntos = [
          if (_miPosicion != null) _miPosicion!,
          ...calculada.polilinea,
        ];
        _ajustarZoom(puntos);
      }

    } catch (e) {
      debugPrint('❌ Error cargando ruta del backend: $e');
      if (mounted) setState(() => _optimizacionLista = true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GPS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _obtenerPosicion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _miPosicion = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  void _iniciarGPS() {
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final nueva = LatLng(pos.latitude, pos.longitude);
      setState(() => _miPosicion = nueva);
      if (_siguiendo) _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
      _verificarProximidad(nueva);

      if (_fase == FaseRuta.enRuta && _sesionId != null) {
        UbicacionRutaVendedorService()
            .enviarPosicion(pos.latitude, pos.longitude);
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ZOOM
  // ══════════════════════════════════════════════════════════════════════════
  void _ajustarZoom(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude,  maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
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

  // ══════════════════════════════════════════════════════════════════════════
  //  PROXIMIDAD
  // ══════════════════════════════════════════════════════════════════════════
  void _verificarProximidad(LatLng pos) {
    if (_estadoHoy == null || _fase != FaseRuta.enRuta) return;

    EmpresaRuta? empCercana;
    for (final emp in _estadoHoy!.empresas
        .where((e) => e.tieneCoordenadas && !e.visitada)) {
      final dist = _haversine(
        pos.latitude, pos.longitude,
        emp.latitud!, emp.longitud!,
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
      final llegada        = llegadaBackend ?? DateTime.now();
      setState(() {
        _empresaCercana = empCercana;
        _llegadaEmpresa = llegada;
      });
      if (llegadaBackend == null) _registrarLlegada(empCercana);
    }
  }

  Future<void> _registrarLlegada(EmpresaRuta emp) async {
    if (_sesionId == null || _miPosicion == null) return;

    final ok = await ref.read(rutaAccionProvider.notifier).registrarLlegada(
      sesionId:  _sesionId!,
      empresaId: emp.id,
      lat:       _miPosicion!.latitude,
      lng:       _miPosicion!.longitude,
    );

    if (ok && mounted) {
      final ahora  = DateTime.now().toIso8601String();
      final nuevas = _estadoHoy!.empresas
          .map((e) => e.id == emp.id ? e.copyWith(llegadaEn: ahora) : e)
          .toList();
      setState(() {
        _estadoHoy = EstadoRutaHoy(
          tieneRuta:        _estadoHoy!.tieneRuta,
          stockLleno:       _estadoHoy!.stockLleno,
          asignacionId:     _estadoHoy!.asignacionId,
          rutaId:           _estadoHoy!.rutaId,
          rutaNombre:       _estadoHoy!.rutaNombre,
          turno:            _estadoHoy!.turno,
          sesion:           _estadoHoy!.sesion,
          empresas:         nuevas,
          total:            _estadoHoy!.total,
          visitadas:        _estadoHoy!.visitadas,
          completada:       _estadoHoy!.completada,
          sesionCompletada: _estadoHoy!.sesionCompletada,
        );
        _llegadaEmpresa = DateTime.now();
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HAVERSINE
  // ══════════════════════════════════════════════════════════════════════════
  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r  = 6371000.0;
    final dLat = _rad(la2 - la1), dLon = _rad(lo2 - lo1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(la1)) * cos(_rad(la2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  // ══════════════════════════════════════════════════════════════════════════
  //  ACCIONES
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _iniciarRuta() async {
    if (_miPosicion == null || _estadoHoy == null) return;

    final hayEmpresas = _estadoHoy!.empresas
        .any((e) => e.tieneCoordenadas && !e.visitada);
    if (hayEmpresas && !_optimizacionLista) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    final puntoInicio = _puntoInicioOptimo;
    if (puntoInicio == null ||
        puntoInicio.latitud  == null ||
        puntoInicio.longitud == null) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    final dist = _haversine(
      _miPosicion!.latitude,  _miPosicion!.longitude,
      puntoInicio.latitud!,   puntoInicio.longitud!,
    );
    if (dist > _kDistanciaInicio) {
      setState(() => _mostrarAlerta = true);
      return;
    }

    setState(() { _mostrarAlerta = false; _panelCargando = true; });

    final sesionId = await ref.read(rutaAccionProvider.notifier).iniciarRuta(
      asignacionId: _estadoHoy!.asignacionId!,
      lat:          _miPosicion!.latitude,
      lng:          _miPosicion!.longitude,
    );

    if (sesionId != null && mounted) {
      final sesion = ref.read(authProvider).sesion;
      if (sesion != null) {
        UbicacionRutaVendedorService().iniciar(
          token:    sesion.token,
          baseUrl:  ApiClient.baseUrl,
          sesionId: sesionId,
        );
      }
      setState(() {
        _sesionId      = sesionId;
        _fase          = FaseRuta.enRuta;
        _panelCargando = false;
      });
      _iniciarGPS();
    } else {
      setState(() => _panelCargando = false);
    }
  }

  Future<void> _marcarVisitada() async {
    if (_empresaCercana == null || _sesionId == null || _miPosicion == null) {
      return;
    }

    setState(() => _panelCargando = true);
    if (!mounted) return;

    final empresaId = _empresaCercana!.id;

    final error = await ref.read(rutaAccionProvider.notifier).marcarVisitada(
      sesionId:  _sesionId!,
      empresaId: empresaId,
      lat:       _miPosicion!.latitude,
      lng:       _miPosicion!.longitude,
    );

    if (!mounted) return;

    if (error != null) {
      _mostrarSnack(error, error: true);
      setState(() => _panelCargando = false);
      return;
    }

    _estadoHoy = _estadoHoy!.marcarVisitada(empresaId);

    setState(() {
      _empresaCercana = null;
      _llegadaEmpresa = null;
      _panelCargando  = false;
    });

    // Invalidar stock y reservas de la empresa recién visitada
    ref.invalidate(stockRestanteProvider);
    ref.invalidate(ped.reservasActivasProvider);
    ref.invalidate(ped.reservasEmpresaProvider(empresaId));

    await _cargarRutaDesdeBackend();

    if (_estadoHoy!.completada) {
      await _completarRuta();
    }
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

    final hoy   = _fmtHoy();
    final rango = RangoFechas(desde: hoy, hasta: hoy);
    ref.invalidate(resumenPorFechasProvider(rango));
    ref.invalidate(historialPorFechasProvider(rango));
    ref.invalidate(ped.pedidosHistorialProvider(rango));

    if (mounted) setState(() => _fase = FaseRuta.completada);
  }

  String _fmtHoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: error ? AppColores.danger : AppColores.success,
    ));
  }

  Future<void> _abrirNuevaVenta() async {
    await context.push('/nueva-venta');
    if (mounted) ref.invalidate(stockRestanteProvider);
  }

  Future<void> _registrarCobro() async {
    _mostrarSnack('Función de cobros en desarrollo');
  }

  // ── Abrir pantalla de reservas de la empresa ──────────────────────────────
  Future<void> _abrirReservas(
    EmpresaRuta empresa,
    List<ped.PedidoVendedor> reservas,
  ) async {
    final actualizo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntregarReservaScreen(
          empresa:  empresa,
          reservas: reservas,
        ),
      ),
    );
    if (actualizo == true && mounted) {
      ref.invalidate(stockRestanteProvider);
      ref.invalidate(ped.reservasEmpresaProvider(empresa.id));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
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
              tieneRuta:        _estadoHoy!.tieneRuta,
              stockLleno:       true,
              asignacionId:     _estadoHoy!.asignacionId,
              rutaId:           _estadoHoy!.rutaId,
              rutaNombre:       _estadoHoy!.rutaNombre,
              turno:            _estadoHoy!.turno,
              sesion:           _estadoHoy!.sesion,
              empresas:         _estadoHoy!.empresas,
              total:            _estadoHoy!.total,
              visitadas:        _estadoHoy!.visitadas,
              completada:       _estadoHoy!.completada,
              sesionCompletada: _estadoHoy!.sesionCompletada,
            );
            setState(() => _fase = FaseRuta.listo);
            _obtenerPosicion().then((_) => _cargarRutaDesdeBackend());
          },
        );

      case FaseRuta.completada:
        _viendoResumen = true;
        return DashboardScreen(
          sesionId:       _sesionId,
          onVolverAlMapa: () async {
            try {
              final r           = await ApiClient.get('/ruta-activa/estado-hoy');
              final nuevoEstado = EstadoRutaHoy.fromJson(r.data);
              _estadoHoy = nuevoEstado;
              _sesionId  = nuevoEstado.sesion?.id;
            } catch (e) {
              debugPrint('Error recargando estado: $e');
            }
            setState(() {
              _fase          = FaseRuta.enRuta;
              _viendoResumen = true;
            });
          },
        );

      default:
        return _scaffoldMapa();
    }
  }

  // ── Scaffolds de estado ───────────────────────────────────────────────────

  Widget _scaffoldCargando() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _scaffoldSinRuta() => Scaffold(
    backgroundColor: AppColores.background,
    appBar: AppBar(
      backgroundColor:           AppColores.primary,
      foregroundColor:           Colors.white,
      automaticallyImplyLeading: false,
      title: const Text('Mi Ruta',
          style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh), onPressed: _inicializar),
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
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary),
            ),
            SizedBox(height: 10),
            Text(
              'El administrador aún no te ha asignado una ruta para hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColores.textSecond, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Mapa principal ────────────────────────────────────────────────────────
  Widget _scaffoldMapa() {
    final enRuta = _fase == FaseRuta.enRuta;
    final centro = _miPosicion ?? const LatLng(-1.66, -78.65);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: centro,
            initialZoom:   14,
            onPositionChanged: (_, gesture) {
              if (gesture && _siguiendo) setState(() => _siguiendo = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.empanatrack.app',
            ),

            if (_rutaCalles.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points:      _rutaCalles,
                  color:       Colors.white,
                  strokeWidth: 7,
                  strokeCap:   StrokeCap.round,
                ),
                Polyline(
                  points:      _rutaCalles,
                  color:       AppColores.primary,
                  strokeWidth: 4,
                  strokeCap:   StrokeCap.round,
                ),
              ]),

            MarkerLayer(markers: [
              for (final emp in _estadoHoy?.empresas ?? [])
                if (emp.tieneCoordenadas)
                  Marker(
                    point:  LatLng(emp.latitud!, emp.longitud!),
                    width:  160,
                    height: 65,
                    child:  EmpresaMarker(
                      empresa:   emp,
                      esCercana: _empresaCercana?.id == emp.id,
                      esInicio:
                          !enRuta && _puntoInicioOptimo?.id == emp.id,
                    ),
                  ),

              if (_miPosicion != null)
                Marker(
                  point:  _miPosicion!,
                  width:  24,
                  height: 24,
                  child: Container(
                    width:  24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:  AppColores.primary,
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color:        AppColores.primary
                              .withValues(alpha: 0.4),
                          blurRadius:   6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
            ]),
          ],
        ),

        // Header progreso
        Positioned(
          top: 0, left: 0, right: 0,
          child: RutaHeader(estado: _estadoHoy),
        ),

        // Toast alerta
        if (_mostrarAlerta)
          Positioned(
            top: 110, left: 16, right: 16,
            child: ToastAlerta(
              titulo: !_optimizacionLista
                  ? 'Calculando ruta óptima…'
                  : 'Debes estar en el punto de inicio',
              subtitulo: !_optimizacionLista
                  ? 'Espera un momento mientras el servidor calcula'
                    ' la mejor ruta.'
                  : _puntoInicioOptimo != null
                      ? 'Dirígete a ${_puntoInicioOptimo!.nombre}. '
                        'Debes estar a menos de '
                        '${_kDistanciaInicio.toInt()} m.'
                      : 'Dirígete al punto de inicio para comenzar.',
              onCerrar: () => setState(() => _mostrarAlerta = false),
            ),
          ),

        // Panel inferior
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildPanelInferior(enRuta),
        ),

        // Botón recentrar GPS
        if (!_siguiendo && _miPosicion != null)
          Positioned(
            right: 16, bottom: 180,
            child: FloatingActionButton.small(
              heroTag:         'centrar',
              backgroundColor: Colors.white,
              elevation:       4,
              onPressed: () {
                setState(() => _siguiendo = true);
                _mapCtrl.move(_miPosicion!, _mapCtrl.camera.zoom);
              },
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColores.primary,
                size:  20,
              ),
            ),
          ),
      ]),
    );
  }

  // ── Panel inferior ────────────────────────────────────────────────────────
  Widget _buildPanelInferior(bool enRuta) {
    // ── Panel de empresa cercana (cuando el vendedor está en una empresa) ──
    if (_empresaCercana != null && enRuta) {
      return Consumer(builder: (ctx, ref2, _) {
        // ✅ CORREGIDO: usa ped.reservasEmpresaProvider (List<PedidoVendedor>)
        //    que es el único que existe ahora — ya no hay duplicado en
        //    ruta_activa_provider.dart
        final reservasAsync = ref2.watch(
            ped.reservasEmpresaProvider(_empresaCercana!.id));

        final cantidadReservas = reservasAsync.maybeWhen(
          data:   (list) => list.length,
          orElse: () => 0,
        );

        return EmpresaPanel(
          empresa:          _empresaCercana!,
          llegadaEn:        _llegadaEmpresa,
          cargando:         _panelCargando,
          onNuevaVenta:     _abrirNuevaVenta,
          cantidadReservas: cantidadReservas,
          onVerReservas: () => _abrirReservas(
            _empresaCercana!,
            // ✅ asData?.value es List<PedidoVendedor> — tipo correcto
            reservasAsync.asData?.value ?? [],
          ),
          onMarcarVisitada: _marcarVisitada,
          onRegistrarCobro: _registrarCobro,
        );
      });
    }

    // ── Panel inferior genérico (stock, iniciar/finalizar ruta) ──────────
    return Consumer(
      builder: (ctx, ref, _) {
        final stockAsync = ref.watch(stockRestanteProvider);
        final sinStock   = stockAsync.maybeWhen(
          data:   (s) => s.sinStock,
          orElse: ()  => false,
        );
        return PanelInferiorRuta(
          estado:            _estadoHoy,
          enRuta:            enRuta,
          cargando:          _panelCargando,
          sinStock:          sinStock && enRuta,
          puntoInicio:       _puntoInicioOptimo,
          distanciaAlInicio: _distanciaAlInicio,
          optimizacionLista: _optimizacionLista,
          viendoResumen:     _viendoResumen,
          onIniciarRuta:     _iniciarRuta,
          onNuevaVenta:      _abrirNuevaVenta,
          onFinalizarRuta:   _completarRuta,
          onVerResumen: () {
            if ((_estadoHoy?.sesionCompletada ?? false) ||
                (_estadoHoy?.completada       ?? false)) {
              setState(() {
                _fase          = FaseRuta.completada;
                _viendoResumen = true;
              });
            } else {
              setState(() => _fase = FaseRuta.completada);
            }
          },
        );
      },
    );
  }
}