import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Modelo resumen ─────────────────────────────────────────
class ResumenDia {
  final int    totalVentas;
  final double totalVendido;
  final double totalFiado;
  final double totalContado;
  final double totalCobrado;

  const ResumenDia({
    required this.totalVentas,
    required this.totalVendido,
    required this.totalFiado,
    required this.totalContado,
    required this.totalCobrado,
  });

  factory ResumenDia.fromJson(Map<String, dynamic> json) => ResumenDia(
    totalVentas:  (json['total_ventas']  as num).toInt(),
    totalVendido: (json['total_vendido'] as num).toDouble(),
    totalFiado:   (json['total_fiado']   as num).toDouble(),
    totalContado: (json['total_contado'] as num).toDouble(),
    totalCobrado: (json['total_cobrado'] as num).toDouble(),
  );

  factory ResumenDia.vacio() => const ResumenDia(
    totalVentas: 0, totalVendido: 0,
    totalFiado: 0, totalContado: 0, totalCobrado: 0,
  );
}

// ── Provider del periodo seleccionado ─────────────────────
// Persiste mientras el dashboard esté vivo
final periodoSeleccionadoProvider = StateProvider<String>((ref) => 'hoy');

// ── Provider del resumen según periodo ────────────────────
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