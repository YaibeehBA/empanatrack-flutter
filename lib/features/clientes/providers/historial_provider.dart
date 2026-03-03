import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/movimiento_model.dart';

// Recibe el cliente_id como parámetro
final historialProvider =
    FutureProvider.family<List<MovimientoModel>, String>((ref, clienteId) async {
  final response = await ApiClient.get('/clientes/$clienteId/historial');
  final lista    = response.data as List;
  return lista.map((m) => MovimientoModel.fromJson(m)).toList();
});