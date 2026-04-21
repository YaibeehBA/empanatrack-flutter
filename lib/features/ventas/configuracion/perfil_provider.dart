import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class PerfilVendedor {
  final String  id;
  final String  nombre;
  final String? telefono;
  final String  nombreUsuario;
  final String  rol;

  const PerfilVendedor({
    required this.id,
    required this.nombre,
    this.telefono,
    required this.nombreUsuario,
    required this.rol,
  });

  factory PerfilVendedor.fromJson(Map<String, dynamic> j) =>
      PerfilVendedor(
        id:            j['id'].toString(),
        nombre:        j['nombre'].toString(),
        telefono:      j['telefono']?.toString(),
        nombreUsuario: j['nombre_usuario'].toString(),
        rol:           j['rol'].toString(),
      );
}

final perfilVendedorProvider =
    FutureProvider.autoDispose<PerfilVendedor>((ref) async {
  final r = await ApiClient.get('/vendedores/mi-perfil');
  return PerfilVendedor.fromJson(r.data);
});