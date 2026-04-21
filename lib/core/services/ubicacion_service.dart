import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Servicio que el VENDEDOR usa para enviar su ubicación en tiempo real
class UbicacionVendedorService {
  static final UbicacionVendedorService _i = UbicacionVendedorService._();
  factory UbicacionVendedorService() => _i;
  UbicacionVendedorService._();

  WebSocketChannel? _channel;
  StreamSubscription<Position>? _gpsSub;
  Timer? _pingTimer;
  Timer? _reconectarTimer;

  // Guardamos params para reconectar
  String? _token;
  String? _baseUrl;
  String? _pedidoId;
  bool    _activo = false;

  Future<void> iniciar({
    required String token,
    required String baseUrl,
    required String pedidoId,
  }) async {
    if (_activo) return;
    _token    = token;
    _baseUrl  = baseUrl;
    _pedidoId = pedidoId;
    _activo   = true;

    await _conectarWs();
    _iniciarGps();
  }

  Future<void> _conectarWs() async {
    _channel?.sink.close();
    _pingTimer?.cancel();

    final wsUrl = _baseUrl!
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/vendedor-ubicacion?token=$_token'),
      );

      // ← CLAVE: escuchar cierre y reconectar automáticamente
      _channel!.stream.listen(
        (_) {},
        onError: (_) => _programarReconexion(),
        onDone:  ()  => _programarReconexion(),
      );

      print('✅ [UbicSvc] WS conectado para pedido $_pedidoId');

      // Ping cada 20s (menos que los 25s anteriores, más margen)
      _pingTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _enviar({'tipo': 'ping'}),
      );
    } catch (e) {
      print('❌ [UbicSvc] Error conectando: $e');
      _programarReconexion();
    }
  }

  void _programarReconexion() {
    if (!_activo) return;
    _reconectarTimer?.cancel();
    print('🔄 [UbicSvc] Reconectando en 3s...');
    _reconectarTimer = Timer(
      const Duration(seconds: 3),
      () async {
        if (_activo) await _conectarWs();
      },
    );
  }

  void _iniciarGps() {
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _enviar({
        'tipo':      'ubicacion',
        'pedido_id': _pedidoId,
        'lat':       pos.latitude,
        'lng':       pos.longitude,
        'estado':    'en_camino',
      });
    });
    print('✅ [UbicSvc] GPS stream iniciado');
  }

  void detener() {
    _activo = false;
    _gpsSub?.cancel();
    _pingTimer?.cancel();
    _reconectarTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel         = null;
    _gpsSub          = null;
    _pedidoId        = null;
    _reconectarTimer = null;
    print('🔌 [UbicSvc] Detenido');
  }

  void _enviar(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  bool get activo => _activo;
}

/// Servicio que el CLIENTE usa para recibir la ubicación del vendedor
class TrackingClienteService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconectarTimer;

  // Guardamos params para reconectar
  String? _token;
  String? _baseUrl;
  String? _pedidoId;
  bool    _activo = false;

  final _posCtrl = StreamController<LatLng>.broadcast();
  Stream<LatLng> get posicionVendedor => _posCtrl.stream;

  Future<void> conectar({
    required String token,
    required String baseUrl,
    required String pedidoId,
  }) async {
    _token    = token;
    _baseUrl  = baseUrl;
    _pedidoId = pedidoId;
    _activo   = true;
    await _conectarWs();
  }

  Future<void> _conectarWs() async {
    _channel?.sink.close();
    _pingTimer?.cancel();

    final wsUrl = _baseUrl!
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/tracking/$_pedidoId?token=$_token'),
      );

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['tipo'] == 'ubicacion_vendedor') {
              final lat = (msg['lat'] as num).toDouble();
              final lng = (msg['lng'] as num).toDouble();
              _posCtrl.add(LatLng(lat, lng));
            }
          } catch (_) {}
        },
        onError: (_) => _programarReconexion(),
        onDone:  ()  => _programarReconexion(),
      );

      // Ping cada 20s
      _pingTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) {
          try {
            _channel?.sink.add(jsonEncode({'tipo': 'ping'}));
          } catch (_) {}
        },
      );

      print('✅ [TrackingSvc] Conectado al tracking de $_pedidoId');
    } catch (e) {
      print('❌ [TrackingSvc] Error: $e');
      _programarReconexion();
    }
  }

  void _programarReconexion() {
    if (!_activo) return;
    _reconectarTimer?.cancel();
    print('🔄 [TrackingSvc] Reconectando en 3s...');
    _reconectarTimer = Timer(
      const Duration(seconds: 3),
      () async {
        if (_activo) await _conectarWs();
      },
    );
  }

  void desconectar() {
    _activo = false;
    _pingTimer?.cancel();
    _reconectarTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel         = null;
    _reconectarTimer = null;
    print('🔌 [TrackingSvc] Desconectado');
  }

  void dispose() {
    desconectar();
    _posCtrl.close();
  }
}