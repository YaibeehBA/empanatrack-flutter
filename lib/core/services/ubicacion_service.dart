import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURACIÓN CENTRALIZADA
// Un solo lugar para tocar timings — antes estaba hardcodeado 4 veces
// ─────────────────────────────────────────────────────────────────────────────

class _WsCfg {
  static const pingInterval   = Duration(seconds: 20);
  static const pongTimeout    = Duration(seconds: 35);
  static const reconectMin    = Duration(seconds: 2);
  static const reconectMax    = Duration(seconds: 30);
  static const distanceFilter = 10; // metros
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO DE CONEXIÓN
// ─────────────────────────────────────────────────────────────────────────────

enum EstadoWs { conectando, conectado, reconectando, desconectado, error }

// ─────────────────────────────────────────────────────────────────────────────
// HELPER INTERNO — convierte http(s) a ws(s)
// Antes duplicado con extension + replaceFirst en cada clase
// ─────────────────────────────────────────────────────────────────────────────

String _toWs(String url) => url
    .replaceFirst('https://', 'wss://')
    .replaceFirst('http://',  'ws://');

// ─────────────────────────────────────────────────────────────────────────────
// BASE WebSocket — toda la lógica común vive aquí UNA SOLA VEZ
//
// Antes: ping, reconexión y _enviar duplicados en las 4 clases.
// Ahora: las subclases solo implementan buildUrl() y onMensaje().
// ─────────────────────────────────────────────────────────────────────────────

abstract class _BaseWsService {
  // ── Estado interno ──────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _pingTimer;
  Timer? _reconectTimer;
  Timer? _pongWatchdog;

  bool    _activo   = false;
  int     _intentos = 0;
  String? _baseUrl;

  // ── Contrato con subclases ──────────────────────────────────────────────────

  /// URL completa del endpoint WS
  String buildUrl(String baseUrl);

  /// Mensajes del servidor que NO son ping/pong
  void onMensaje(Map<String, dynamic> msg);

  /// Cambios de estado — override opcional
  void onEstado(EstadoWs estado) {}

  // ── Conexión ────────────────────────────────────────────────────────────────

  Future<void> _conectar(String baseUrl) async {
    _baseUrl = baseUrl;
    _cerrarCanal();

    final url = buildUrl(baseUrl);
    debugPrint('🔌 [$runtimeType] → $url (intento $_intentos)');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _wsSub = _channel!.stream.listen(
        _onDato,
        onError: (_) => _manejarCierre(),
        onDone:  ()  => _manejarCierre(),
      );

      // Conexión exitosa: reset backoff
      _intentos = 0;
      _reiniciarPongWatchdog();
      onEstado(EstadoWs.conectado);

      _pingTimer = Timer.periodic(
        _WsCfg.pingInterval,
        (_) => _enviar({'tipo': 'ping'}),
      );

      debugPrint('✅ [$runtimeType] Conectado');
    } catch (e) {
      debugPrint('❌ [$runtimeType] Error conectando: $e');
      _scheduleReconect();
    }
  }

  // ── Recepción de mensajes ───────────────────────────────────────────────────

  void _onDato(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;

      switch (msg['tipo'] as String?) {
        // El servidor nuevo manda ping → respondemos pong
        case 'ping':
          _enviar({'tipo': 'pong'});
          return;
        // Respuesta al ping que nosotros mandamos → reiniciar watchdog
        case 'pong':
          _reiniciarPongWatchdog();
          return;
        default:
          onMensaje(msg);
      }
    } catch (e) {
      debugPrint('⚠️ [$runtimeType] Mensaje inválido: $e');
    }
  }

  // ── Heartbeat / pong watchdog ───────────────────────────────────────────────
  //
  // El cliente original solo hacía ping y esperaba que el servidor viviera.
  // Ahora: si no llega nada en 35s, asumimos conexión zombie y reconectamos.
  // Detecta redes móviles donde el TCP queda "abierto" pero sin datos.

  void _reiniciarPongWatchdog() {
    _pongWatchdog?.cancel();
    _pongWatchdog = Timer(_WsCfg.pongTimeout, () {
      debugPrint(
        '💀 [$runtimeType] Zombie detectado '
        '(sin pong ${_WsCfg.pongTimeout.inSeconds}s)',
      );
      _manejarCierre();
    });
  }

  // ── Reconexión con backoff exponencial ─────────────────────────────────────
  //
  // Original: siempre 3 segundos fijos.
  // Ahora: 2s → 4s → 8s → 16s → 30s (máx).
  // Evita saturar el servidor cuando está caído.

  void _manejarCierre() {
    if (!_activo) return;
    onEstado(EstadoWs.reconectando);
    _scheduleReconect();
  }

  void _scheduleReconect() {
    _cerrarCanal();
    _reconectTimer?.cancel();

    final seconds = min(
      _WsCfg.reconectMin.inSeconds * pow(2, _intentos).toInt(),
      _WsCfg.reconectMax.inSeconds,
    );
    _intentos++;

    debugPrint('🔄 [$runtimeType] Reconectando en ${seconds}s (intento $_intentos)');
    _reconectTimer = Timer(Duration(seconds: seconds), () {
      if (_activo) _conectar(_baseUrl!);
    });
  }

  // ── Limpieza ────────────────────────────────────────────────────────────────

  void _cerrarCanal() {
    _pingTimer?.cancel();
    _pongWatchdog?.cancel();
    _wsSub?.cancel();
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
  }

  void _detenerBase() {
    _activo = false;
    _reconectTimer?.cancel();
    _cerrarCanal();
    onEstado(EstadoWs.desconectado);
  }

  // ── Envío ───────────────────────────────────────────────────────────────────

  void _enviar(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  bool get activo => _activo;
}

