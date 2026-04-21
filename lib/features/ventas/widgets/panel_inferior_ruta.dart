import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

class PanelInferiorRuta extends StatelessWidget {
  final EstadoRutaHoy? estado;
  final bool enRuta;
  final bool cargando;
  final bool sinStock;
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
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColores.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -2)),
      ],
    ),
    padding: EdgeInsets.fromLTRB(
      16,
      14,
      16,
      MediaQuery.of(context).padding.bottom + 14,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Próxima empresa
        if (estado != null && enRuta && !sinStock)
          _ProximaEmpresaRow(estado: estado!),

        // Aviso sin stock
        if (sinStock && enRuta) ...[
          _AvisoSinStock(),
          const SizedBox(height: 12),
        ] else if (estado != null && enRuta)
          const SizedBox(height: 12),

        // Botón principal
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            // Sin stock en ruta → siempre mostrar finalizar, no desaparece
            onPressed: cargando
                ? null
                : ((sinStock && enRuta)
                      ? onFinalizarRuta
                      : enRuta
                      ? onNuevaVenta
                      : onIniciarRuta),
            style: ElevatedButton.styleFrom(
              backgroundColor: (sinStock && enRuta)
                  ? AppColores.warning
                  : enRuta
                  ? AppColores.accent
                  : AppColores.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    (sinStock && enRuta)
                        ? Icons.flag_rounded
                        : enRuta
                        ? Icons.add_circle_outline
                        : Icons.play_arrow_rounded,
                    size: 22,
                  ),
            label: Text(
              (sinStock && enRuta)
                  ? 'Finalizar ruta (sin stock)'
                  : enRuta
                  ? 'Nueva venta rápida'
                  : 'INICIAR RUTA',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Aviso sin stock ───────────────────────────────────────
class _AvisoSinStock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColores.warning.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColores.warning.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          color: AppColores.warning,
          size: 18,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Has agotado tu stock del día. '
            'Puedes finalizar la ruta.',
            style: TextStyle(fontSize: 12, color: AppColores.textSecond),
          ),
        ),
      ],
    ),
  );
}

// ── Próxima empresa ───────────────────────────────────────
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
              color: AppColores.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: AppColores.primary,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIGUIENTE PARADA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColores.primary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  pendiente.nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary,
                  ),
                ),
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
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppColores.primary,
      ),
    ),
  );
}
