import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/venta_model.dart';

// Historial con filtro de periodo
final historialVentasProvider =
    FutureProvider.family<List<VentaModel>, String>((ref, periodo) async {
  final response = await ApiClient.get(
    '/ventas/historial',
    params: {'periodo': periodo},
  );
  final lista = response.data as List;
  return lista.map((v) => VentaModel.fromJson(v)).toList();
});

// Ventas de hoy — alias para compatibilidad con otros providers
final ventasHoyProvider = FutureProvider<List<VentaModel>>((ref) async {
  final response = await ApiClient.get(
    '/ventas/historial',
    params: {'periodo': 'hoy'},
  );
  final lista = response.data as List;
  return lista.map((v) => VentaModel.fromJson(v)).toList();
});

// Parámetro para historial por fechas
class RangoFechas {
  final String desde;
  final String hasta;
  const RangoFechas({required this.desde, required this.hasta});

  @override
  bool operator ==(Object other) =>
      other is RangoFechas &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

// autoDispose → se destruye al salir y recarga al volver
final historialPorFechasProvider =
    FutureProvider.autoDispose.family<List<VentaModel>, RangoFechas>(
        (ref, rango) async {
  final r = await ApiClient.get('/ventas/historial-fechas', params: {
    'desde': rango.desde,
    'hasta': rango.hasta,
  });
  return (r.data as List)
      .map((v) => VentaModel.fromJson(v))
      .toList();
});