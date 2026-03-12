import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class RecuperacionState {
  final bool    cargando;
  final String? error;
  final bool    codigoEnviado;
  final bool    exitoso;

  const RecuperacionState({
    this.cargando      = false,
    this.error,
    this.codigoEnviado = false,
    this.exitoso       = false,
  });

  RecuperacionState copyWith({
    bool?   cargando,
    String? error,
    bool?   codigoEnviado,
    bool?   exitoso,
  }) {
    return RecuperacionState(
      cargando:      cargando      ?? this.cargando,
      error:         error,
      codigoEnviado: codigoEnviado ?? this.codigoEnviado,
      exitoso:       exitoso       ?? this.exitoso,
    );
  }
}

class RecuperacionNotifier extends StateNotifier<RecuperacionState> {
  RecuperacionNotifier() : super(const RecuperacionState());

  Future<void> solicitarCodigo(String correo) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.postPublico(
        '/auth/recuperar-contrasena',
        data: {'correo': correo.trim().toLowerCase()},
      );
      state = state.copyWith(cargando: false, codigoEnviado: true);
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        error:    _parsearError(e),
      );
    }
  }

  Future<void> verificarCodigo({
    required String correo,
    required String codigo,
    required String contrasenaNueva,
  }) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.postPublico(
        '/auth/verificar-codigo',
        data: {
          'correo':           correo.trim().toLowerCase(),
          'codigo':           codigo.trim(),
          'contrasena_nueva': contrasenaNueva,
        },
      );
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        error:    _parsearError(e),
      );
    }
  }

  void resetear() {
    state = const RecuperacionState();
  }

  String _parsearError(Object e) {
    final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
    if (match != null) return match.group(1)!;
    return 'Ocurrió un error. Intenta de nuevo.';
  }
}

final recuperacionProvider =
    StateNotifierProvider.autoDispose<RecuperacionNotifier, RecuperacionState>(
  (ref) => RecuperacionNotifier(),
);