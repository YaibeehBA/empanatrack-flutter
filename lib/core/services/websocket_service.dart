import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WsEstado { desconectado, conectando, conectado, error }

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  factory WebSocketService() => _instance;
  WebSocketService._();

  WebSocketChannel?          _channel;
  StreamSubscription?        _sub;
  Timer?                     _pingTimer;
  Timer?                     _reconectarTimer;

  WsEstado _estado = WsEstado.desconectado;
  WsEstado get estado => _estado;

  // Stream de mensajes para los listeners
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get mensajes => _ctrl.stream;

  String? _token;
  String? _baseUrl;

  // ── Conectar ───────────────────────────────────────
  Future<void> conectar({
    required String token,
    required String baseUrl,
  }) async {
    _token   = token;
    _baseUrl = baseUrl;

    if (_estado == WsEstado.conectado ||
        _estado == WsEstado.conectando) return;

    _estado = WsEstado.conectando;
    print('🔌 [WS] Conectando...');

    try {
      // Convertir http/https a ws/wss
      final wsUrl = baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final uri = Uri.parse('$wsUrl/ws/vendedor?token=$token');
      _channel  = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        _onMensaje,
        onError: _onError,
        onDone:  _onDesconectado,
      );

      _estado = WsEstado.conectado;
      print('✅ [WS] Conectado');

      // Ping cada 30 segundos para mantener conexión viva
      _pingTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _enviar({'tipo': 'ping'}),
      );

    } catch (e) {
      print('❌ [WS] Error conectando: $e');
      _estado = WsEstado.error;
      _programarReconexion();
    }
  }

  // ── Desconectar ────────────────────────────────────
  void desconectar() {
    _pingTimer?.cancel();
    _reconectarTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _estado  = WsEstado.desconectado;
    print('🔌 [WS] Desconectado');
  }

  // ── Enviar mensaje ─────────────────────────────────
  void _enviar(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  // ── Callbacks ──────────────────────────────────────
  void _onMensaje(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      if (msg['tipo'] == 'pong') return; // ignorar pong
      print('📨 [WS] Mensaje recibido: $msg');
      _ctrl.add(msg);
    } catch (_) {}
  }

  void _onError(dynamic error) {
    print('❌ [WS] Error: $error');
    _estado = WsEstado.error;
    _programarReconexion();
  }

  void _onDesconectado() {
    print('🔌 [WS] Conexión cerrada');
    if (_estado != WsEstado.desconectado) {
      _estado = WsEstado.error;
      _programarReconexion();
    }
  }

  // ── Reconexión automática ──────────────────────────
  void _programarReconexion() {
    _reconectarTimer?.cancel();
    _reconectarTimer = Timer(const Duration(seconds: 5), () {
      if (_token != null && _baseUrl != null &&
          _estado != WsEstado.conectado) {
        print('🔄 [WS] Reconectando...');
        _estado = WsEstado.desconectado;
        conectar(token: _token!, baseUrl: _baseUrl!);
      }
    });
  }

  void dispose() {
    desconectar();
    _ctrl.close();
  }
}