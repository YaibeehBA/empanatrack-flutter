// lib/core/services/notificaciones_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

// ── Provider global para poder invalidar desde cualquier lugar ──
// Se asigna en main.dart después de crear el ProviderContainer
ProviderContainer? _globalContainer;

void setGlobalContainer(ProviderContainer container) {
  _globalContainer = container;
}

// ── Lista de providers que se deben refrescar al recibir notif ──
// Agrégalos desde tu código cuando los tengas listos
final _providersParaRefrescar = <ProviderOrFamily>[];

void registrarProviderParaRefrescar(ProviderOrFamily provider) {
  _providersParaRefrescar.add(provider);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [FCM] Mensaje en BACKGROUND: ${message.notification?.title}');
}

class NotificacionesService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // ══════════════════════════════════════════════
  //  INICIALIZAR
  // ══════════════════════════════════════════════
  static Future<void> inicializar() async {
    print('\n══════════════════════════════════════');
    print('🔥 [FCM] Iniciando servicio...');

    try {
      await Firebase.initializeApp();
      print('✅ [FCM] Firebase OK');
    } catch (e) {
      print('❌ [FCM] Firebase init error: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Canal Android
    const channel = AndroidNotificationChannel(
      'empanatrack_channel',
      'EmpanaTrack',
      description: 'Notificaciones de ventas y pagos',
      importance: Importance.high,
    );

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        print('👆 [FCM] Notificacion tocada (local): ${details.payload}');
        _refrescarProviders();
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Permisos
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── Listener PRIMER PLANO ─────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('\n🔔 [FCM] Mensaje en PRIMER PLANO');
      print('   Título: ${message.notification?.title}');
      print('   Cuerpo: ${message.notification?.body}');
      print('   Datos:  ${message.data}');

      // Refrescar providers aunque la app esté abierta
      _refrescarProviders();

      // Mostrar notificación local (en primer plano no aparece sola)
      final notif = message.notification;
      if (notif != null) {
        _local.show(
          notif.hashCode,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'empanatrack_channel',
              'EmpanaTrack',
              channelDescription: 'Notificaciones de ventas y pagos',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              styleInformation: BigTextStyleInformation(notif.body ?? ''),
            ),
          ),
          payload: message.data.toString(),
        );
        print('✅ [FCM] Notificacion local mostrada');
      }
    });

    // ── App abierta desde notificación (background → foreground) ──
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('\n👆 [FCM] App abierta desde notificacion');
      print('   Datos: ${message.data}');
      // Refrescar al abrir desde la notificación
      _refrescarProviders();
    });

    // ── App estaba CERRADA y usuario tocó la notificación ────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      print('\n👆 [FCM] App abierta desde notificacion (cold start)');
      print('   Datos: ${initial.data}');
      // Pequeño delay para que los providers estén montados
      await Future.delayed(const Duration(milliseconds: 800));
      _refrescarProviders();
    }

    print('🔥 [FCM] Servicio listo');
    print('══════════════════════════════════════\n');
  }

  // ══════════════════════════════════════════════
  //  REFRESCAR PROVIDERS
  // ══════════════════════════════════════════════
  static void _refrescarProviders() {
    if (_globalContainer == null) {
      print('⚠️  [FCM] globalContainer no asignado');
      return;
    }
    if (_providersParaRefrescar.isEmpty) {
      print('⚠️  [FCM] No hay providers registrados para refrescar');
      return;
    }
    for (final provider in _providersParaRefrescar) {
      try {
        _globalContainer!.invalidate(provider);
        print('🔄 [FCM] Provider refrescado: $provider');
      } catch (e) {
        print('❌ [FCM] Error refrescando provider: $e');
      }
    }
  }

  // ══════════════════════════════════════════════
  //  REGISTRAR TOKEN
  // ══════════════════════════════════════════════
  static Future<void> registrarToken() async {
    print('\n──────────────────────────────────────');
    print('🔑 [FCM] Registrando token...');
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ [FCM] Permisos denegados');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('❌ [FCM] Token NULL (emulador sin Google Play?)');
        return;
      }

      print('✅ [FCM] Token: ${token.substring(0, 40)}...');

      await ApiClient.post(
        '/notificaciones/token',
        data: {'token': token, 'plataforma': 'android'},
      );
      print('✅ [FCM] Token guardado en backend');

      FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) {
        print('🔄 [FCM] Token refrescado');
        ApiClient.post(
              '/notificaciones/token',
              data: {'token': nuevoToken, 'plataforma': 'android'},
            )
            .then((_) => print('✅ [FCM] Token nuevo guardado'))
            .catchError(
              (e) => print('❌ [FCM] Error guardando token nuevo: $e'),
            );
      });
    } catch (e) {
      print('❌ [FCM] Error en registrarToken: $e');
    }
    print('──────────────────────────────────────\n');
  }

  // ══════════════════════════════════════════════
  //  ELIMINAR TOKEN
  // ══════════════════════════════════════════════
  static Future<void> eliminarToken() async {
    print('🗑️  [FCM] Eliminando token...');
    try {
      await ApiClient.delete('/notificaciones/token');
      print('✅ [FCM] Token eliminado del backend');
    } catch (e) {
      print('❌ [FCM] Error eliminando del backend: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
      print('✅ [FCM] Token eliminado de Firebase');
    } catch (e) {
      print('❌ [FCM] Error eliminando de Firebase: $e');
    }
  }
}
