// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(
    // ProviderScope es el contenedor de todo Riverpod
    // DEBE envolver toda la app
    const ProviderScope(
      child: EmpanaTrackApp(),
    ),
  );
}