import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/ventas_provider.dart';
import '../providers/reporte_provider.dart';
import '../providers/pedidos_vendedor_provider.dart';
import '../../../shared/models/venta_model.dart';

// ── Helpers de fecha ──────────────────────────────────────
String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

String _hoy() => _fmt(DateTime.now());
String _ayer() => _fmt(DateTime.now().subtract(const Duration(days: 1)));
String _mesDesde() =>
    _fmt(DateTime(DateTime.now().year, DateTime.now().month, 1));

// ── Provider rango — por defecto HOY ─────────────────────
final rangoHistorialProvider = StateProvider<RangoFechas>((ref) {
  final h = _hoy();
  return RangoFechas(desde: h, hasta: h);
});

// ══════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════
class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _hoy();
      final rangoHoy = RangoFechas(desde: h, hasta: h);
      // Resetear rango a hoy
      ref.read(rangoHistorialProvider.notifier).state = rangoHoy;
      // Forzar recarga aunque el rango sea el mismo
      ref.invalidate(historialPorFechasProvider(rangoHoy));
      ref.invalidate(resumenPorFechasProvider(rangoHoy));
      ref.invalidate(pedidosHistorialProvider(rangoHoy));
    });
  }

  @override
  Widget build(BuildContext context) {
    final rango       = ref.watch(rangoHistorialProvider);
    final ventasAsync = ref.watch(historialPorFechasProvider(rango));
    final resumenAsync = ref.watch(resumenPorFechasProvider(rango));
    final pedidosAsync = ref.watch(pedidosHistorialProvider(rango));

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Historial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(historialPorFechasProvider(rango));
              ref.invalidate(resumenPorFechasProvider(rango));
              ref.invalidate(pedidosHistorialProvider(rango));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Selector ─────────────────────────────────
          _SelectorFechas(
            rango: rango,
            onChange: (r) {
              ref.read(rangoHistorialProvider.notifier).state = r;
            },
          ),

          // ── Resumen ───────────────────────────────────
          resumenAsync.maybeWhen(
            data: (r) => _ResumenCompacto(resumen: r),
            orElse: () => const SizedBox.shrink(),
          ),

          // ── Lista ventas + pedidos ────────────────────
          Expanded(
            child: _ListaMixta(
              ventasAsync:  ventasAsync,
              pedidosAsync: pedidosAsync,
              rango:        rango,
              onRefresh: () {
                ref.invalidate(historialPorFechasProvider(rango));
                ref.invalidate(resumenPorFechasProvider(rango));
                ref.invalidate(pedidosHistorialProvider(rango));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LISTA MIXTA — ventas + pedidos
// ══════════════════════════════════════════════════════════
class _ListaMixta extends StatelessWidget {
  final AsyncValue<List<VentaModel>>      ventasAsync;
  final AsyncValue<List<PedidoVendedor>>  pedidosAsync;
  final RangoFechas                       rango;
  final VoidCallback                      onRefresh;

  const _ListaMixta({
    required this.ventasAsync,
    required this.pedidosAsync,
    required this.rango,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final ventas  = ventasAsync.asData?.value  ?? [];
    final pedidos = pedidosAsync.asData?.value ?? [];
    final cargando = ventasAsync.isLoading || pedidosAsync.isLoading;
    final hayError = ventasAsync.hasError;

    if (cargando) return const Center(child: CircularProgressIndicator());
    if (hayError)  return _ErrorVista(onReintentar: onRefresh);

    final items = <_ItemHistorial>[];
    for (final v in ventas) {
      items.add(_ItemHistorial(
        fecha:  DateTime.tryParse(v.fechaVenta) ?? DateTime.now(),
        venta:  v,
        pedido: null,
      ));
    }
    for (final p in pedidos) {
      items.add(_ItemHistorial(
        fecha:  DateTime.tryParse(p.aceptadoEn ?? p.creadoEn) ?? DateTime.now(),
        venta:  null,
        pedido: p,
      ));
    }
    items.sort((a, b) => b.fecha.compareTo(a.fecha));

    if (items.isEmpty) return _EmptyVista(rango: rango);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount:   items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          if (item.venta != null) return _VentaCard(venta: item.venta!);
          return _PedidoCard(pedido: item.pedido!);
        },
      ),
    );
  }
}

class _ItemHistorial {
  final DateTime        fecha;
  final VentaModel?     venta;
  final PedidoVendedor? pedido;
  const _ItemHistorial({
    required this.fecha,
    required this.venta,
    required this.pedido,
  });
}

// ══════════════════════════════════════════════════════════
//  SELECTOR DE FECHAS
// ══════════════════════════════════════════════════════════
class _SelectorFechas extends StatelessWidget {
  final RangoFechas            rango;
  final Function(RangoFechas)  onChange;
  const _SelectorFechas({required this.rango, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final accesos = [
      _Acceso('Hoy',      _hoy(),      _hoy()),
      _Acceso('Ayer',     _ayer(),     _ayer()),
      _Acceso('Este mes', _mesDesde(), _hoy()),
    ];

    return Container(
      color: AppColores.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ...accesos.map((a) {
              final activo = rango.desde == a.desde && rango.hasta == a.hasta;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      onChange(RangoFechas(desde: a.desde, hasta: a.hasta)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: activo
                          ? Colors.white
                          : Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a.label,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color: activo ? AppColores.primary : Colors.white,
                        )),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _abrirCalendario(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: const Row(children: [
                  Icon(Icons.calendar_today,
                      color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Fecha',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.date_range,
                color: Colors.white60, size: 14),
            const SizedBox(width: 8),
            Text(_labelRango(),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  String _labelRango() {
    if (rango.desde == rango.hasta) return _legible(rango.desde);
    return '${_legible(rango.desde)}  →  ${_legible(rango.hasta)}';
  }

  String _legible(String f) {
    try {
      final dt    = DateTime.parse(f);
      const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${meses[dt.month]} ${dt.year}';
    } catch (_) { return f; }
  }

  Future<void> _abrirCalendario(BuildContext context) async {
    final result = await showDateRangePicker(
      context:     context,
      firstDate:   DateTime(2024),
      lastDate:    DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(rango.desde),
        end:   DateTime.parse(rango.hasta),
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColores.primary,
            onPrimary: Colors.white,
            surface:   Colors.white,
            onSurface: AppColores.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      onChange(RangoFechas(
          desde: _fmt(result.start), hasta: _fmt(result.end)));
    }
  }
}

class _Acceso {
  final String label, desde, hasta;
  const _Acceso(this.label, this.desde, this.hasta);
}

// ══════════════════════════════════════════════════════════
//  RESUMEN COMPACTO
// ══════════════════════════════════════════════════════════
class _ResumenCompacto extends StatelessWidget {
  final ResumenDia resumen;
  const _ResumenCompacto({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat('${resumen.totalVentas}', 'Ventas',   AppColores.primary),
            _Div(),
            _Stat('\$${resumen.totalContado.toStringAsFixed(2)}',
                'Contado', AppColores.success),
            _Div(),
            _Stat('\$${resumen.totalFiado.toStringAsFixed(2)}',
                'Fiado', AppColores.warning),
            _Div(),
            _Stat('\$${resumen.totalVendido.toStringAsFixed(2)}',
                'Total', AppColores.primary),
          ],
        ),
        if (resumen.pedidosEntregados > 0) ...[
          Divider(height: 16, color: Colors.grey.withOpacity(0.15)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('${resumen.pedidosEntregados}',
                  'Pedidos', AppColores.accent),
              _Div(),
              _Stat('\$${resumen.totalPedidosContado.toStringAsFixed(2)}',
                  'Cobrado', AppColores.success),
              _Div(),
              _Stat('\$${resumen.totalPedidosTransf.toStringAsFixed(2)}',
                  'Transf.', AppColores.textSecond),
              _Div(),
              _Stat('\$${resumen.dineroEnMano.toStringAsFixed(2)}',
                  'En mano', AppColores.primary),
            ],
          ),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String valor, label;
  final Color  color;
  const _Stat(this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(valor, style: TextStyle(fontSize: 14,
        fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(
        fontSize: 10, color: AppColores.textSecond)),
  ]);
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 28, width: 1, color: Colors.grey.shade200);
}

// ══════════════════════════════════════════════════════════
//  CARD VENTA
// ══════════════════════════════════════════════════════════
class _VentaCard extends StatelessWidget {
  final VentaModel venta;
  const _VentaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final esCredito = venta.tipo == 'credito';
    final cfg = _config(esCredito, venta.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(
            color: cfg.colorBorde, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        cfg.colorFondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(cfg.icono,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(venta.cliente ?? 'Venta al contado',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        color: AppColores.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 11, color: AppColores.textSecond),
                  const SizedBox(width: 3),
                  Text(_formatFecha(venta.fechaVenta),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColores.textSecond)),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text('\$${venta.montoTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: AppColores.textPrimary)),
              if (esCredito && venta.estado == 'parcial')
                Text('Debe \$${venta.montoPendiente.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11,
                        color: AppColores.warning,
                        fontWeight: FontWeight.w500)),
              if (esCredito && venta.estado == 'pagado')
                const Text('Pagado ✓',
                    style: TextStyle(fontSize: 11,
                        color: AppColores.success,
                        fontWeight: FontWeight.w500)),
              if (esCredito && venta.estado == 'pendiente')
                Text('Debe \$${venta.montoPendiente.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11,
                        color: AppColores.danger,
                        fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          Row(children: [
            _Badge(
              label: esCredito ? 'FIADO' : 'CONTADO',
              color: esCredito ? AppColores.warning : AppColores.success,
            ),
            const SizedBox(width: 6),
            if (esCredito)
              _Badge(label: cfg.labelEstado, color: cfg.colorEstado),
            const Spacer(),
            Text(cfg.mensajeAyuda,
                style: TextStyle(fontSize: 10,
                    color: cfg.colorEstado,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }

  _Cfg _config(bool esCredito, String estado) {
    if (!esCredito) return _Cfg(
      icono: '💵', colorBorde: AppColores.success,
      colorFondo: AppColores.success.withOpacity(0.10),
      colorEstado: AppColores.success,
      labelEstado: 'PAGADO', mensajeAyuda: 'Cobrado al momento',
    );
    switch (estado) {
      case 'pagado': return _Cfg(
        icono: '✅', colorBorde: AppColores.success,
        colorFondo: AppColores.success.withOpacity(0.10),
        colorEstado: AppColores.success,
        labelEstado: 'PAGADO', mensajeAyuda: 'Deuda saldada',
      );
      case 'parcial': return _Cfg(
        icono: '⏳', colorBorde: AppColores.warning,
        colorFondo: AppColores.warning.withOpacity(0.10),
        colorEstado: AppColores.warning,
        labelEstado: 'PARCIAL', mensajeAyuda: 'Pago parcial',
      );
      default: return _Cfg(
        icono: '📋', colorBorde: AppColores.danger,
        colorFondo: AppColores.danger.withOpacity(0.08),
        colorEstado: AppColores.danger,
        labelEstado: 'PENDIENTE', mensajeAyuda: 'Sin pago aún',
      );
    }
  }

  String _formatFecha(String f) {
    try {
      final dt    = DateTime.parse(f).toLocal();
      const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${meses[dt.month]} ${dt.year} — '
             '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return f; }
  }
}

class _Cfg {
  final String icono, labelEstado, mensajeAyuda;
  final Color  colorBorde, colorFondo, colorEstado;
  const _Cfg({
    required this.icono, required this.colorBorde,
    required this.colorFondo, required this.colorEstado,
    required this.labelEstado, required this.mensajeAyuda,
  });
}

// ══════════════════════════════════════════════════════════
//  CARD PEDIDO
// ══════════════════════════════════════════════════════════
class _PedidoCard extends StatelessWidget {
  final PedidoVendedor pedido;
  const _PedidoCard({required this.pedido});

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'entregado': return AppColores.success;
      case 'en_camino': return AppColores.primary;
      case 'cancelado': return AppColores.danger;
      default:          return AppColores.accent;
    }
  }

  String get _iconoEstado {
    switch (pedido.estado) {
      case 'entregado': return '✅';
      case 'en_camino': return '🚚';
      case 'cancelado': return '❌';
      default:          return '🛵';
    }
  }

  @override
  Widget build(BuildContext context) {
    final esCobrado = pedido.tipoPago == 'contraentrega';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(
            color: AppColores.primary, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_iconoEstado,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.clienteNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        color: AppColores.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 11, color: AppColores.textSecond),
                  const SizedBox(width: 3),
                  Text(_formatFecha(pedido.aceptadoEn ?? pedido.creadoEn),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColores.textSecond)),
                ]),
              ],
            )),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: AppColores.textPrimary)),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          Row(children: [
            _Badge(label: 'PEDIDO', color: AppColores.primary),
            const SizedBox(width: 6),
            _Badge(
              label: esCobrado ? 'CONTRAENTREGA' : 'TRANSFERENCIA',
              color: esCobrado ? AppColores.success : AppColores.primary,
            ),
            const Spacer(),
            Text(
              esCobrado ? 'Cobrado al entregar' : 'Ya fue pagado',
              style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: esCobrado
                      ? AppColores.success : AppColores.primary),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatFecha(String f) {
    try {
      final dt    = DateTime.parse(f).toLocal();
      const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${meses[dt.month]} ${dt.year} — '
             '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return f; }
  }
}

// ══════════════════════════════════════════════════════════
//  BADGE
// ══════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );
}

// ══════════════════════════════════════════════════════════
//  EMPTY Y ERROR
// ══════════════════════════════════════════════════════════
class _EmptyVista extends StatelessWidget {
  final RangoFechas rango;
  const _EmptyVista({required this.rango});

  @override
  Widget build(BuildContext context) {
    final h = _hoy();
    final a = _ayer();
    final m = _mesDesde();

    String msg;
    if (rango.desde == h && rango.hasta == h)
      msg = 'Aún no hay actividad hoy.\nPresiona + para registrar la primera venta.';
    else if (rango.desde == a && rango.hasta == a)
      msg = 'No hubo actividad ayer.';
    else if (rango.desde == m && rango.hasta == h)
      msg = 'No hay actividad este mes.';
    else
      msg = 'No hay actividad en el rango seleccionado.';

    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🫓', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColores.textSecond, fontSize: 14)),
        ],
      ),
    ));
  }
}

class _ErrorVista extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorVista({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.wifi_off,
          color: AppColores.textSecond, size: 40),
      const SizedBox(height: 8),
      const Text('Error cargando historial',
          style: TextStyle(color: AppColores.textSecond)),
      TextButton(
          onPressed: onReintentar,
          child: const Text('Reintentar')),
    ],
  ));
}