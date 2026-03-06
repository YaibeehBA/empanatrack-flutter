import 'package:flutter/material.dart';
import '../../core/constants/colores.dart';
import '../models/venta_model.dart';

class VentaItem extends StatelessWidget {
  final VentaModel venta;
  const VentaItem({super.key, required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito  = venta.tipo == 'credito';
    final estado     = venta.estado; // pendiente | parcial | pagado
    final config     = _configEstado(esCredito, estado);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        // Borde izquierdo de color según estado
        border: Border(
          left: BorderSide(color: config.colorBorde, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [

            // ── Fila principal ───────────────────────────
            Row(
              children: [
                // Ícono con fondo de color
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color:        config.colorFondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      config.icono,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nombre y fecha
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venta.cliente ?? 'Venta al contado',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   14,
                          color:      AppColores.textPrimary,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 11,
                              color: AppColores.textSecond),
                          const SizedBox(width: 3),
                          Text(
                            _formatearFecha(venta.fechaVenta),
                            style: const TextStyle(
                              fontSize: 11,
                              color:    AppColores.textSecond,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Monto
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${venta.montoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   16,
                        color:      AppColores.textPrimary,
                      ),
                    ),
                    if (esCredito && estado == 'parcial')
                      Text(
                        'Debe \$${venta.montoPendiente.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color:    AppColores.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (esCredito && estado == 'pagado')
                      const Text(
                        'Pagado ✓',
                        style: TextStyle(
                          fontSize:   11,
                          color:      AppColores.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 8),

            // ── Badges de estado ─────────────────────────
            Row(
              children: [
                // Badge tipo (contado / fiado)
                _Badge(
                  label: esCredito ? 'FIADO' : 'CONTADO',
                  color: esCredito
                      ? AppColores.warning
                      : AppColores.success,
                ),
                const SizedBox(width: 6),

                // Badge estado (solo si es crédito)
                if (esCredito)
                  _Badge(
                    label: config.labelEstado,
                    color: config.colorEstado,
                  ),

                const Spacer(),

                // Texto de ayuda visual
                Text(
                  config.mensajeAyuda,
                  style: TextStyle(
                    fontSize:   10,
                    color:      config.colorEstado,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Configuración visual según estado ─────────────────
  _ConfigVenta _configEstado(bool esCredito, String estado) {
    if (!esCredito) {
      // Contado — siempre verde
      return _ConfigVenta(
        icono:        '💵',
        colorBorde:   AppColores.success,
        colorFondo:   AppColores.success.withOpacity(0.10),
        colorEstado:  AppColores.success,
        labelEstado:  'PAGADO',
        mensajeAyuda: 'Cobrado al momento',
      );
    }

    switch (estado) {
      case 'pagado':
        return _ConfigVenta(
          icono:        '✅',
          colorBorde:   AppColores.success,
          colorFondo:   AppColores.success.withOpacity(0.10),
          colorEstado:  AppColores.success,
          labelEstado:  'PAGADO',
          mensajeAyuda: 'Deuda saldada',
        );
      case 'parcial':
        return _ConfigVenta(
          icono:        '⏳',
          colorBorde:   AppColores.warning,
          colorFondo:   AppColores.warning.withOpacity(0.10),
          colorEstado:  AppColores.warning,
          labelEstado:  'PARCIAL',
          mensajeAyuda: 'Pago parcial recibido',
        );
      default: // pendiente
        return _ConfigVenta(
          icono:        '📋',
          colorBorde:   AppColores.danger,
          colorFondo:   AppColores.danger.withOpacity(0.08),
          colorEstado:  AppColores.danger,
          labelEstado:  'PENDIENTE',
          mensajeAyuda: 'Sin pago aún',
        );
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      final dt     = DateTime.parse(fechaStr).toLocal();
      const meses  = ['','Ene','Feb','Mar','Abr','May',
                      'Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      final hora   = dt.hour.toString().padLeft(2, '0');
      final minuto = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${meses[dt.month]} — $hora:$minuto';
    } catch (_) {
      return fechaStr;
    }
  }
}

// ── Modelo de configuración visual ────────────────────────
class _ConfigVenta {
  final String icono;
  final Color  colorBorde;
  final Color  colorFondo;
  final Color  colorEstado;
  final String labelEstado;
  final String mensajeAyuda;

  const _ConfigVenta({
    required this.icono,
    required this.colorBorde,
    required this.colorFondo,
    required this.colorEstado,
    required this.labelEstado,
    required this.mensajeAyuda,
  });
}

// ── Badge reutilizable ─────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.bold,
          color:      color,
        ),
      ),
    );
  }
}