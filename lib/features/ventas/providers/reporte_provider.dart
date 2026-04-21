import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'ventas_provider.dart';

class ResumenDia {
  final int    totalVentas;
  final double totalVendido;
  final double totalFiado;
  final double totalContado;
  final double totalCobrado;
  final int    pedidosEntregados;
  final double totalPedidosContado;
  final double totalPedidosTransf;
  final double dineroEnMano;

  const ResumenDia({
    required this.totalVentas,
    required this.totalVendido,
    required this.totalFiado,
    required this.totalContado,
    required this.totalCobrado,
    required this.pedidosEntregados,
    required this.totalPedidosContado,
    required this.totalPedidosTransf,
    required this.dineroEnMano,
  });

  factory ResumenDia.fromJson(Map<String, dynamic> j) => ResumenDia(
    totalVentas:         (j['total_ventas']         as num).toInt(),
    totalVendido:        (j['total_vendido']         as num).toDouble(),
    totalFiado:          (j['total_fiado']           as num).toDouble(),
    totalContado:        (j['total_contado']         as num).toDouble(),
    totalCobrado:        (j['total_cobrado']         as num).toDouble(),
    pedidosEntregados:   (j['pedidos_entregados']    as num).toInt(),
    totalPedidosContado: (j['total_pedidos_contado'] as num).toDouble(),
    totalPedidosTransf:  (j['total_pedidos_transf']  as num).toDouble(),
    dineroEnMano:        (j['dinero_en_mano']        as num).toDouble(),
  );

  factory ResumenDia.vacio() => const ResumenDia(
    totalVentas:         0,
    totalVendido:        0,
    totalFiado:          0,
    totalContado:        0,
    totalCobrado:        0,
    pedidosEntregados:   0,
    totalPedidosContado: 0,
    totalPedidosTransf:  0,
    dineroEnMano:        0,
  );
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════════
final periodoSeleccionadoProvider =
    StateProvider<String>((ref) => 'hoy');

final resumenDiaProvider =
    FutureProvider.family<ResumenDia, String>((ref, periodo) async {
  final response = await ApiClient.get(
    '/reportes/vendedor/resumen',
    params: {'periodo': periodo},
  );
  if (response.data == null || (response.data as Map).isEmpty) {
    return ResumenDia.vacio();
  }
  return ResumenDia.fromJson(response.data);
});

// autoDispose → se destruye al salir de la pantalla y recarga al volver
final resumenPorFechasProvider =
    FutureProvider.autoDispose.family<ResumenDia, RangoFechas>(
        (ref, rango) async {
  final r = await ApiClient.get(
    '/reportes/vendedor/resumen-fechas',
    params: {'desde': rango.desde, 'hasta': rango.hasta},
  );
  if (r.data == null || (r.data as Map).isEmpty) {
    return ResumenDia.vacio();
  }
  return ResumenDia.fromJson(r.data);
});