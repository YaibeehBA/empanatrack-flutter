class VentaModel {
  final String  id;
  final String  tipo;
  final double  montoTotal;
  final double  montoPagado;
  final double  montoPendiente;
  final String  estado;
  final String  fechaVenta;
  final String? cliente;
  final String  vendedor;

  const VentaModel({
    required this.id,
    required this.tipo,
    required this.montoTotal,
    required this.montoPagado,
    required this.montoPendiente,
    required this.estado,
    required this.fechaVenta,
    this.cliente,
    required this.vendedor,
  });

  factory VentaModel.fromJson(Map<String, dynamic> json) {
    return VentaModel(
      id:              json['id'],
      tipo:            json['tipo'],
      montoTotal:      (json['monto_total']     as num).toDouble(),
      montoPagado:     (json['monto_pagado']    as num).toDouble(),
      montoPendiente:  (json['monto_pendiente'] as num).toDouble(),
      estado:          json['estado'],
      fechaVenta:      json['fecha_venta'],
      cliente:         json['cliente'],
      vendedor:        json['vendedor'],
    );
  }
}