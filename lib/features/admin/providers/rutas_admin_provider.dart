import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';


// ── Modelos existentes ────────────────────────────────────
class EmpresaRuta {
  final String  id;
  final String  nombre;
  final String? direccion;
  final String? telefono;
  final double? latitud;
  final double? longitud;

  const EmpresaRuta({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.latitud,
    this.longitud,
  });

  bool get tieneCoordenadas => latitud != null && longitud != null;

  factory EmpresaRuta.fromJson(Map<String, dynamic> j) => EmpresaRuta(
        id:        j['id'],
        nombre:    j['nombre'],
        direccion: j['direccion'],
        telefono:  j['telefono'],
        latitud:   j['latitud']  != null
            ? (j['latitud']  as num).toDouble() : null,
        longitud:  j['longitud'] != null
            ? (j['longitud'] as num).toDouble() : null,
      );
}

class AsignacionRuta {
  final String id;
  final String vendedorId;
  final String nombre;
  final String turno;
  final bool   estaActiva;

  const AsignacionRuta({
    required this.id,
    required this.vendedorId,
    required this.nombre,
    required this.turno,
    required this.estaActiva,
  });

  factory AsignacionRuta.fromJson(Map<String, dynamic> j) => AsignacionRuta(
        id:         j['id'],
        vendedorId: j['vendedor_id'],
        nombre:     j['nombre'],
        turno:      j['turno'],
        estaActiva: j['esta_activa'],
      );

  String get turnoLabel {
    switch (turno) {
      case 'mañana': return '🌅 Mañana';
      case 'tarde':  return '🌇 Tarde';
      default:       return '🕐 Única';
    }
  }
}

class RutaAdmin {
  final String            id;
  final String            nombre;
  final String?           descripcion;
  final bool              estaActiva;
  final List<EmpresaRuta> empresas;
  final List<AsignacionRuta> asignaciones;

  const RutaAdmin({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.estaActiva,
    required this.empresas,
    required this.asignaciones,
  });

  factory RutaAdmin.fromJson(Map<String, dynamic> j) => RutaAdmin(
        id:          j['id'],
        nombre:      j['nombre'],
        descripcion: j['descripcion'],
        estaActiva:  j['esta_activa'],
        empresas: (j['empresas'] as List)
            .map((e) => EmpresaRuta.fromJson(e))
            .toList(),
        asignaciones: (j['asignaciones'] as List)
            .map((a) => AsignacionRuta.fromJson(a))
            .toList(),
      );
}

// ── NUEVOS: Modelos respuesta calculada ───────────────────
class PuntoRuta {
  final double latitud;
  final double longitud;
  
  const PuntoRuta({required this.latitud, required this.longitud});
  
  factory PuntoRuta.fromJson(Map<String, dynamic> j) => PuntoRuta(
    latitud:  (j['latitud']  as num).toDouble(),
    longitud: (j['longitud'] as num).toDouble(),
  );
}

class ParadaRuta {
  final String  empresaId;
  final String  nombre;
  final String? direccion;
  final double  latitud;
  final double  longitud;
  final double  distanciaDesdeAnterior;
  final bool    esInicio;
  final bool    esFin;

  const ParadaRuta({
    required this.empresaId,
    required this.nombre,
    this.direccion,
    required this.latitud,
    required this.longitud,
    required this.distanciaDesdeAnterior,
    required this.esInicio,
    required this.esFin,
  });

  factory ParadaRuta.fromJson(Map<String, dynamic> j) => ParadaRuta(
    empresaId:               j['empresa_id'],
    nombre:                  j['nombre'],
    direccion:               j['direccion'],
    latitud:                 (j['latitud']  as num).toDouble(),
    longitud:                (j['longitud'] as num).toDouble(),
    distanciaDesdeAnterior:  (j['distancia_desde_anterior'] as num).toDouble(),
    esInicio:                j['es_inicio'],
    esFin:                   j['es_fin'],
  );

  String get distanciaLabel {
    if (distanciaDesdeAnterior < 1000) {
      return '${distanciaDesdeAnterior.toStringAsFixed(0)} m';
    }
    return '${(distanciaDesdeAnterior / 1000).toStringAsFixed(1)} km';
  }
}

class RutaCalculada {
  final List<ParadaRuta> paradas;
  final List<PuntoRuta>  puntosPolilinea;
  final double           distanciaTotal;
  final double           tiempoMinutos;
  final String           fuente;

