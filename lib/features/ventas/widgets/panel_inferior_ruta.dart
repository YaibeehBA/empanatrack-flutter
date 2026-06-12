import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';
import '../providers/recarga_stock_provider.dart';

class PanelInferiorRuta extends StatelessWidget {
  final EstadoRutaHoy? estado;
  final bool           enRuta;
  final bool           cargando;
  final bool           sinStock;
  final EmpresaRuta?   puntoInicio;
  final double?        distanciaAlInicio;
  final bool           optimizacionLista;
  final bool           viendoResumen;
  final RecargaStock?  recarga;
  final VoidCallback   onIniciarRuta;
  final VoidCallback   onNuevaVenta;
  final VoidCallback   onFinalizarRuta;
  final VoidCallback?  onSolicitarRecarga;
  final VoidCallback?  onCompletarRecarga;
  final VoidCallback?  onVerResumen;

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
    this.viendoResumen     = false,
    this.recarga,
    this.onSolicitarRecarga,
    this.onCompletarRecarga,
    this.onVerResumen,
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

  String get _textoBoton {
    if ((estado?.sesionCompletada ?? false) ||
        (estado?.completada       ?? false)) return 'Ver resumen del día';
    if (sinStock && enRuta) return 'Finalizar ruta (sin stock)';
    if (enRuta) return 'Nueva venta rápida';
    if (!optimizacionLista) return 'Calculando ruta…';
    if (!_puedeIniciar) return 'Dirígete al punto de inicio';
    return 'INICIAR RUTA';
  }

  IconData get _iconoBoton {
    if ((estado?.sesionCompletada ?? false) ||
        (estado?.completada       ?? false)) return Icons.summarize_rounded;
    if (sinStock && enRuta) return Icons.flag_rounded;
    if (enRuta) return Icons.add_circle_outline;
    if (!optimizacionLista) return Icons.hourglass_top_rounded;
    if (!_puedeIniciar) return Icons.location_off_rounded;
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color:        AppColores.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [BoxShadow(
          color: Colors.black12, blurRadius: 16, offset: Offset(0, -2))],
    ),
    padding: EdgeInsets.fromLTRB(
      16, 14, 16,
      MediaQuery.of(context).padding.bottom + 14,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 12),

        // Punto de inicio
        if (!enRuta && puntoInicio != null) ...[
          _PuntoInicioCard(empresa: puntoInicio!, puedeIniciar: _puedeIniciar),
          const SizedBox(height: 10),
        ],

        // Aviso distancia
        if (!enRuta && !_puedeIniciar) ...[
          _AvisoEstado(
            texto:      _textoAviso,
            calculando: !optimizacionLista || distanciaAlInicio == null,
          ),
          const SizedBox(height: 10),
        ],

        // Próxima empresa (solo cuando hay stock)
        if (estado != null && enRuta && !sinStock)
          _ProximaEmpresaRow(estado: estado!),

