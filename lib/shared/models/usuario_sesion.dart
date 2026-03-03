class UsuarioSesion {
  final String token;
  final String rol;
  final String nombre;

  const UsuarioSesion({
    required this.token,
    required this.rol,
    required this.nombre,
  });
}