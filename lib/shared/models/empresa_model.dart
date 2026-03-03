class EmpresaModel {
  final String  id;
  final String  nombre;
  final String? direccion;

  const EmpresaModel({
    required this.id,
    required this.nombre,
    this.direccion,
  });

  factory EmpresaModel.fromJson(Map<String, dynamic> json) {
    return EmpresaModel(
      id:        json['id'],
      nombre:    json['nombre'],
      direccion: json['direccion'],
    );
  }
}