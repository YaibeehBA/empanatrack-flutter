import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ══════════════════════════════════════════════════════════
//  MODELOS
// ══════════════════════════════════════════════════════════
class ResumenGeneral {
  final String periodo;
  final int    totalVentas;
  final double totalVendido;
  final double totalContado;
  final double totalFiado;
  final double totalCobrado;
  final double totalDeudas;
  final int    clientesConDeuda;

  const ResumenGeneral({
    required this.periodo,
    required this.totalVentas,
    required this.totalVendido,
    required this.totalContado,
    required this.totalFiado,
    required this.totalCobrado,
    required this.totalDeudas,
    required this.clientesConDeuda,
  });

  factory ResumenGeneral.fromJson(Map<String, dynamic> j) => ResumenGeneral(
    periodo:          j['periodo'],
    totalVentas:      j['total_ventas'],
    totalVendido:     (j['total_vendido']  as num).toDouble(),
    totalContado:     (j['total_contado']  as num).toDouble(),
    totalFiado:       (j['total_fiado']    as num).toDouble(),
    totalCobrado:     (j['total_cobrado']  as num).toDouble(),
    totalDeudas:      (j['total_deudas']   as num).toDouble(),
    clientesConDeuda: j['clientes_con_deuda'],
  );
}

class VentaVendedor {
  final String vendedorId;
  final String nombre;
  final int    totalVentas;
  final double totalVendido;
  final double totalContado;
  final double totalFiado;
  final double totalCobrado;

  const VentaVendedor({
    required this.vendedorId,
    required this.nombre,
    required this.totalVentas,
    required this.totalVendido,
    required this.totalContado,
    required this.totalFiado,
    required this.totalCobrado,
  });

  factory VentaVendedor.fromJson(Map<String, dynamic> j) => VentaVendedor(
    vendedorId:   j['vendedor_id'],
    nombre:       j['nombre'],
    totalVentas:  j['total_ventas'],
    totalVendido: (j['total_vendido'] as num).toDouble(),
    totalContado: (j['total_contado'] as num).toDouble(),
    totalFiado:   (j['total_fiado']   as num).toDouble(),
    totalCobrado: (j['total_cobrado'] as num).toDouble(),
  );
}

class ProductoVendido {
  final String productoId;
  final String nombre;
  final double precioUnitario;
  final int    totalCantidad;
  final double totalIngresos;

  const ProductoVendido({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.totalCantidad,
    required this.totalIngresos,
  });

  factory ProductoVendido.fromJson(Map<String, dynamic> j) => ProductoVendido(
    productoId:     j['producto_id'],
    nombre:         j['nombre'],
    precioUnitario: (j['precio_unitario'] as num).toDouble(),
    totalCantidad:  j['total_cantidad'],
    totalIngresos:  (j['total_ingresos']  as num).toDouble(),
  );
}

class DeudaCliente {
  final String  clienteId;
  final String  nombre;
  final String? empresa;
  final double  saldoActual;

  const DeudaCliente({
    required this.clienteId,
    required this.nombre,
    this.empresa,
    required this.saldoActual,
  });

  factory DeudaCliente.fromJson(Map<String, dynamic> j) => DeudaCliente(
    clienteId:   j['cliente_id'].toString(),
    nombre:      j['nombre']    ?? j['cliente'] ?? '',
    empresa:     j['empresa'],
    saldoActual: (j['saldo_actual'] as num).toDouble(),
  );
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS — con periodo como familia
// ══════════════════════════════════════════════════════════
final resumenGeneralProvider =
    FutureProvider.family<ResumenGeneral, String>((ref, periodo) async {
  final r = await ApiClient.get(
      '/reportes/admin/resumen-general',
      params: {'periodo': periodo});
  return ResumenGeneral.fromJson(r.data);
});

final ventasPorVendedorProvider =
    FutureProvider.family<List<VentaVendedor>, String>((ref, periodo) async {
  final r = await ApiClient.get(
      '/reportes/admin/ventas-por-vendedor',
      params: {'periodo': periodo});
  return (r.data as List).map((v) => VentaVendedor.fromJson(v)).toList();
});

final productosMasVendidosProvider =
    FutureProvider.family<List<ProductoVendido>, String>((ref, periodo) async {
  final r = await ApiClient.get(
      '/reportes/admin/productos-mas-vendidos',
      params: {'periodo': periodo});
  return (r.data as List).map((p) => ProductoVendido.fromJson(p)).toList();
});

final deudasClientesProvider =
    FutureProvider<List<DeudaCliente>>((ref) async {
  final r = await ApiClient.get('/reportes/admin/deudas');
  return (r.data as List).map((d) => DeudaCliente.fromJson(d)).toList();
});