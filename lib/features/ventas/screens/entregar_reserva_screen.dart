import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../models/ruta_activa_models.dart';
import '../providers/pedidos_vendedor_provider.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../../shared/models/cliente_model.dart';
import '../providers/ruta_activa_provider.dart';
import 'nueva_venta_screen.dart';

class EntregarReservaScreen extends ConsumerStatefulWidget {
  final EmpresaRuta          empresa;
  final List<PedidoVendedor> reservas;

  const EntregarReservaScreen({
    super.key,
    required this.empresa,
    required this.reservas,
  });

  @override
  ConsumerState<EntregarReservaScreen> createState() =>
      _EntregarReservaScreenState();
}

class _EntregarReservaScreenState
    extends ConsumerState<EntregarReservaScreen> {

  bool _huboCambios = false;

  @override
  Widget build(BuildContext context) {
    final reservasAsync =
        ref.watch(reservasEmpresaProvider(widget.empresa.id));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: AppColores.background,
        appBar: AppBar(
          backgroundColor: AppColores.primary,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reservas',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.empresa.nombre,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
              icon:      const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(
                  reservasEmpresaProvider(widget.empresa.id)),
            ),
          ],
        ),
        body: reservasAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  parsearErrorDio(e),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColores.textSecond),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(
                      reservasEmpresaProvider(widget.empresa.id)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (reservas) {
            if (reservas.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📋',
                          style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 16),
                      const Text('Sin reservas pendientes',
                          style: TextStyle(
                              fontSize:   18,
                              fontWeight: FontWeight.bold,
                              color:      AppColores.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        'No hay reservas activas para\n'
                        '${widget.empresa.nombre}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColores.textSecond),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _huboCambios),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColores.primary,
                            foregroundColor: Colors.white),
                        child: const Text('Volver al mapa'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BannerEmpresa(empresa: widget.empresa),
                const SizedBox(height: 16),

                Row(children: [
                  const Text('RESERVAS PARA ENTREGAR',
                      style: TextStyle(
                          fontSize:      10,
                          fontWeight:    FontWeight.bold,
                          color:         AppColores.textSecond,
                          letterSpacing: 1.0)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color:        AppColores.accent
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${reservas.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color:      AppColores.accent,
                            fontSize:   12)),
                  ),
                ]),
                const SizedBox(height: 12),

                ...reservas.map((reserva) => _TarjetaReserva(
                      reserva:    reserva,
                      onEntregar: () => _abrirEntrega(reserva),
                      onLiberar:  () => _confirmarLiberar(reserva),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Abrir NuevaVentaScreen pre-llenada y volver al mapa ──
  Future<void> _abrirEntrega(PedidoVendedor reserva) async {
    final productos = reserva.items.map((item) => (
      productoId: item['producto_id'] as String,
      nombre:     item['nombre']      as String,
      precio:     (item['precio_unit'] as num).toDouble(),
      cantidad:   item['cantidad']    as int,
      imagenUrl:  item['imagen_url'] as String?,  
    )).toList();

    // Buscar cliente
    ClienteModel? cliente;
    try {
      final clientes = ref.read(clientesProvider).asData?.value;
      if (clientes != null) {
        cliente = clientes.firstWhere(
          (c) => c.nombre == reserva.clienteNombre,
          orElse: () => ClienteModel(
            id:          reserva.id,
            nombre:      reserva.clienteNombre,
            cedula:      '',
            saldoActual: 0.0,
          ),
        );
      }
    } catch (_) {}

    // Navegar a NuevaVentaScreen
    final exito = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaVentaScreen(
          reservaId:          reserva.id,
          clienteInicial:     cliente,
          productosIniciales: productos,
        ),
      ),
    );

    if (exito == true && mounted) {
      _huboCambios = true;

      // Invalidar providers para refrescar datos
      ref.invalidate(reservasActivasProvider);
      ref.invalidate(reservasEmpresaProvider(widget.empresa.id));
      ref.invalidate(stockRestanteProvider);

      // ✅ Pop inmediato - sin delay
      // El SnackBar de éxito se debe mostrar en el MapaRutaScreen
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // ── Confirmar liberar stock ───────────────────────────
  Future<void> _confirmarLiberar(PedidoVendedor reserva) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_open_rounded, color: AppColores.warning),
          SizedBox(width: 8),
          Text('Liberar reserva'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'La reserva de ${reserva.clienteNombre} '
              'será cancelada y los productos volverán '
              'a tu stock disponible.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        AppColores.warning.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppColores.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se liberarán ${reserva.items.fold<int>(0, (s, i) => s + (i['cantidad'] as int))} unidades.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.warning),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Liberar stock'),
          ),
        ],
      ),
    );

    if (confirma != true || !mounted) return;

    try {
      await ApiClient.post(
          '/pedidos/${reserva.id}/liberar-reserva');
      _huboCambios = true;

      // Invalidar todo lo necesario
      ref.invalidate(reservasEmpresaProvider(widget.empresa.id));
      ref.invalidate(reservasActivasProvider);
      ref.invalidate(stockRestanteProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Stock liberado — unidades de vuelta en tu inventario'),
            backgroundColor: AppColores.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(parsearErrorDio(e)),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════
//  BANNER EMPRESA
// ══════════════════════════════════════════════════════════
class _BannerEmpresa extends StatelessWidget {
  final EmpresaRuta empresa;
  const _BannerEmpresa({required this.empresa});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColores.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColores.primary.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColores.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded,
                color: AppColores.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(empresa.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   15,
                        color:      AppColores.textPrimary)),
                if (empresa.direccion != null)
                  Text(empresa.direccion!,
                      style: const TextStyle(
                          fontSize: 12,
                          color:    AppColores.textSecond),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  TARJETA RESERVA
// ══════════════════════════════════════════════════════════
class _TarjetaReserva extends StatelessWidget {
  final PedidoVendedor reserva;
  final VoidCallback   onEntregar;
  final VoidCallback   onLiberar;

  const _TarjetaReserva({
    required this.reserva,
    required this.onEntregar,
    required this.onLiberar,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
              left: BorderSide(color: AppColores.accent, width: 4)),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset:     const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Cliente + total
              Row(children: [
                CircleAvatar(
                  radius:          22,
                  backgroundColor:
                      AppColores.accent.withValues(alpha: 0.12),
                  child: Text(
                    reserva.clienteNombre.isNotEmpty
                        ? reserva.clienteNombre[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   18,
                        color:      AppColores.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reserva.clienteNombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:   15,
                              color:      AppColores.textPrimary)),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:        AppColores.accent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('ACEPTADA',
                              style: TextStyle(
                                  fontSize:   9,
                                  fontWeight: FontWeight.bold,
                                  color:      AppColores.accent)),
                        ),
                        const SizedBox(width: 6),
                        // Las reservas siempre son contado
                        const Text('💵 Contado',
                            style: TextStyle(
                                fontSize: 11,
                                color:    AppColores.textSecond)),
                      ]),
                    ],
                  ),
                ),
                Text('\$${reserva.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   18,
                        color:      AppColores.primary)),
              ]),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 10),

              // Productos
              const Text('PRODUCTOS',
                  style: TextStyle(
                      fontSize:      9,
                      fontWeight:    FontWeight.bold,
                      color:         AppColores.textSecond,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),

              ...reserva.items.map((item) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width:  28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:        AppColores.accent
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${item['cantidad']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize:   12,
                                  color:      AppColores.accent)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item['nombre'] as String,
                            style: const TextStyle(
                                fontSize: 13,
                                color:    AppColores.textPrimary)),
                      ),
                      Text(
                        '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color:      AppColores.textPrimary),
                      ),
                    ]),
                  )),

              if (reserva.notas != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:     const EdgeInsets.all(8),
                  decoration:  BoxDecoration(
                      color:        Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.notes,
                        size: 13, color: AppColores.textSecond),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reserva.notas!,
                          style: const TextStyle(
                              fontSize: 11,
                              color:    AppColores.textSecond)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 14),

              // Botones
              Row(children: [
                // Liberar stock
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLiberar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColores.warning,
                      side: BorderSide(
                          color: AppColores.warning
                              .withValues(alpha: 0.6),
                          width: 1.5),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon:  const Icon(Icons.lock_open_rounded, size: 16),
                    label: const Text('Liberar stock',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   12)),
                  ),
                ),
                const SizedBox(width: 10),

                // Hacer venta (siempre contado)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEntregar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.success,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        size: 16),
                    label: const Text('Entregar (contado)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   12)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}