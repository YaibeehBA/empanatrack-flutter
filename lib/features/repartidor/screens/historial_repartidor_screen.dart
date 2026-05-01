import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../pedidos/models/pedido_models.dart';

// ── Provider ──────────────────────────────────────────────
class _RangoFechas {
  final String desde, hasta;
  const _RangoFechas({required this.desde, required this.hasta});
  @override bool operator ==(o) =>
      o is _RangoFechas && o.desde == desde && o.hasta == hasta;
  @override int get hashCode => Object.hash(desde, hasta);
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}'
    '-${d.day.toString().padLeft(2,'0')}';
String _hoy()  => _fmt(DateTime.now());
String _ayer() => _fmt(DateTime.now().subtract(const Duration(days: 1)));
String _mes()  =>
    _fmt(DateTime(DateTime.now().year, DateTime.now().month, 1));

final _rangoRepartidorProvider =
    StateProvider<_RangoFechas>((ref) {
  final h = _hoy();
  return _RangoFechas(desde: h, hasta: h);
});

class _ResumenRepartidor {
  final int    totalEntregados;
  final double totalMonto;
  final double totalContado;
  final double totalTransf;

  const _ResumenRepartidor({
    required this.totalEntregados,
    required this.totalMonto,
    required this.totalContado,
    required this.totalTransf,
  });

  factory _ResumenRepartidor.fromPedidos(List<PedidoBase> pedidos) {
    final entregados = pedidos
        .where((p) => p.estado == 'entregado').toList();
    return _ResumenRepartidor(
      totalEntregados: entregados.length,
      totalMonto:      entregados.fold(0, (s, p) => s + p.total),
      totalContado:    entregados
          .where((p) => p.tipoPago == 'contraentrega')
          .fold(0, (s, p) => s + p.total),
      totalTransf:     entregados
          .where((p) => p.tipoPago == 'transferencia')
          .fold(0, (s, p) => s + p.total),
    );
  }
}

final _historialRepartidorProvider =
    FutureProvider.family<List<PedidoBase>, _RangoFechas>(
        (ref, rango) async {
  final r = await ApiClient.get(
    '/pedidos/historial-repartidor',
    params: {'desde': rango.desde, 'hasta': rango.hasta},
  );
  return (r.data as List)
      .map((p) => PedidoBase.fromJson(p))
      .toList();
});

// ══════════════════════════════════════════════════════════
//  PANTALLA
// ══════════════════════════════════════════════════════════
class HistorialRepartidorScreen extends ConsumerStatefulWidget {
  const HistorialRepartidorScreen({super.key});

  @override
  ConsumerState<HistorialRepartidorScreen> createState() =>
      _HistorialRepartidorScreenState();
}

class _HistorialRepartidorScreenState
    extends ConsumerState<HistorialRepartidorScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _hoy();
      final rango = _RangoFechas(desde: h, hasta: h);
      ref.read(_rangoRepartidorProvider.notifier).state = rango;
      ref.invalidate(_historialRepartidorProvider(rango));
    });
  }

  @override
  Widget build(BuildContext context) {
    final rango  = ref.watch(_rangoRepartidorProvider);
    final async  = ref.watch(_historialRepartidorProvider(rango));

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Mis Entregas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_historialRepartidorProvider(rango)),
          ),
        ],
      ),
      body: Column(children: [

        // Selector fechas
        _SelectorFechas(
          rango:    rango,
          onChange: (r) =>
              ref.read(_rangoRepartidorProvider.notifier).state = r,
        ),

        // Resumen
        async.maybeWhen(
          data: (pedidos) => _ResumenCompacto(
              resumen: _ResumenRepartidor.fromPedidos(pedidos)),
          orElse: () => const SizedBox.shrink(),
        ),

        // Lista
        Expanded(child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: TextButton(
              onPressed: () =>
                  ref.invalidate(_historialRepartidorProvider(rango)),
              child: const Text('Reintentar'))),
          data: (pedidos) {
            if (pedidos.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📭', style: TextStyle(fontSize: 52)),
                    SizedBox(height: 14),
                    Text('Sin entregas en este periodo',
                        style: TextStyle(
                            color:    AppColores.textSecond,
                            fontSize: 14)),
                  ],
                ),
              ));
            }
            final ordenados = List<PedidoBase>.from(pedidos)
              ..sort((a, b) {
                final fa = DateTime.tryParse(
                    a.aceptadoEn ?? a.creadoEn) ?? DateTime.now();
                final fb = DateTime.tryParse(
                    b.aceptadoEn ?? b.creadoEn) ?? DateTime.now();
                return fb.compareTo(fa);
              });
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(_historialRepartidorProvider(rango)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount:   ordenados.length,
                itemBuilder: (_, i) =>
                    _EntregaCard(pedido: ordenados[i]),
              ),
            );
          },
        )),
      ]),
    );
  }
}

