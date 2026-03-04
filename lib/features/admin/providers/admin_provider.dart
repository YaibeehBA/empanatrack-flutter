import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Modelos ───────────────────────────────────────────────

class VendedorAdmin {
  final String  id;
  final String  nombreCompleto;
  final String? telefono;
  final String  nombreUsuario;
  final String? correo;
  final bool    estaActivo;

  const VendedorAdmin({
    required this.id,
    required this.nombreCompleto,
    this.telefono,
    required this.nombreUsuario,
    this.correo,
    required this.estaActivo,
  });

  factory VendedorAdmin.fromJson(Map<String, dynamic> j) => VendedorAdmin(
    id:             j['id'],
    nombreCompleto: j['nombre_completo'],
    telefono:       j['telefono'],
    nombreUsuario:  j['nombre_usuario'],
    correo:         j['correo'],
    estaActivo:     j['esta_activo'],
  );
}

class EmpresaAdmin {
  final String  id;
  final String  nombre;
  final String? direccion;
  final String? telefono;
  final bool    estaActiva;

  const EmpresaAdmin({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.estaActiva,
  });

  factory EmpresaAdmin.fromJson(Map<String, dynamic> j) => EmpresaAdmin(
    id:        j['id'],
    nombre:    j['nombre'],
    direccion: j['direccion'],
    telefono:  j['telefono'],
    estaActiva: j['esta_activa'],
  );
}

class ProductoAdmin {
  final String id;
  final String nombre;
  final double precio;
  final bool   estaActivo;

  const ProductoAdmin({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.estaActivo,
  });

  factory ProductoAdmin.fromJson(Map<String, dynamic> j) => ProductoAdmin(
    id:         j['id'],
    nombre:     j['nombre'],
    precio:     (j['precio'] as num).toDouble(),
    estaActivo: j['esta_activo'],
  );
}

class ResumenAdmin {
  final double totalDeudas;
  final int    clientesConDeuda;
  final int    vendedoresActivos;
  final double vendidoHoy;

  const ResumenAdmin({
    required this.totalDeudas,
    required this.clientesConDeuda,
    required this.vendedoresActivos,
    required this.vendidoHoy,
  });

  factory ResumenAdmin.fromJson(Map<String, dynamic> j) => ResumenAdmin(
    totalDeudas:       (j['total_deudas']       as num).toDouble(),
    clientesConDeuda:  (j['clientes_con_deuda'] as num).toInt(),
    vendedoresActivos: (j['vendedores_activos'] as num).toInt(),
    vendidoHoy:        (j['vendido_hoy']        as num).toDouble(),
  );
}

// ── Providers de lectura ──────────────────────────────────

final vendedoresAdminProvider = FutureProvider<List<VendedorAdmin>>((ref) async {
  final r = await ApiClient.get('/admin/vendedores');
  return (r.data as List).map((v) => VendedorAdmin.fromJson(v)).toList();
});

final empresasAdminProvider = FutureProvider<List<EmpresaAdmin>>((ref) async {
  final r = await ApiClient.get('/admin/empresas');
  return (r.data as List).map((e) => EmpresaAdmin.fromJson(e)).toList();
});

final productosAdminProvider = FutureProvider<List<ProductoAdmin>>((ref) async {
  final r = await ApiClient.get('/admin/productos');
  return (r.data as List).map((p) => ProductoAdmin.fromJson(p)).toList();
});

final resumenAdminProvider = FutureProvider<ResumenAdmin>((ref) async {
  final r = await ApiClient.get('/admin/resumen');
  return ResumenAdmin.fromJson(r.data);
});

// ── Provider de operaciones (crear/editar) ────────────────

class AdminOpState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;
  const AdminOpState({
    this.cargando = false, this.error, this.exitoso = false,
  });
  AdminOpState copyWith({bool? cargando, String? error, bool? exitoso}) =>
      AdminOpState(
        cargando: cargando ?? this.cargando,
        error:    error,
        exitoso:  exitoso  ?? this.exitoso,
      );
}

class AdminOpNotifier extends StateNotifier<AdminOpState> {
  AdminOpNotifier() : super(const AdminOpState());

  Future<void> crearVendedor(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/admin/vendedores', data: datos));

  Future<void> editarVendedor(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/vendedores/$id', data: datos));

  Future<void> crearEmpresa(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/admin/empresas', data: datos));

  Future<void> editarEmpresa(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/empresas/$id', data: datos));

  Future<void> crearProducto(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/admin/productos', data: datos));

  Future<void> editarProducto(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/productos/$id', data: datos));

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

  void resetear() => state = const AdminOpState();
}


final adminOpProvider =
    StateNotifierProvider<AdminOpNotifier, AdminOpState>(
  (ref) => AdminOpNotifier(),
);