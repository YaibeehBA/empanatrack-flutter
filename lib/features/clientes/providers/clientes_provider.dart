import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/cliente_model.dart';

// Provider para la lista de clientes del vendedor
final clientesProvider = FutureProvider<List<ClienteModel>>((ref) async {
  final response = await ApiClient.get('/clientes/');
  final lista    = response.data as List;
  return lista.map((c) => ClienteModel.fromJson(c)).toList();
});