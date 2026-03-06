import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notificaciones_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase y notificaciones
  await NotificacionesService.inicializar();

  runApp(
    const ProviderScope(
      child: EmpanaTrackApp(),
    ),
  );
}