// ── Selector fechas (mismo estilo que vendedor) ───────────
class _SelectorFechas extends StatelessWidget {
  final _RangoFechas           rango;
  final Function(_RangoFechas) onChange;
  const _SelectorFechas({
      required this.rango, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final accesos = [
      _A('Hoy',      _hoy(),  _hoy()),
      _A('Ayer',     _ayer(), _ayer()),
      _A('Este mes', _mes(),  _hoy()),
    ];
    return Container(
      color: AppColores.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ...accesos.map((a) {
              final activo =
                  rango.desde == a.d && rango.hasta == a.h;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChange(
                      _RangoFechas(desde: a.d, hasta: a.h)),
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
                    child: Text(a.l,
                        style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.bold,
                            color: activo
                                ? AppColores.primary : Colors.white)),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () async {
                final r = await showDateRangePicker(
                  context:   context,
                  firstDate: DateTime(2024),
                  lastDate:  DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: DateTime.parse(rango.desde),
                    end:   DateTime.parse(rango.hasta),
                  ),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary:   AppColores.primary,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (r != null) {
                  onChange(_RangoFechas(
                      desde: _fmt(r.start), hasta: _fmt(r.end)));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Row(children: [
                  Icon(Icons.calendar_today,
                      color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Fecha',
                      style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _A {
  final String l, d, h;
  const _A(this.l, this.d, this.h);
}

// ── Resumen compacto ──────────────────────────────────────
class _ResumenCompacto extends StatelessWidget {
  final _ResumenRepartidor resumen;
  const _ResumenCompacto({required this.resumen});

  @override
  Widget build(BuildContext context) => Container(
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
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Stat('${resumen.totalEntregados}',
            'Entregas',   AppColores.primary),
        _Div(),
        _Stat('\$${resumen.totalContado.toStringAsFixed(2)}',
            'Cobrado',    AppColores.success),
        _Div(),
        _Stat('\$${resumen.totalTransf.toStringAsFixed(2)}',
            'Transf.',    AppColores.textSecond),
        _Div(),
        _Stat('\$${resumen.totalMonto.toStringAsFixed(2)}',
            'Total',      AppColores.primary),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String valor, label;
  final Color  color;
  const _Stat(this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(valor, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(
        fontSize: 10, color: AppColores.textSecond)),
  ]);
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 28, width: 1, color: Colors.grey.shade200);
}

// ── Card entrega ──────────────────────────────────────────
class _EntregaCard extends StatelessWidget {
  final PedidoBase pedido;
  const _EntregaCard({required this.pedido});

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'entregado': return AppColores.success;
      case 'en_camino': return AppColores.accent;
      case 'cancelado': return AppColores.danger;
      default:          return AppColores.warning;
    }
  }

  String get _icono {
    switch (pedido.estado) {
      case 'entregado': return '✅';
      case 'en_camino': return '🛵';
      case 'cancelado': return '❌';
      default:          return '📦';
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
            color: _colorEstado, width: 4)),
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
                color:        _colorEstado.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_icono,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.clienteNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   14,
                        color:      AppColores.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (pedido.direccionEntrega != null)
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 10,
                        color: AppColores.textSecond),
                    const SizedBox(width: 3),
                    Expanded(child: Text(
                        pedido.direccionEntrega!,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColores.textSecond),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                  ]),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 10,
                      color: AppColores.textSecond),
                  const SizedBox(width: 3),
                  Text(_formatFecha(
                          pedido.aceptadoEn ?? pedido.creadoEn),
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColores.textSecond)),
                ]),
              ],
            )),
            Text('\$${pedido.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   16,
                    color:      AppColores.textPrimary)),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          Row(children: [
            _Badge(
              label: pedido.estado.toUpperCase(),
              color: _colorEstado,
            ),
            const SizedBox(width: 6),
            _Badge(
              label: esCobrado
                  ? 'CONTRAENTREGA' : 'TRANSFERENCIA',
              color: esCobrado
                  ? AppColores.success : AppColores.primary,
            ),
            const Spacer(),
            Text(
              esCobrado
                  ? 'Cobrar al entregar'
                  : 'Ya fue pagado',
              style: TextStyle(
                  fontSize:   10,
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