import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/producto_model.dart';

final productosProvider = FutureProvider<List<ProductoModel>>((ref) async {
  final response = await ApiClient.get('/productos/');
  final lista    = response.data as List;
  return lista.map((p) => ProductoModel.fromJson(p)).toList();
});