// lib/core/services/notificaciones_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificacionesService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    try {
      print('🔥 [FCM] Inicializando Firebase...');
      await Firebase.initializeApp();
      print('🔥 [FCM] Firebase inicializado OK');

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Configurar notificaciones locales
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _local.initialize(initSettings);
      print('🔥 [FCM] Notificaciones locales OK');

      // Canal Android
      const channel = AndroidNotificationChannel(
        'empanatrack_channel',
        'EmpanaTrack',
        description: 'Notificaciones de ventas y pagos',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      print('🔥 [FCM] Canal Android creado OK');

      // Pedir permisos
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔥 [FCM] Permisos: ${settings.authorizationStatus}');

      // Escuchar mensajes en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print(
          '🔔 [FCM] Mensaje recibido en primer plano: '
          '${message.notification?.title}',
        );
        final notification = message.notification;
        final android = message.notification?.android;
        if (notification != null && android != null) {
          _local.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'empanatrack_channel',
                'EmpanaTrack',
                channelDescription: 'Notificaciones de ventas y pagos',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      print('🔥 [FCM] Servicio completamente inicializado');
    } catch (e, stack) {
      print('❌ [FCM] Error al inicializar: $e');
      print('❌ [FCM] Stack: $stack');
    }
  }

  static Future<void> registrarToken() async {
    try {
      print('🔑 [FCM] Obteniendo token...');

      final messaging = FirebaseMessaging.instance;

      // Verificar permisos primero
      final settings = await messaging.getNotificationSettings();
      print('🔑 [FCM] Estado permisos: ${settings.authorizationStatus}');

      final token = await messaging.getToken();

      if (token == null) {
        print(
          '❌ [FCM] Token es NULL — '
          'verifica google-services.json y emulador con Google Play',
        );
        return;
      }

      print('✅ [FCM] Token obtenido: ${token.substring(0, 30)}...');
      print('✅ [FCM] Token completo: $token');

      // Enviar al backend
      print('🌐 [FCM] Enviando token al backend...');
      final response = await ApiClient.post(
        '/notificaciones/token',
        data: {'token': token, 'plataforma': 'android'},
      );
      print('✅ [FCM] Token registrado en backend: ${response.data}');

      // Listener para cuando el token cambia
      messaging.onTokenRefresh.listen((nuevoToken) {
        print('🔄 [FCM] Token refrescado');
        ApiClient.post(
          '/notificaciones/token',
          data: {'token': nuevoToken, 'plataforma': 'android'},
        );
      });
    } catch (e, stack) {
      print('❌ [FCM] Error registrando token: $e');
      print('❌ [FCM] Stack: $stack');
    }
  }

  static Future<void> eliminarToken() async {
    try {
      await ApiClient.delete('/notificaciones/token');
      await FirebaseMessaging.instance.deleteToken();
      print('🗑️ [FCM] Token eliminado');
    } catch (e) {
      print('❌ [FCM] Error eliminando token: $e');
    }
  }
}