        // ── SIN STOCK ─────────────────────────────────
        if (sinStock && enRuta) ...[
          _PanelSinStock(
            recarga:            recarga,
            onSolicitarRecarga: onSolicitarRecarga,
            onCompletarRecarga: onCompletarRecarga,
            onFinalizarRuta:    onFinalizarRuta,
            cargando:           cargando,
          ),
        ] else ...[
          if (enRuta) const SizedBox(height: 12),

          SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: cargando
                  ? null
                  : ((estado?.sesionCompletada ?? false) ||
                          (estado?.completada ?? false))
                      ? () => onVerResumen?.call()
                      : enRuta
                          ? onNuevaVenta
                          : _puedeIniciar ? onIniciarRuta : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    ((estado?.sesionCompletada ?? false) ||
                            (estado?.completada ?? false))
                        ? AppColores.primary
                        : enRuta
                            ? AppColores.accent
                            : AppColores.primary,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: AppColores.primary.withOpacity(0.35),
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: cargando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_iconoBoton, size: 22),
              label: Text(_textoBoton,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  PANEL SIN STOCK
// ══════════════════════════════════════════════════════════
class _PanelSinStock extends StatelessWidget {
  final RecargaStock? recarga;
  final VoidCallback? onSolicitarRecarga;
  final VoidCallback? onCompletarRecarga;
  final VoidCallback  onFinalizarRuta;
  final bool          cargando;

  const _PanelSinStock({
    required this.recarga,
    required this.onSolicitarRecarga,
    required this.onCompletarRecarga,
    required this.onFinalizarRuta,
    required this.cargando,
  });

  @override
  Widget build(BuildContext context) {
    final r = recarga;

    // Recarga aceptada → ir a punto de recarga
    if (r != null && r.esAceptada) {
      return _RecargaAceptadaPanel(
        recarga:            r,
        onCompletarRecarga: onCompletarRecarga,
        cargando:           cargando,
      );
    }

    // Recarga pendiente → esperar admin
    if (r != null && r.esPendiente) {
      return _RecargaPendientePanel(
        recarga:         r,
        onFinalizarRuta: onFinalizarRuta,
        cargando:        cargando,
      );
    }

    // ✅ Sin recarga activa → mostrar opciones
    // recargasUsadas ya incluye la pendiente si existe en BD
    // aquí r es null o está en estado completada/rechazada
    final puedeRecargar = r?.puedesolicitarMas ?? true;
    // ✅ FIX contador: si hay recarga pendiente o aceptada,
    //    sumar 1 a usadas para reflejar la actual
    final usadas = (r?.recargasUsadas ?? 0);
    final maxR   = r?.recargasMax ?? 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Aviso sin stock con contador
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        AppColores.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColores.warning.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined,
                color: AppColores.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sin stock disponible',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColores.warning,
                        fontSize:   13)),
                Text(
                  puedeRecargar
                      ? 'Puedes solicitar una recarga ($usadas/$maxR usadas)'
                      : 'Has alcanzado el límite de recargas ($maxR/$maxR)',
                  style: const TextStyle(
                      fontSize: 11, color: AppColores.textSecond),
                ),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 10),

        // ✅ Indicador de recargas
        _IndicadorRecargas(usadas: usadas, max: maxR),
        const SizedBox(height: 12),

        // Botones: Finalizar + Recargar (si puede)
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: cargando ? null : onFinalizarRuta,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.danger,
              side: BorderSide(color: AppColores.danger.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon:  const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Finalizar ruta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          )),

          if (puedeRecargar) ...[
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: cargando ? null : onSolicitarRecarga,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: cargando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.inventory_2_rounded, size: 18),
              label: const Text('Solicitar recarga',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )),
          ],
        ]),
      ],
    );
  }
}

// ── Recarga pendiente ─────────────────────────────────────
class _RecargaPendientePanel extends StatelessWidget {
  final RecargaStock recarga;
  final VoidCallback onFinalizarRuta;
  final bool         cargando;

  const _RecargaPendientePanel({
    required this.recarga,
    required this.onFinalizarRuta,
    required this.cargando,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColores.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColores.accent.withOpacity(0.3)),
        ),
        child: Row(children: [
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColores.accent),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Solicitud enviada',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColores.accent,
                      fontSize:   13)),
              const Text('Esperando respuesta del administrador…',
                  style: TextStyle(fontSize: 11, color: AppColores.textSecond)),
              // ✅ Mostrar contador con la recarga pendiente incluida
              Text(
                'Recarga ${recarga.recargasUsadas}/${recarga.recargasMax}',
                style: const TextStyle(
                    fontSize:   10,
                    color:      AppColores.textSecond,
                    fontWeight: FontWeight.w500),
              ),
            ],
          )),
        ]),
      ),
      const SizedBox(height: 10),
      // ✅ Mensaje aclaratorio del error
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        AppColores.warning.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColores.warning.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColores.warning, size: 14),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'Ya tienes una solicitud activa. '
            'Espera a que el admin responda antes de solicitar otra.',
            style: TextStyle(fontSize: 11, color: AppColores.textSecond),
          )),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: cargando ? null : onFinalizarRuta,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColores.danger,
            side: BorderSide(color: AppColores.danger.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon:  const Icon(Icons.flag_rounded, size: 16),
          label: const Text('Finalizar de todas formas'),
        ),
      ),
    ],
  );
}

