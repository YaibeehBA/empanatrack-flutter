import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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
  final double? latitud;    
  final double? longitud;   

  const EmpresaAdmin({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.estaActiva,
    this.latitud,            
    this.longitud,           
  });

  factory EmpresaAdmin.fromJson(Map<String, dynamic> j) => EmpresaAdmin(
    id:         j['id'],
    nombre:     j['nombre'],
    direccion:  j['direccion'],
    telefono:   j['telefono'],
    estaActiva: j['esta_activa'],
    latitud:    j['latitud']  != null
        ? (j['latitud']  as num).toDouble() : null,
    longitud:   j['longitud'] != null
        ? (j['longitud'] as num).toDouble() : null,
  );
}

// ── ProductoAdmin con imagenUrl ───────────────────────────
class ProductoAdmin {
  final String  id;
  final String  nombre;
  final double  precio;
  final bool    estaActivo;
  final String? imagenUrl;   // ← NUEVO

  const ProductoAdmin({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.estaActivo,
    this.imagenUrl,
  });

  factory ProductoAdmin.fromJson(Map<String, dynamic> j) => ProductoAdmin(
    id:         j['id'],
    nombre:     j['nombre'],
    precio:     (j['precio'] as num).toDouble(),
    estaActivo: j['esta_activo'],
    imagenUrl:  j['imagen_url'],   // ← NUEVO
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

// ── Provider de operaciones ───────────────────────────────

class AdminOpState {
  final bool    cargando;
  final String? error;
  final bool    exitoso;
  final String? ultimoId;  // ← AGREGADO

  const AdminOpState({
    this.cargando = false, 
    this.error, 
    this.exitoso = false, 
    this.ultimoId,  // ← AGREGADO
  });
  
  AdminOpState copyWith({
    bool? cargando, 
    String? error, 
    bool? exitoso, 
    String? ultimoId,  // ← AGREGADO
  }) => AdminOpState(
    cargando: cargando ?? this.cargando,
    error:    error,
    exitoso:  exitoso  ?? this.exitoso,
    ultimoId: ultimoId ?? this.ultimoId,  // ← AGREGADO
  );
}

class AdminOpNotifier extends StateNotifier<AdminOpState> {
  AdminOpNotifier() : super(const AdminOpState());

  // ── MODIFICADO: crearProducto guarda el id ─────────────
  Future<void> crearProducto(Map<String, dynamic> datos) async {
    state = state.copyWith(cargando: true);
    try {
      final r = await ApiClient.post('/admin/productos', data: datos);
      state = state.copyWith(
        cargando: false,
        exitoso:  true,
        ultimoId: r.data['id'].toString(),
      );
    } catch (e) {
      String msg = 'Error en la operación.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

  Future<void> editarProducto(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/productos/$id', data: datos));

  // ── AGREGADO: eliminarProducto ─────────────────────────
  Future<void> eliminarProducto(String id) async {
    state = state.copyWith(cargando: true);
    try {
      await ApiClient.delete('/admin/productos/$id');
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String msg = 'Error al eliminar.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }
//---------------

Future<void> eliminarVendedor(String id) =>
    _ejecutar(() => ApiClient.delete('/admin/vendedores/$id'));

Future<void> eliminarEmpresa(String id) =>
    _ejecutar(() => ApiClient.delete('/admin/empresas/$id'));

Future<void> eliminarCliente(String id) =>
    _ejecutar(() => ApiClient.delete('/clientes/$id'));
//-----------
  Future<void> crearVendedor(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/admin/vendedores', data: datos));

  Future<void> editarVendedor(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/vendedores/$id', data: datos));

  Future<void> crearEmpresa(Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.post('/admin/empresas', data: datos));

  Future<void> editarEmpresa(String id, Map<String, dynamic> datos) =>
      _ejecutar(() => ApiClient.put('/admin/empresas/$id', data: datos));

  // ── subir imagen a un producto existente ───────────────
  Future<void> subirImagenProducto(String id, XFile imagen) async {
    state = state.copyWith(cargando: true);
    try {
      final formData = FormData.fromMap({
        'imagen': await MultipartFile.fromFile(
          imagen.path,
          filename: imagen.name,
        ),
      });
      await ApiClient.postFormData(
        '/admin/productos/$id/imagen',
        formData: formData,
      );
      state = state.copyWith(cargando: false, exitoso: true);
    } catch (e) {
      String msg = 'Error al subir la imagen.';
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(e.toString());
      if (match != null) msg = match.group(1)!;
      state = state.copyWith(cargando: false, error: msg);
    }
  }

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