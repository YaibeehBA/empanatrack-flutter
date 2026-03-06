// lib/features/ventas/screens/historial_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/ventas_provider.dart';
import '../providers/reporte_provider.dart';
import '../../../shared/models/venta_model.dart';
import 'vendedor_shell.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoSeleccionadoProvider);

    // Refrescar cuando se activa el tab de historial
    ref.listen<int>(tabActivoProvider, (prev, next) {
      if (next == 2 && prev != 2) {
        ref.invalidate(historialVentasProvider(periodo));
        ref.invalidate(resumenDiaProvider(periodo));
      }
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Historial de Ventas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Selector de periodo
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SelectorPeriodo(
              seleccionado: periodo,
              onChange: (p) {
                ref.read(periodoSeleccionadoProvider.notifier).state = p;
                ref.invalidate(historialVentasProvider(p));
                ref.invalidate(resumenDiaProvider(p));
              },
            ),
          ),

          // Resumen compacto
          _ResumenCompacto(periodo: periodo),

          // Lista de ventas
          Expanded(
            child: _ListaVentas(periodo: periodo),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTOR DE PERIODO
// ══════════════════════════════════════════════════════════
class _SelectorPeriodo extends StatelessWidget {
  final String           seleccionado;
  final Function(String) onChange;
  const _SelectorPeriodo({
    required this.seleccionado, required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final ops = [
      {'v': 'hoy',    'l': 'Hoy'},
      {'v': 'ayer',   'l': 'Ayer'},
      {'v': 'semana', 'l': 'Semana'},
      {'v': 'mes',    'l': 'Mes'},
    ];
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ops.map((o) {
          final activo = seleccionado == o['v'];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(o['v']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:  const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color:        activo
                      ? AppColores.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    o['l']!,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.bold,
                      color: activo
                          ? Colors.white
                          : AppColores.textSecond,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  RESUMEN COMPACTO
// ══════════════════════════════════════════════════════════
class _ResumenCompacto extends ConsumerWidget {
  final String periodo;
  const _ResumenCompacto({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(resumenDiaProvider(periodo));
    return async.maybeWhen(
      data: (r) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                valor: '${r.totalVentas}',
                label: 'Ventas',
                color: AppColores.accent,
              ),
              _Divider(),
              _Stat(
                valor: '\$${r.totalContado.toStringAsFixed(2)}',
                label: 'Contado',
                color: AppColores.success,
              ),
              _Divider(),
              _Stat(
                valor: '\$${r.totalFiado.toStringAsFixed(2)}',
                label: 'Fiado',
                color: AppColores.warning,
              ),
              _Divider(),
              _Stat(
                valor: '\$${r.totalVendido.toStringAsFixed(2)}',
                label: 'Total',
                color: AppColores.primary,
              ),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Stat extends StatelessWidget {
  final String valor;
  final String label;
  final Color  color;
  const _Stat({
    required this.valor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.bold,
            color:      color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color:    AppColores.textSecond,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, width: 1,
      color:  Colors.grey.shade200,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LISTA DE VENTAS
// ══════════════════════════════════════════════════════════
class _ListaVentas extends ConsumerWidget {
  final String periodo;
  const _ListaVentas({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historialVentasProvider(periodo));
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off,
                color: AppColores.textSecond, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Error cargando ventas',
              style: TextStyle(color: AppColores.textSecond),
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(historialVentasProvider(periodo)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (ventas) => ventas.isEmpty
          ? _Empty(periodo: periodo)
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(historialVentasProvider(periodo));
                ref.invalidate(resumenDiaProvider(periodo));
              },
              child: ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount:   ventas.length,
                itemBuilder: (ctx, i) => _VentaCard(venta: ventas[i]),
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  VENTA CARD CON FECHA Y HORA
// ══════════════════════════════════════════════════════════
class _VentaCard extends StatelessWidget {
  final VentaModel venta;
  const _VentaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito = venta.tipo == 'credito';
    final estado    = venta.estado;
    final config    = _configEstado(esCredito, estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            Row(
              children: [
                // Ícono
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          fontSize:   11,
                          color:      AppColores.warning,
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
                    if (esCredito && estado == 'pendiente')
                      Text(
                        'Debe \$${venta.montoPendiente.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize:   11,
                          color:      AppColores.danger,
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

            // Badges
            Row(
              children: [
                _Badge(
                  label: esCredito ? 'FIADO' : 'CONTADO',
                  color: esCredito
                      ? AppColores.warning
                      : AppColores.success,
                ),
                const SizedBox(width: 6),
                if (esCredito)
                  _Badge(
                    label: config.labelEstado,
                    color: config.colorEstado,
                  ),
                const Spacer(),
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

  _ConfigVenta _configEstado(bool esCredito, String estado) {
    if (!esCredito) {
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
      default:
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

// ══════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════
class _Empty extends StatelessWidget {
  final String periodo;
  const _Empty({required this.periodo});

  @override
  Widget build(BuildContext context) {
    final msgs = {
      'hoy':    'Aún no hay ventas hoy.\nPresiona + para registrar la primera.',
      'ayer':   'No hubo ventas ayer.',
      'semana': 'No hay ventas esta semana.',
      'mes':    'No hay ventas este mes.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🫓', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(
              msgs[periodo] ?? 'Sin ventas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:    AppColores.textSecond,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}