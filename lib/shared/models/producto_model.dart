class ProductoModel {
  final String id;
  final String nombre;
  final double precio;

  const ProductoModel({
    required this.id,
    required this.nombre,
    required this.precio,
  });

  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    return ProductoModel(
      id:     json['id'],
      nombre: json['nombre'],
      precio: (json['precio'] as num).toDouble(),
    );
  }
}