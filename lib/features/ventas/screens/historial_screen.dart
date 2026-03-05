import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/ventas_provider.dart';
import '../providers/reporte_provider.dart';
import '../../../shared/models/venta_model.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoSeleccionadoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Historial de Ventas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Selector de periodo
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SelectorPeriodo(
              seleccionado: periodo,
              onChange: (p) =>
                  ref.read(periodoSeleccionadoProvider.notifier).state = p,
            ),
          ),

          // Resumen compacto del periodo
          _ResumenCompacto(periodo: periodo),

          // Lista de ventas
          Expanded(child: _ListaVentas(periodo: periodo)),
        ],
      ),
    );
  }
}

// ── Selector ───────────────────────────────────────────────
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
            blurRadius: 8, offset: const Offset(0, 2),
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
                  child: Text(o['l']!,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                        color: activo
                            ? Colors.white
                            : AppColores.textSecond,
                      )),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Resumen compacto ───────────────────────────────────────
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
                blurRadius: 6, offset: const Offset(0, 2),
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
    required this.valor, required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(valor, style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold, color: color,
      )),
      Text(label, style: const TextStyle(
        fontSize: 11, color: AppColores.textSecond,
      )),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 30, width: 1, color: Colors.grey.shade200,
  );
}

// ── Lista de ventas con fecha y hora ───────────────────────
class _ListaVentas extends ConsumerWidget {
  final String periodo;
  const _ListaVentas({required this.periodo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historialVentasProvider(periodo));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: AppColores.textSecond, size: 40),
            const SizedBox(height: 8),
            const Text('Error cargando ventas'),
            TextButton(
              onPressed: () => ref.invalidate(historialVentasProvider(periodo)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (ventas) => ventas.isEmpty
          ? _Empty(periodo: periodo)
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(historialVentasProvider(periodo)),
              child: ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount:   ventas.length,
                itemBuilder: (ctx, i) => _VentaCard(venta: ventas[i]),
              ),
            ),
    );
  }
}

// ── Card de venta con fecha y hora ─────────────────────────
class _VentaCard extends StatelessWidget {
  final VentaModel venta;
  const _VentaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito = venta.tipo == 'credito';
    final colorTipo = esCredito ? AppColores.warning : AppColores.success;
    final labelTipo = esCredito ? 'FIADO'            : 'CONTADO';
    final fechaHora = _formatearFechaHora(venta.fechaVenta);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Ícono tipo
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        colorTipo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    esCredito ? '📋' : '💵',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venta.cliente ?? 'Venta de contado',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   14,
                        color:      AppColores.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Fecha y hora
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: AppColores.textSecond),
                        const SizedBox(width: 3),
                        Text(
                          fechaHora,
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
                  if (esCredito && venta.montoPendiente > 0)
                    Text(
                      'Debe \$${venta.montoPendiente.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11, color: AppColores.danger,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Badges tipo y estado
          Row(
            children: [
              _Badge(label: labelTipo, color: colorTipo),
              const SizedBox(width: 6),
              if (esCredito)
                _Badge(
                  label: venta.estado.toUpperCase(),
                  color: _colorEstado(venta.estado),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatearFechaHora(String fechaStr) {
    try {
      final dt     = DateTime.parse(fechaStr).toLocal();
      const meses  = ['','Ene','Feb','Mar','Abr','May','Jun',
                      'Jul','Ago','Sep','Oct','Nov','Dic'];
      final hora   = dt.hour.toString().padLeft(2, '0');
      final minuto = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${meses[dt.month]} — $hora:$minuto';
    } catch (_) {
      return fechaStr;
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'pagado':  return AppColores.success;
      case 'parcial': return AppColores.warning;
      default:        return AppColores.danger;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.bold, color: color,
        )),
  );
}

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
                color: AppColores.textSecond, fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}