// lib/features/clientes/screens/mi_cuenta_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notificaciones_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/movimiento_model.dart';

// ══════════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════════
final miSaldoProvider = FutureProvider.autoDispose<double>((ref) async {
  final clienteId = await _obtenerClienteId();
  if (clienteId == null) return 0.0;
  final response = await ApiClient.get('/clientes/$clienteId/saldo');
  return (response.data['saldo_actual'] as num).toDouble();
});

Future<String?> _obtenerClienteId() async {
  try {
    final response = await ApiClient.get('/clientes/mi-perfil');
    return response.data['id'].toString();
  } catch (_) {
    return null;
  }
}

// ══════════════════════════════════════════════════════════
//  MODELO DE PÁGINA DE HISTORIAL
// ══════════════════════════════════════════════════════════
class _PaginaHistorial {
  final List<MovimientoModel> datos;
  final int  pagina;
  final int  total;
  final bool tieneMas;

  const _PaginaHistorial({
    required this.datos,
    required this.pagina,
    required this.total,
    required this.tieneMas,
  });
}

// ══════════════════════════════════════════════════════════
//  NOTIFIER — historial paginado
// ══════════════════════════════════════════════════════════
class HistorialPaginadoNotifier
    extends StateNotifier<AsyncValue<List<MovimientoModel>>> {

  HistorialPaginadoNotifier(this._clienteId)
      : super(const AsyncValue.loading()) {
    _cargarPagina(1);
  }

  final String _clienteId;
  int  _paginaActual = 1;
  bool _tieneMas     = false;
  bool _cargandoMas  = false;
  int  _total        = 0;

  bool get tieneMas    => _tieneMas;
  bool get cargandoMas => _cargandoMas;
  int  get total       => _total;

  Future<void> _cargarPagina(int pagina) async {
    try {
      final r = await ApiClient.get(
        '/clientes/$_clienteId/historial',
        params: {'pagina': pagina, 'por_pagina': 10},
      );

      final data = r.data as Map<String, dynamic>;
      final nuevos = (data['datos'] as List)
          .map((m) => MovimientoModel.fromJson(m))
          .toList();

      _paginaActual = data['pagina']    as int;
      _total        = data['total']     as int;
      _tieneMas     = data['tiene_mas'] as bool;

      if (pagina == 1) {
        // Primera carga o refresco
        if (mounted) state = AsyncValue.data(nuevos);
      } else {
        // Cargar más — agregar al final
        state.whenData((existentes) {
          if (mounted) {
            state = AsyncValue.data([...existentes, ...nuevos]);
          }
        });
      }
    } catch (e, st) {
      if (pagina == 1 && mounted) {
        state = AsyncValue.error(e, st);
      }
      // Si falla "cargar más", no borramos lo que ya había
    }
  }

  Future<void> cargarMas() async {
    if (!_tieneMas || _cargandoMas) return;
    _cargandoMas = true;
    await _cargarPagina(_paginaActual + 1);
    _cargandoMas = false;
  }

  Future<void> recargar() async {
    if (mounted) state = const AsyncValue.loading();
    _paginaActual = 1;
    _tieneMas     = false;
    _total        = 0;
    await _cargarPagina(1);
  }
}

// Provider family por clienteId
final historialPaginadoProvider = StateNotifierProvider.autoDispose
    .family<HistorialPaginadoNotifier,
            AsyncValue<List<MovimientoModel>>, String>(
  (ref, clienteId) => HistorialPaginadoNotifier(clienteId),
);

// ══════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════════
class MiCuentaScreen extends ConsumerStatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  ConsumerState<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends ConsumerState<MiCuentaScreen> {