  const RutaCalculada({
    required this.paradas,
    required this.puntosPolilinea,
    required this.distanciaTotal,
    required this.tiempoMinutos,
    required this.fuente,
  });

  factory RutaCalculada.fromJson(Map<String, dynamic> j) => RutaCalculada(
    paradas: (j['paradas'] as List)
        .map((p) => ParadaRuta.fromJson(p)).toList(),
    puntosPolilinea: (j['puntos_polilinea'] as List)
        .map((p) => PuntoRuta.fromJson(p)).toList(),
    distanciaTotal: (j['distancia_total'] as num).toDouble(),
    tiempoMinutos:  (j['tiempo_minutos']  as num).toDouble(),
    fuente:         j['fuente'],
  );

  String get tiempoLabel {
    if (tiempoMinutos < 60) return '${tiempoMinutos.toStringAsFixed(0)} min';
    final h = (tiempoMinutos / 60).floor();
    return '${h}h ${(tiempoMinutos % 60).toStringAsFixed(0)}min';
  }

  String get distanciaLabel {
    if (distanciaTotal < 1000) return '${distanciaTotal.toStringAsFixed(0)} m';
    return '${(distanciaTotal / 1000).toStringAsFixed(1)} km';
  }
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS DE LECTURA
// ══════════════════════════════════════════════════════════
final rutasAdminProvider = FutureProvider<List<RutaAdmin>>((ref) async {
  final r = await ApiClient.get('/rutas/admin');
  return (r.data as List).map((r) => RutaAdmin.fromJson(r)).toList();
});

final rutaDetalleProvider =
    FutureProvider.family<RutaAdmin, String>((ref, id) async {
  final r = await ApiClient.get('/rutas/admin/$id');
  return RutaAdmin.fromJson(r.data);
});

// ── NUEVO: Provider para ruta calculada ───────────────────
final rutaCalculadaProvider =
    FutureProvider.family<RutaCalculada, String>((ref, rutaId) async {
  final r = await ApiClient.get('/rutas/calcular/$rutaId');
  return RutaCalculada.fromJson(r.data);
});

// ══════════════════════════════════════════════════════════
//  ESTADO DE OPERACIONES
// ══════════════════════════════════════════════════════════
class RutaOpState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;

  const RutaOpState({
    this.cargando = false,
    this.error,
    this.exitoso  = false,
  });

  RutaOpState copyWith({
    bool?   cargando,
    String? error,
    bool?   exitoso,
  }) =>
      RutaOpState(
        cargando: cargando ?? this.cargando,
        error:    error,
        exitoso:  exitoso  ?? this.exitoso,
      );
}

class RutaOpNotifier extends StateNotifier<RutaOpState> {
  RutaOpNotifier() : super(const RutaOpState());

  Future<void> crearRuta(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/rutas/admin', data: datos));

  Future<void> editarRuta(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/rutas/admin/$id', data: datos));

  Future<void> eliminarRuta(String id) =>
      _ejecutar(() => ApiClient.delete('/rutas/admin/$id'));

  Future<void> actualizarEmpresas(
          String id, List<String> empresaIds) =>
      _ejecutar(() => ApiClient.put(
            '/rutas/admin/$id/empresas',
            data: {'empresa_ids': empresaIds},
          ));

  Future<void> asignarVendedor(
          String rutaId, String vendedorId, String turno) =>
      _ejecutar(() => ApiClient.post(
            '/rutas/admin/$rutaId/asignaciones',
            data: {'vendedor_id': vendedorId, 'turno': turno},
          ));

  Future<void> eliminarAsignacion(String asignacionId) =>
      _ejecutar(
          () => ApiClient.delete('/rutas/admin/asignaciones/$asignacionId'));

  Future<void> actualizarCoordenadas(
          String empresaId, double lat, double lng) =>
      _ejecutar(() => ApiClient.put(
            '/rutas/admin/empresas/$empresaId/coordenadas',
            data: {'latitud': lat, 'longitud': lng},
          ));

  Future<void> _ejecutar(Future Function() accion) async {
    state = state.copyWith(cargando: true);
    try {
      await accion();
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String msg = 'Error en la operación.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  void resetear() => state = const RutaOpState();
}

final rutaOpProvider =
    StateNotifierProvider<RutaOpNotifier, RutaOpState>(
  (ref) => RutaOpNotifier(),
);