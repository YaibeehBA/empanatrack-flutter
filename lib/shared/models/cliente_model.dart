class ClienteModel {
  final String  id;
  final String  cedula;
  final String  nombre;
  final String? correo;
  final String? telefono;
  final String? empresa;
  final double  saldoActual;

  const ClienteModel({
    required this.id,
    required this.cedula,
    required this.nombre,
    this.correo,
    this.telefono,
    this.empresa,
    required this.saldoActual,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id:          json['id'],
      cedula:      json['cedula'],
      nombre:      json['nombre'],
      correo:      json['correo'],
      telefono:    json['telefono'],
      empresa:     json['empresa'],
      saldoActual: (json['saldo_actual'] as num).toDouble(),
    );
  }
}