  @override
  void initState() {
    super.initState();
    registrarProviderParaRefrescar(miSaldoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(authProvider).sesion;

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        title: const Text('Mi Cuenta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:    const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _MiCuentaBody(
          nombreCliente: sesion?.nombre ?? ''),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BODY
// ══════════════════════════════════════════════════════════
class _MiCuentaBody extends ConsumerStatefulWidget {
  final String nombreCliente;
  const _MiCuentaBody({required this.nombreCliente});

  @override
  ConsumerState<_MiCuentaBody> createState() => _MiCuentaBodyState();
}

class _MiCuentaBodyState extends ConsumerState<_MiCuentaBody> {

  String? _clienteId;

  @override
  void initState() {
    super.initState();
    _cargarClienteId();
  }

  Future<void> _cargarClienteId() async {
    final id = await _obtenerClienteId();
    if (id != null && mounted) {
      setState(() => _clienteId = id);
      registrarProviderParaRefrescar(
          historialPaginadoProvider(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clienteId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _ContenidoCuenta(
      clienteId:     _clienteId!,
      nombreCliente: widget.nombreCliente,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CONTENIDO PRINCIPAL
// ══════════════════════════════════════════════════════════
class _ContenidoCuenta extends ConsumerWidget {
  final String clienteId;
  final String nombreCliente;

  const _ContenidoCuenta({
    required this.clienteId,
    required this.nombreCliente,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldoAsync     = ref.watch(miSaldoProvider);
    final historialAsync = ref.watch(
        historialPaginadoProvider(clienteId));
    final notifier       = ref.read(
        historialPaginadoProvider(clienteId).notifier);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(miSaldoProvider);
        await notifier.recargar();
      },
      child: ListView(
        children: [

          // ── Header con saldo ──────────────────────────
          _HeaderSaldo(
            nombreCliente: nombreCliente,
            saldoAsync:    saldoAsync,
          ),

          // ── Título sección ────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(children: [
              Text(
                'HISTORIAL DE MOVIMIENTOS',
                style: TextStyle(
                    fontSize:      12,
                    fontWeight:    FontWeight.bold,
                    color:         AppColores.textSecond,
                    letterSpacing: 1.2),
              ),
            ]),
          ),

          // ── Lista de movimientos ──────────────────────
          historialAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child:   CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorHistorial(
              onReintentar: () => notifier.recargar(),
            ),
            data: (movimientos) => movimientos.isEmpty
                ? const _SinMovimientos()
                : _ListaMovimientos(
                    movimientos: movimientos,
                    notifier:    notifier,
                  ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HEADER SALDO
// ══════════════════════════════════════════════════════════
class _HeaderSaldo extends StatelessWidget {
  final String                nombreCliente;
  final AsyncValue<double>    saldoAsync;

  const _HeaderSaldo({
    required this.nombreCliente,
    required this.saldoAsync,
  });

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.symmetric(
        horizontal: 24, vertical: 32),
    color:   AppColores.primary,
    child: Column(children: [
      CircleAvatar(
        radius:          36,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: Text(
          nombreCliente.isNotEmpty
              ? nombreCliente[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize:   30,
              fontWeight: FontWeight.bold,
              color:      Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      Text(nombreCliente,
          style: const TextStyle(
              color:      Colors.white,
              fontSize:   20,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),

      // Card saldo
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Text('Mi deuda actual',
              style: TextStyle(
                  color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          saldoAsync.when(
            loading: () => const CircularProgressIndicator(
                color: Colors.white),
            error: (_, __) => const Text('Error al cargar',
                style: TextStyle(color: Colors.white)),
            data: (saldo) => Text(
              '\$${saldo.toStringAsFixed(2)}',
              style: TextStyle(
                  color: saldo > 0
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                  fontSize:   40,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          saldoAsync.maybeWhen(
            data: (saldo) => Text(
              saldo > 0
                  ? 'Tienes deuda pendiente'
                  : '¡Estás al día! 🎉',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ]),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  LISTA DE MOVIMIENTOS CON "CARGAR MÁS"
// ══════════════════════════════════════════════════════════
class _ListaMovimientos extends StatefulWidget {
  final List<MovimientoModel>      movimientos;
  final HistorialPaginadoNotifier  notifier;

  const _ListaMovimientos({
    required this.movimientos,
    required this.notifier,
  });

  @override
  State<_ListaMovimientos> createState() => _ListaMovimientosState();
}

class _ListaMovimientosState extends State<_ListaMovimientos> {

  bool _cargando = false;

  Future<void> _cargarMas() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    await widget.notifier.cargarMas();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [

          // Lista de items
          ...widget.movimientos.map(
              (m) => _MovimientoItem(movimiento: m)),

          // Contador total
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Mostrando ${widget.movimientos.length} '
              'de ${widget.notifier.total} movimientos',
              style: const TextStyle(
                  fontSize: 12,
                  color:    AppColores.textSecond),
            ),
          ),

          // Botón cargar más
          if (widget.notifier.tieneMas) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cargando ? null : _cargarMas,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColores.primary,
                  side: BorderSide(
                      color: AppColores.primary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _cargando
                    ? const SizedBox(
                        width:  16,
                        height: 16,
                        child:  CircularProgressIndicator(
                            strokeWidth: 2,
                            color:       AppColores.primary))
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _cargando ? 'Cargando...' : 'Cargar más',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (widget.movimientos.isNotEmpty) ...[
            // Indicador de que ya se cargó todo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(
                      color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Todo al día',
                        style: TextStyle(
                            fontSize: 11,
                            color:    Colors.grey.shade400)),
                  ),
                  Expanded(child: Divider(
                      color: Colors.grey.shade300)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════
class _SinMovimientos extends StatelessWidget {
  const _SinMovimientos();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Column(children: [
        Text('📋', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('Sin movimientos aún',
            style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.bold,
                color:      AppColores.textPrimary)),
        SizedBox(height: 8),
        Text('Aquí verás tus compras y pagos.',
            style: TextStyle(color: AppColores.textSecond)),
      ]),
    ),
  );
}

class _ErrorHistorial extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorHistorial({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        const Text('No se pudo cargar el historial',
            style: TextStyle(color: AppColores.textSecond)),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: onReintentar,
            child:     const Text('Reintentar')),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  ITEM DE MOVIMIENTO
// ══════════════════════════════════════════════════════════
class _MovimientoItem extends StatelessWidget {
  final MovimientoModel movimiento;
  const _MovimientoItem({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final esVenta = movimiento.esVenta;
    final color   = esVenta ? AppColores.danger  : AppColores.success;
    final icono   = esVenta ? '🧾'               : '💸';
    final signo   = esVenta ? '+'                : '-';
    final monto   = movimiento.monto.abs();

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(icono,
              style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esVenta ? 'Compra a crédito' : 'Pago registrado',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      AppColores.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                '${_formatearFecha(movimiento.fecha)}  •  '
                '${movimiento.vendedor}',
                style: const TextStyle(
                    fontSize: 12,
                    color:    AppColores.textSecond),
              ),
              if (esVenta) ...[
                const SizedBox(height: 3),
                _EstadoBadge(estado: movimiento.estado),
              ],
            ],
          ),
        ),
        Text(
          '$signo\$${monto.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   16,
              color:      color),
        ),
      ]),
    );
  }

  String _formatearFecha(String fechaStr) {
    try {
      final dt    = DateTime.parse(fechaStr);
      const meses = [
        '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${dt.day} ${meses[dt.month]} ${dt.year}';
    } catch (_) {
      return fechaStr;
    }
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'pagado'  => AppColores.success,
      'parcial' => AppColores.warning,
      _         => AppColores.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.bold,
            color:      color),
      ),
    );
  }
}