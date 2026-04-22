import 'package:flutter_riverpod/flutter_riverpod.dart';

final tabActivoProvider = StateProvider<int>((ref) => 0);
final mostrarMapaCompletadaProvider = StateProvider<bool>((ref) => false);

class Tabs {
  const Tabs._();
  static const int ruta = 0;
  static const int pedidos = 1;
  static const int clientes = 2;
  static const int config = 3;
}