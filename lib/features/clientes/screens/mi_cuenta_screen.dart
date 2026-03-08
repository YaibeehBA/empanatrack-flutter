// lib/features/cliente/screens/mi_cuenta_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notificaciones_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/historial_provider.dart';
import '../../../shared/models/movimiento_model.dart';

// ── Providers del cliente ──────────────────────────────────
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
//  PANTALLA PRINCIPAL — ConsumerStatefulWidget para poder
//  registrar providers en initState
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
    // Registrar miSaldoProvider para que FCM lo refresque
    // automáticamente cuando llegue una notificación de venta
    registrarProviderParaRefrescar(miSaldoProvider);
    print('✅ [MiCuenta] miSaldoProvider registrado para FCM');
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(authProvider).sesion;

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Mi Cuenta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: _MiCuentaBody(nombreCliente: sesion?.nombre ?? ''),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BODY — ConsumerStatefulWidget para registrar
//  historialProvider una vez que tengamos el clienteId
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

      // Ahora que tenemos el clienteId, registramos historialProvider
      // para que FCM también lo refresque automáticamente
      registrarProviderParaRefrescar(historialProvider(id));
      print('✅ [MiCuenta] historialProvider($id) registrado para FCM');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras carga el clienteId mostramos spinner
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
//  CONTENIDO — ya no recibe ref como parámetro,
//  usa ConsumerWidget directamente
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
    final saldoAsync    = ref.watch(miSaldoProvider);
    final historialAsync = ref.watch(historialProvider(clienteId));

    return RefreshIndicator(
      onRefresh: () async {
        // Refresco manual con pull-to-refresh
        ref.invalidate(miSaldoProvider);
        ref.invalidate(historialProvider(clienteId));
      },
      child: ListView(
        children: [

          // ── Header con saldo ─────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: AppColores.primary,
            ),
            child: Column(
              children: [
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
                      color:      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nombreCliente,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Card saldo
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Mi deuda actual',
                        style: TextStyle(
                          color:    Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      saldoAsync.when(
                        loading: () => const CircularProgressIndicator(
                            color: Colors.white),
                        error: (e, _) => const Text(
                          'Error al cargar',
                          style: TextStyle(color: Colors.white),
                        ),
                        data: (saldo) => Text(
                          '\$${saldo.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: saldo > 0
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize:   40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      saldoAsync.maybeWhen(
                        data: (saldo) => Text(
                          saldo > 0
                              ? 'Tienes deuda pendiente'
                              : '¡Estás al día! 🎉',
                          style: const TextStyle(
                            color:    Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Historial ─────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'HISTORIAL DE MOVIMIENTOS',
              style: TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.bold,
                color:         AppColores.textSecond,
                letterSpacing: 1.2,
              ),
            ),
          ),

          historialAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child:   CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child:   Text('No se pudo cargar el historial'),
              ),
            ),
            data: (movimientos) => movimientos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Aún no tienes movimientos registrados.',
                        style: TextStyle(color: AppColores.textSecond),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: movimientos
                          .map((m) => _MovimientoItem(movimiento: m))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ITEM DE MOVIMIENTO — sin cambios
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
    final fecha   = _formatearFecha(movimiento.fecha);

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
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icono,
                  style: const TextStyle(fontSize: 22)),
            ),
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
                    color:      AppColores.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$fecha  •  ${movimiento.vendedor}',
                  style: const TextStyle(
                    fontSize: 12,
                    color:    AppColores.textSecond,
                  ),
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
              color:      color,
            ),
          ),
        ],
      ),
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
    Color color;
    switch (estado) {
      case 'pagado':
        color = AppColores.success;
        break;
      case 'parcial':
        color = AppColores.warning;
        break;
      default:
        color = AppColores.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.bold,
          color:      color,
        ),
      ),
    );
  }
}