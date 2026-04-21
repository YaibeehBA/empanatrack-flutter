import 'package:geolocator/geolocator.dart';

class UbicacionUtil {
  /// Obtiene la posición actual del dispositivo.
  /// Retorna null si no hay permisos o falla.
  static Future<({double lat, double lng})?> obtenerPosicionActual() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }
}