// ── Recarga aceptada ──────────────────────────────────────
class _RecargaAceptadaPanel extends StatelessWidget {
  final RecargaStock  recarga;
  final VoidCallback? onCompletarRecarga;
  final bool          cargando;

  const _RecargaAceptadaPanel({
    required this.recarga,
    required this.onCompletarRecarga,
    required this.cargando,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColores.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColores.success.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColores.success, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('¡Recarga aprobada!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColores.success,
                      fontSize:   14))),
            ]),
            const SizedBox(height: 8),
            if (recarga.direccionRecarga != null) ...[
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColores.textSecond),
                const SizedBox(width: 6),
                Expanded(child: Text(recarga.direccionRecarga!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond))),
              ]),
              const SizedBox(height: 4),
            ],
            if (recarga.notasAdmin != null)
              Row(children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: AppColores.textSecond),
                const SizedBox(width: 6),
                Expanded(child: Text(recarga.notasAdmin!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColores.textSecond))),
              ]),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width:  double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: cargando ? null : onCompletarRecarga,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: cargando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.inventory_2_rounded, size: 20),
          label: const Text('Confirmé que recibí el stock',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    ],
  );
}

// ── Indicador de recargas ─────────────────────────────────
class _IndicadorRecargas extends StatelessWidget {
  final int usadas;
  final int max;
  const _IndicadorRecargas({required this.usadas, required this.max});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('Recargas: ',
          style: TextStyle(fontSize: 11, color: AppColores.textSecond)),
      ...List.generate(max, (i) {
        final usado = i < usadas;
        return Container(
          width: 14, height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: usado ? AppColores.warning : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(
                color: usado ? AppColores.warning : Colors.grey.shade300),
          ),
          child: usado
              ? const Icon(Icons.close, size: 8, color: Colors.white)
              : null,
        );
      }),
      Text(' $usadas/$max',
          style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.bold,
              color: usadas >= max
                  ? AppColores.danger : AppColores.textSecond)),
    ],
  );
}

// ── Punto inicio card ─────────────────────────────────────
class _PuntoInicioCard extends StatelessWidget {
  final EmpresaRuta empresa;
  final bool        puedeIniciar;
  const _PuntoInicioCard({required this.empresa, required this.puedeIniciar});

  @override
  Widget build(BuildContext context) {
    final color = puedeIniciar ? AppColores.primary : AppColores.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            puedeIniciar ? Icons.flag_rounded : Icons.location_off_rounded,
            color: color, size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PUNTO DE INICIO ÓPTIMO',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: color, letterSpacing: 0.6)),
            Text(empresa.nombre,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary)),
            if (empresa.direccion != null)
              Text(empresa.direccion!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColores.textSecond),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        Icon(Icons.chevron_right_rounded, color: color, size: 16),
      ]),
    );
  }
}

class _AvisoEstado extends StatelessWidget {
  final String texto;
  final bool   calculando;
  const _AvisoEstado({required this.texto, required this.calculando});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:        AppColores.warning.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColores.warning.withOpacity(0.3)),
    ),
    child: Row(children: [
      calculando
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColores.warning))
          : const Icon(Icons.directions_walk_rounded,
              color: AppColores.warning, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(texto,
          style: const TextStyle(fontSize: 12, color: AppColores.textSecond))),
    ]),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColores.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:        AppColores.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.navigation_rounded,
              color: AppColores.primary, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SIGUIENTE PARADA',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: AppColores.primary, letterSpacing: 0.6)),
            Text(pendiente.nombre,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary)),
          ],
        )),
        _BadgePill(texto: 'En ruta'),
      ]),
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
      color:        AppColores.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(texto,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold,
            color: AppColores.primary)),
  );
}