import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notificaciones_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificacionesService.inicializar();

  final container = ProviderContainer();
  setGlobalContainer(container);   // ← conecta FCM con Riverpod

  await container.read(authProvider.notifier).verificarSesion();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EmpanaTrackApp(),
    ),
  );
}