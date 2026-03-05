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