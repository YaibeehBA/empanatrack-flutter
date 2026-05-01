import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colores.dart';
import '../../../../core/network/api_client.dart';
import '../../pedidos/models/pedido_models.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../../shared/models/cliente_model.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';
import '../screens/nueva_venta_screen.dart';


// Provider local para las reservas de la empresa actual
final _reservasEmpresaProvider =
    FutureProvider.autoDispose.family<List<PedidoBase>, String>(
  (ref, empresaId) async {
    final r = await ApiClient.get(
        '/pedidos/reservas-empresa/$empresaId');
    return (r.data as List)
        .map((p) => PedidoBase.fromJson(p))
        .toList();
  },
);

class PanelReservasEmpresa extends ConsumerWidget {
  final EmpresaRuta empresa;
  const PanelReservasEmpresa({super.key, required this.empresa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
        _reservasEmpresaProvider(empresa.id));

    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // Título
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(children: [
            const Icon(Icons.bookmark_outlined,
                color: AppColores.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reservas pendientes',
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold,
                        color:      AppColores.textPrimary)),
                Text(empresa.nombre,
                    style: const TextStyle(
                        fontSize: 12,
                        color:    AppColores.textSecond)),
              ],
            )),
            async.maybeWhen(
              data: (list) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColores.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${list.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColores.accent,
                        fontSize:   13)),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
        ),

        // Lista
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child:   CircularProgressIndicator(),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(20),
            child:   Text('Error cargando reservas'),
          ),
          data: (reservas) {
            if (reservas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📋',
                        style: TextStyle(fontSize: 40)),
                    SizedBox(height: 12),
                    Text('Sin reservas para esta empresa',
                        style: TextStyle(
                            color:    AppColores.textSecond,
                            fontSize: 14)),
                  ],
                ),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap:       true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount:        reservas.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReservaItem(
                  reserva:     reservas[i],
                  onEntregar:  () async {
                    Navigator.pop(context, true);
                    await _entregarReserva(
                        context, ref, reservas[i]);
                  },
                  onLiberar: () async {
                    await _liberarReserva(
                        context, ref, reservas[i]);
                    ref.invalidate(
                        _reservasEmpresaProvider(empresa.id));
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Entregar reserva → abrir nueva venta pre-llenada ───
  Future<void> _entregarReserva(
    BuildContext context,
    WidgetRef    ref,
    PedidoBase   reserva,
  ) async {
    // Construir cliente si está disponible
    ClienteModel? cliente;
    if (reserva.clienteNombre.isNotEmpty) {
      // Buscar en la lista de clientes por nombre
      final clientes = ref.read(clientesProvider).asData?.value;
      cliente = clientes?.firstWhere(
        (c) => c.nombre == reserva.clienteNombre,
        orElse: () => ClienteModel(
          id:     reserva.clienteId,
          nombre: reserva.clienteNombre,
          cedula: '',
          saldoActual: 0.0,
        ),
      );
    }

    // Construir productos de la reserva
    final productos = reserva.items.map((item) => (
      productoId: item['producto_id'] as String,
      nombre:     item['nombre']      as String,
      precio:     (item['precio_unit'] as num).toDouble(),
      cantidad:   item['cantidad']    as int,
    )).toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaVentaScreen(
          reservaId:          reserva.id,
          clienteInicial:     cliente,
          productosIniciales: productos,
        ),
      ),
    );
  }

  // ── Liberar reserva ────────────────────────────────────
  Future<void> _liberarReserva(
    BuildContext context,
    WidgetRef    ref,
    PedidoBase   reserva,
  ) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Liberar reserva'),
        content: Text(
            '¿Liberar la reserva de ${reserva.clienteNombre}? '
            'Las unidades volverán a tu stock disponible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.warning,
                foregroundColor: Colors.white),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    try {
      await ApiClient.post(
          '/pedidos/${reserva.id}/liberar-reserva');
      ref.invalidate(stockRestanteProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Reserva liberada — stock actualizado'),
            backgroundColor: AppColores.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Error al liberar reserva'),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    }
  }
}

// ── Item de reserva ───────────────────────────────────────
class _ReservaItem extends StatelessWidget {
  final PedidoBase   reserva;
  final VoidCallback onEntregar;
  final VoidCallback onLiberar;

  const _ReservaItem({
    required this.reserva,
    required this.onEntregar,
    required this.onLiberar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppColores.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: AppColores.accent.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Cliente + total
        Row(children: [
          CircleAvatar(
            radius:          18,
            backgroundColor:
                AppColores.accent.withOpacity(0.12),
            child: Text(
              reserva.clienteNombre.isNotEmpty
                  ? reserva.clienteNombre[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reserva.clienteNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColores.textPrimary)),
              Text('\$${reserva.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color:    AppColores.accent,
                      fontWeight: FontWeight.w600)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColores.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reserva.estado == 'aceptado'
                  ? 'ACEPTADA' : 'PENDIENTE',
              style: const TextStyle(
                  fontSize:   9,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.accent),
            ),
          ),
        ]),

        // Productos
        const SizedBox(height: 8),
        ...reserva.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            const Icon(Icons.circle,
                size: 5, color: AppColores.textSecond),
            const SizedBox(width: 6),
            Expanded(child: Text(
              '${item['cantidad']}x ${item['nombre']}',
              style: const TextStyle(
                  fontSize: 12,
                  color:    AppColores.textSecond),
            )),
            Text(
              '\$${(item['subtotal'] as num).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color:      AppColores.textPrimary),
            ),
          ]),
        )),

        // Botones
        const SizedBox(height: 10),
        Row(children: [

          // Liberar
          Expanded(child: OutlinedButton.icon(
            onPressed: onLiberar,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.warning,
              side: BorderSide(
                  color: AppColores.warning.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon:  const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text('Liberar',
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 10),

          // Entregar
          Expanded(child: ElevatedButton.icon(
            onPressed: reserva.estado == 'aceptado'
                ? onEntregar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon:  const Icon(Icons.check_circle_outline,
                size: 16),
            label: const Text('Entregar',
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          )),
        ]),
      ],
    ),
  );
}