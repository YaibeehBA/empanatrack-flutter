import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/venta_model.dart';

// Lista de ventas del día del vendedor
final ventasHoyProvider = FutureProvider<List<VentaModel>>((ref) async {
  final response = await ApiClient.get('/ventas/');
  final lista    = response.data as List;
  return lista.map((v) => VentaModel.fromJson(v)).toList();
});