// ─────────────────────────────────────────────────────────────────────────────
// MIXIN GPS
//
// Reutilizable por cualquier servicio emisor de posición.
// MEJORA CLAVE: el GPS solo corre cuando el WS está conectado.
// Original: GPS corría aunque el canal estuviera caído → batería desperdiciada.
// ─────────────────────────────────────────────────────────────────────────────

mixin _GpsMixin on _BaseWsService {
  StreamSubscription<Position>? _gpsSub;

  void _iniciarGps() {
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: _WsCfg.distanceFilter,
      ),
    ).listen(
      onPosicion,
      onError: (e) => debugPrint('⚠️ GPS error: $e'),
    );
    debugPrint('✅ [$runtimeType] GPS iniciado');
  }

  void _detenerGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    debugPrint('🛑 [$runtimeType] GPS detenido');
  }

  /// Subclases definen qué enviar con cada posición GPS
  void onPosicion(Position pos);

  @override
  void onEstado(EstadoWs estado) {
    super.onEstado(estado);
    // GPS activo SOLO cuando hay canal vivo — ahorra batería
    if (estado == EstadoWs.conectado) {
      _iniciarGps();
    } else if (estado == EstadoWs.reconectando ||
               estado == EstadoWs.desconectado) {
      _detenerGps();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. UbicacionVendedorService
//    Tracking tradicional de pedido — el vendedor emite su posición GPS
//    ✅ API pública idéntica al original: iniciar() / detener() / activo
// ─────────────────────────────────────────────────────────────────────────────

class UbicacionVendedorService extends _BaseWsService with _GpsMixin {
  static final UbicacionVendedorService _i = UbicacionVendedorService._();
  factory UbicacionVendedorService() => _i;
  UbicacionVendedorService._();

  String? _token;
  String? _pedidoId;

  Future<void> iniciar({
    required String token,
    required String baseUrl,
    required String pedidoId,
  }) async {
    if (_activo) return;
    _token    = token;
    _pedidoId = pedidoId;
    _activo   = true;
    await _conectar(baseUrl);
  }

  void detener() {
    _detenerGps();
    _detenerBase();
    _pedidoId = null;
  }

  @override
  String buildUrl(String baseUrl) =>
      '${_toWs(baseUrl)}/ws/vendedor-ubicacion?token=$_token';

  @override
  void onMensaje(Map<String, dynamic> msg) {
    debugPrint('📨 [VendedorSvc] $msg');
  }

  @override
  void onPosicion(Position pos) {
    if (_pedidoId == null) return;
    _enviar({
      'tipo':      'ubicacion',
      'pedido_id': _pedidoId,
      'lat':       pos.latitude,
      'lng':       pos.longitude,
      'estado':    'en_camino',
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TrackingClienteService
//    El cliente recibe la posición del vendedor (tracking tradicional)
//    ✅ API pública idéntica al original:
//       conectar() / desconectar() / dispose() / posicionVendedor
// ─────────────────────────────────────────────────────────────────────────────

class TrackingClienteService extends _BaseWsService {
  String? _token;
  String? _pedidoId;

  final _posCtrl    = StreamController<LatLng>.broadcast();
  final _estadoCtrl = StreamController<EstadoWs>.broadcast();

  /// Mismo stream que el original
  Stream<LatLng>   get posicionVendedor => _posCtrl.stream;

  /// Añadido: permite mostrar indicador de conexión en la UI
  Stream<EstadoWs> get estadoConexion   => _estadoCtrl.stream;

  Future<void> conectar({
    required String token,
    required String baseUrl,
    required String pedidoId,
  }) async {
    if (_activo) desconectar();
    _token    = token;
    _pedidoId = pedidoId;
    _activo   = true;
    onEstado(EstadoWs.conectando);
    await _conectar(baseUrl);
  }

  void desconectar() {
    _detenerBase();
    _pedidoId = null;
  }

  /// CORRECCIÓN: el original no cerraba _posCtrl → memory leak
  void dispose() {
    desconectar();
    if (!_posCtrl.isClosed)    _posCtrl.close();
    if (!_estadoCtrl.isClosed) _estadoCtrl.close();
  }

  @override
  String buildUrl(String baseUrl) =>
      '${_toWs(baseUrl)}/ws/tracking/$_pedidoId?token=$_token';

  @override
  void onMensaje(Map<String, dynamic> msg) {
    if (msg['tipo'] == 'ubicacion_vendedor') {
      final lat = (msg['lat'] as num).toDouble();
      final lng = (msg['lng'] as num).toDouble();
      if (!_posCtrl.isClosed) _posCtrl.add(LatLng(lat, lng));
    }
  }

  @override
  void onEstado(EstadoWs estado) {
    super.onEstado(estado);
    if (!_estadoCtrl.isClosed) _estadoCtrl.add(estado);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. UbicacionRutaVendedorService
//    El vendedor transmite su posición durante la ruta (mapa avanzado)
//    ✅ API pública idéntica al original:
//       iniciar() / detener() / enviarPosicion() / activo
//    NOTA: mantiene enviarPosicion() manual — el GPS lo gestiona mapa_ruta_screen
// ─────────────────────────────────────────────────────────────────────────────

class UbicacionRutaVendedorService extends _BaseWsService {
  static final UbicacionRutaVendedorService _i =
      UbicacionRutaVendedorService._();
  factory UbicacionRutaVendedorService() => _i;
  UbicacionRutaVendedorService._();

  String? _token;
  String? _sesionId;

  Future<void> iniciar({
    required String token,
    required String baseUrl,
    required String sesionId,
  }) async {
    if (_activo) return;
    _token    = token;
    _sesionId = sesionId;
    _activo   = true;
    await _conectar(baseUrl);
  }

  /// Mismo contrato que el original — llamado desde mapa_ruta_screen
  void enviarPosicion(double lat, double lng) {
    if (!_activo || _sesionId == null) return;
    _enviar({
      'tipo':      'ubicacion_ruta',
      'sesion_id': _sesionId,
      'lat':       lat,
      'lng':       lng,
    });
  }

  void detener() {
    _detenerBase();
    _sesionId = null;
  }

  @override
  String buildUrl(String baseUrl) =>
      '${_toWs(baseUrl)}/ws/ruta-vendedor?token=$_token';

  @override
  void onMensaje(Map<String, dynamic> msg) {
    debugPrint('📨 [RutaVendedorSvc] $msg');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. MapaRutaClienteService
//    El cliente recibe la posición del vendedor en el mapa de ruta
//    ✅ API pública idéntica al original:
//       conectar() / desconectar() / dispose()
//       posicion / estadoConexion / errores / sesionId
// ─────────────────────────────────────────────────────────────────────────────

class MapaRutaClienteService extends _BaseWsService {
  String? _token;
  String? _sesionId;

  final _posCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _estadoCtrl = StreamController<EstadoWs>.broadcast();
  final _errorCtrl  = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get posicion       => _posCtrl.stream;
  Stream<EstadoWs>             get estadoConexion  => _estadoCtrl.stream;
  Stream<String>               get errores         => _errorCtrl.stream;
  String?                      get sesionId        => _sesionId;

  Future<void> conectar({
    required String token,
    required String baseUrl,
    required String sesionId,
  }) async {
    if (_activo) await desconectar();
    _token    = token;
    _sesionId = sesionId;
    _activo   = true;
    onEstado(EstadoWs.conectando);
    await _conectar(baseUrl);
  }

  Future<void> desconectar() async {
    _detenerBase();
    _sesionId = null;
  }

  void dispose() {
    desconectar();
    if (!_posCtrl.isClosed)    _posCtrl.close();
    if (!_estadoCtrl.isClosed) _estadoCtrl.close();
    if (!_errorCtrl.isClosed)  _errorCtrl.close();
  }

  @override
  String buildUrl(String baseUrl) =>
      '${_toWs(baseUrl)}/ws/mapa-cliente/$_sesionId?token=$_token';

 @override
void onMensaje(Map<String, dynamic> msg) {
  switch (msg['tipo'] as String?) {
    case 'ubicacion_vendedor_ruta':
    case 'ubicacion_vendedor':
      if (!_posCtrl.isClosed) {
        final sesionRaw = msg['sesion_id'] as String? ?? '';
        // Quitar prefijo "sesion:" que agrega el backend
        final sesionLimpio = sesionRaw.startsWith('sesion:')
            ? sesionRaw.substring(7) : sesionRaw;
        _posCtrl.add({
          'lat':         (msg['lat'] as num).toDouble(),
          'lng':         (msg['lng'] as num).toDouble(),
          'vendedor_id': msg['vendedor_id'] as String? ?? '',
          'sesion_id':   sesionLimpio,
          'timestamp':   msg['timestamp'],
        });
      }
      break;

    case 'error':
      final err = msg['mensaje'] as String? ?? 'Error desconocido';
      if (!_errorCtrl.isClosed) _errorCtrl.add(err);
      onEstado(EstadoWs.error);
      break;

    default:
      debugPrint('📨 [MapaClienteSvc] tipo desconocido: ${msg['tipo']}');
  }
}
  @override
  void onEstado(EstadoWs estado) {
    super.onEstado(estado);
    if (!_estadoCtrl.isClosed) _estadoCtrl.add(estado);
  }
}