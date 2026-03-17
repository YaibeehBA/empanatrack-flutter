class Validators {
  /// Valida cédula ecuatoriana. Retorna null si es válida,
  /// o un mensaje de error si no lo es.
  static String? cedulaEcuador(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu número de cédula';
    }
    if (value.length != 10) {
      return 'La cédula debe tener 10 dígitos';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'La cédula solo debe contener números';
    }

    // Provincia entre 01 y 24
    final provincia = int.parse(value.substring(0, 2));
    if (provincia < 1 || provincia > 24) {
      return 'Los dos primeros dígitos no son válidos';
    }

    // Tercer dígito menor a 6
    if (int.parse(value[2]) >= 6) {
      return 'El tercer dígito no es válido';
    }

    // Módulo 10
    const coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int total = 0;
    for (int i = 0; i < coeficientes.length; i++) {
      int valor = int.parse(value[i]) * coeficientes[i];
      if (valor >= 10) valor -= 9;
      total += valor;
    }

    final residuo = total % 10;
    final digitoVerificador = residuo == 0 ? 0 : 10 - residuo;

    if (digitoVerificador != int.parse(value[9])) {
      return 'La cédula no es válida';
    }

    return null; // ✅ válida
  }

static String? telefonoEcuador(String? value) {
  if (value == null || value.isEmpty) return null; // opcional
  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return 'El teléfono solo debe contener números';
  }
  if (value.length != 10) {
    return 'El teléfono debe tener 10 dígitos';
  }
  return null;
}
static String? latitud(String? value) {
    if (value == null || value.isEmpty) return null; // opcional
    final v = double.tryParse(value);
    if (v == null) return 'Ingresa un número válido';
    if (v < -90 || v > 90) return 'Latitud debe estar entre -90 y 90';
    return null;
  }

  static String? longitud(String? value) {
    if (value == null || value.isEmpty) return null; // opcional
    final v = double.tryParse(value);
    if (v == null) return 'Ingresa un número válido';
    if (v < -180 || v > 180) return 'Longitud debe estar entre -180 y 180';
    return null;
  }
}

