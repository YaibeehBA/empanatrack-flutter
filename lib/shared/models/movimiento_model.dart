class MovimientoModel {
  final String  clienteId;
  final String  nombreCliente;
  final String  tipoMovimiento;  // 'venta' o 'pago'
  final String  referenciaId;
  final double  monto;
  final String  detalleTipo;
  final String  estado;
  final String  fecha;
  final String  vendedor;

  const MovimientoModel({
    required this.clienteId,
    required this.nombreCliente,
    required this.tipoMovimiento,
    required this.referenciaId,
    required this.monto,
    required this.detalleTipo,
    required this.estado,
    required this.fecha,
    required this.vendedor,
  });

  factory MovimientoModel.fromJson(Map<String, dynamic> json) {
    return MovimientoModel(
      clienteId:      json['cliente_id'].toString(),
      nombreCliente:  json['nombre_cliente'],
      tipoMovimiento: json['tipo_movimiento'],
      referenciaId:   json['referencia_id'].toString(),
      monto:          (json['monto'] as num).toDouble(),
      detalleTipo:    json['detalle_tipo'],
      estado:         json['estado'],
      fecha:          json['fecha'].toString(),
      vendedor:       json['vendedor'],
    );
  }

  bool get esVenta => tipoMovimiento == 'venta';
  bool get esPago  => tipoMovimiento == 'pago';
}