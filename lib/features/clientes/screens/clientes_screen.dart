import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/clientes_provider.dart';
import '../../../shared/models/cliente_model.dart';

class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      
      // ── AppBar ────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Clientes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(clientesProvider),
          ),
        ],
      ),

      // ── FAB: Nuevo Cliente (AGREGADO) ────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/nuevo-cliente');
          ref.invalidate(clientesProvider);
        },
        backgroundColor: AppColores.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text(
          'Nuevo Cliente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ── Body ──────────────────────────────────────────────
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorWidget(
          onReintentar: () => ref.invalidate(clientesProvider),
        ),
        data: (clientes) {
          if (clientes.isEmpty) {
            return const _EmptyWidget();
          }

          // Ordenar por mayor deuda primero
          final ordenados = [...clientes]
            ..sort((a, b) => b.saldoActual.compareTo(a.saldoActual));

          // Total general de deudas
          final totalDeudas = ordenados.fold<double>(
            0, (sum, c) => sum + c.saldoActual,
          );

          return Column(
            children: [
              // Banner total deudas
              _BannerTotal(total: totalDeudas, cantidad: clientes.length),

              // Lista de clientes
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ordenados.length,
                    itemBuilder: (ctx, i) =>
                        _ClienteCard(cliente: ordenados[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Banner con el total de deudas ──────────────────────────
class _BannerTotal extends StatelessWidget {
  final double total;
  final int cantidad;
  const _BannerTotal({required this.total, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColores.primary,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total en deudas',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$cantidad clientes',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de cada cliente ───────────────────────────────────
class _ClienteCard extends StatelessWidget {
  final ClienteModel cliente;
  const _ClienteCard({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final tieneDeuda = cliente.saldoActual > 0;
    final colorSaldo = tieneDeuda ? AppColores.danger : AppColores.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColores.accent.withOpacity(0.12),
                child: Text(
                  cliente.nombre[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColores.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColores.textPrimary,
                      ),
                    ),
                    if (cliente.empresa != null)
                      Row(children: [
                        const Icon(Icons.business_outlined,
                            size: 13, color: AppColores.textSecond),
                        const SizedBox(width: 4),
                        Text(cliente.empresa!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColores.textSecond)),
                      ]),
                    Row(children: [
                      const Icon(Icons.badge_outlined,
                          size: 13, color: AppColores.textSecond),
                      const SizedBox(width: 4),
                      Text('CI: ${cliente.cedula}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColores.textSecond)),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${cliente.saldoActual.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorSaldo,
                    ),
                  ),
                  Text(
                    tieneDeuda ? 'Debe' : 'Al día ✓',
                    style: TextStyle(fontSize: 11, color: colorSaldo),
                  ),
                ],
              ),
            ],
          ),

          // Botón cobrar — solo si tiene deuda
          if (tieneDeuda) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/registrar-pago/${cliente.id}',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColores.success,
                  side: const BorderSide(color: AppColores.success),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text(
                  'Registrar cobro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets de estado ──────────────────────────────────────
class _ErrorWidget extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorWidget({required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: AppColores.textSecond),
          const SizedBox(height: 16),
          const Text('No se pudieron cargar los clientes',
              style: TextStyle(color: AppColores.textSecond)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏪', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text(
            'No hay clientes registrados aún.',
            style: TextStyle(color: AppColores.textSecond, fontSize: 15),
          ),
        ],
      ),
    );
  }
}