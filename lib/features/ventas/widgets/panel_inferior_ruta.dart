import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

class PanelInferiorRuta extends StatelessWidget {
  final EstadoRutaHoy? estado;
  final bool enRuta;
  final bool cargando;
  final bool sinStock;
  final EmpresaRuta? puntoInicio;
  final double? distanciaAlInicio;
  final bool optimizacionLista;
  final VoidCallback onIniciarRuta;
  final VoidCallback onNuevaVenta;
  final VoidCallback onFinalizarRuta;

  const PanelInferiorRuta({
    super.key,
    required this.estado,
    required this.enRuta,
    required this.cargando,
    required this.sinStock,
    required this.onIniciarRuta,
    required this.onNuevaVenta,
    required this.onFinalizarRuta,
    required this.optimizacionLista,
    this.puntoInicio,
    this.distanciaAlInicio,
  });

  static const double _kRadioInicio = 30.0;

  bool get _puedeIniciar {
    if (enRuta) return true;
    if (!optimizacionLista) return false;
    if (puntoInicio == null) return false;
    if (distanciaAlInicio == null) return false;
    return distanciaAlInicio! <= _kRadioInicio;
  }

  String get _textoAviso {
    if (!optimizacionLista) return 'Calculando ruta óptima…';
    if (distanciaAlInicio == null) return 'Obteniendo tu ubicación…';
    final metros = distanciaAlInicio!.round();
    if (metros >= 1000) {
      return 'Estás a ${(metros / 1000).toStringAsFixed(1)} km del punto de inicio';
    }
    return 'Estás a $metros m — necesitas estar a ≤${_kRadioInicio.toInt()} m';
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColores.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -2)),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (!enRuta && puntoInicio != null) ...[
              _PuntoInicioCard(empresa: puntoInicio!, puedeIniciar: _puedeIniciar),
              const SizedBox(height: 10),
            ],

            if (!enRuta && !_puedeIniciar) ...[
              _AvisoEstado(
                texto: _textoAviso,
                calculando: !optimizacionLista || distanciaAlInicio == null,
              ),
              const SizedBox(height: 10),
            ],

            if (estado != null && enRuta && !sinStock)
              _ProximaEmpresaRow(estado: estado!),

            if (sinStock && enRuta) ...[
              _AvisoSinStock(),
              const SizedBox(height: 12),
            ] else if (estado != null && enRuta)
              const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: cargando
                    ? null
                    : (sinStock && enRuta)
                        ? onFinalizarRuta
                        : enRuta
                            ? onNuevaVenta
                            : _puedeIniciar
                                ? onIniciarRuta
                                : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (sinStock && enRuta)
                      ? AppColores.warning
                      : enRuta
                          ? AppColores.accent
                          : AppColores.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColores.primary.withOpacity(0.35),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: cargando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_iconoBoton, size: 22),
                label: Text(
                  _textoBoton,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );

  IconData get _iconoBoton {
    if (sinStock && enRuta) return Icons.flag_rounded;
    if (enRuta) return Icons.add_circle_outline;
    if (!optimizacionLista) return Icons.hourglass_top_rounded;
    if (!_puedeIniciar) return Icons.location_off_rounded;
    return Icons.play_arrow_rounded;
  }

  String get _textoBoton {
    if (sinStock && enRuta) return 'Finalizar ruta (sin stock)';
    if (enRuta) return 'Nueva venta rápida';
    if (!optimizacionLista) return 'Calculando ruta…';
    if (!_puedeIniciar) return 'Dirígete al punto de inicio';
    return 'INICIAR RUTA';
  }
}

class _PuntoInicioCard extends StatelessWidget {
  final EmpresaRuta empresa;
  final bool puedeIniciar;
  const _PuntoInicioCard({required this.empresa, required this.puedeIniciar});

  @override
  Widget build(BuildContext context) {
    final color = puedeIniciar ? AppColores.primary : AppColores.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(puedeIniciar ? Icons.flag_rounded : Icons.location_off_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PUNTO DE INICIO ÓPTIMO',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.6)),
                Text(empresa.nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
                if (empresa.direccion != null)
                  Text(empresa.direccion!,
                      style: const TextStyle(fontSize: 11, color: AppColores.textSecond),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 16),
        ],
      ),
    );
  }
}

class _AvisoEstado extends StatelessWidget {
  final String texto;
  final bool calculando;
  const _AvisoEstado({required this.texto, required this.calculando});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColores.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColores.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            calculando
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColores.warning))
                : const Icon(Icons.directions_walk_rounded, color: AppColores.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto, style: const TextStyle(fontSize: 12, color: AppColores.textSecond)),
            ),
          ],
        ),
      );
}

class _AvisoSinStock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColores.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColores.warning.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColores.warning, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Has agotado tu stock del día. Puedes finalizar la ruta.',
                  style: TextStyle(fontSize: 12, color: AppColores.textSecond)),
            ),
          ],
        ),
      );
}

class _ProximaEmpresaRow extends StatelessWidget {
  final EstadoRutaHoy estado;
  const _ProximaEmpresaRow({required this.estado});

  @override
  Widget build(BuildContext context) {
    final pendiente = estado.empresas.where((e) => !e.visitada).firstOrNull;
    if (pendiente == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColores.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColores.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.navigation_rounded, color: AppColores.primary, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SIGUIENTE PARADA',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                        color: AppColores.primary, letterSpacing: 0.6)),
                Text(pendiente.nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppColores.textPrimary)),
              ],
            ),
          ),
          _BadgePill(texto: 'En ruta'),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String texto;
  const _BadgePill({required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColores.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(texto,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColores.primary)),
      );
}