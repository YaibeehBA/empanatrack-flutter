import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/reportes_admin_provider.dart';

// Provider local para el periodo seleccionado
final _periodoProvider = StateProvider<String>((ref) => 'hoy');

class ReportesAdminScreen extends ConsumerWidget {
  const ReportesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColores.background,
        appBar: AppBar(
          backgroundColor: AppColores.primary,
          foregroundColor: Colors.white,
          title: const Text('Reportes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor:   Colors.white,
            labelColor:       Colors.white,
            unselectedLabelColor: Colors.white60,
            isScrollable:     true,
            tabAlignment:     TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.bar_chart),      text: 'Resumen'),
              Tab(icon: Icon(Icons.people_outline),  text: 'Vendedores'),
              Tab(icon: Icon(Icons.fastfood_outlined),text: 'Productos'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined),
                  text: 'Deudas'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Selector de periodo ───────────────────────
            _SelectorPeriodo(),
            // ── Tabs ─────────────────────────────────────
            const Expanded(
              child: TabBarView(
                children: [
                  _TabResumen(),
                  _TabVendedores(),
                  _TabProductos(),
                  _TabDeudas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTOR DE PERIODO
// ══════════════════════════════════════════════════════════
class _SelectorPeriodo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(_periodoProvider);

    final opciones = [
      ('hoy',    'Hoy'),
      ('ayer',   'Ayer'),
      ('semana', 'Semana'),
      ('mes',    'Mes'),
    ];

    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: opciones.map((op) {
          final seleccionado = periodo == op.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(_periodoProvider.notifier).state = op.$1;
                // Invalidar providers para recargar con nuevo periodo
                ref.invalidate(resumenGeneralProvider);
                ref.invalidate(ventasPorVendedorProvider);
                ref.invalidate(productosMasVendidosProvider);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:  const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? AppColores.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  op.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.bold,
                    color:      seleccionado
                        ? Colors.white : AppColores.textSecond,
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
//  TAB 1 — RESUMEN GENERAL
// ══════════════════════════════════════════════════════════
class _TabResumen extends ConsumerWidget {
  const _TabResumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(_periodoProvider);
    final async   = ref.watch(resumenGeneralProvider(periodo));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorBox(onRetry: () =>
          ref.invalidate(resumenGeneralProvider)),
      data: (r) => RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(resumenGeneralProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card principal — dinero en mano
            _CardDestacada(
              titulo: 'Total vendido',
              valor:  r.totalVendido,
              icono:  '💰',
              color:  AppColores.primary,
              sub:    '${r.totalVentas} ventas en el periodo',
            ),
            const SizedBox(height: 12),

            // Grid de 2 columnas
            GridView.count(
              crossAxisCount:   2,
              crossAxisSpacing: 10,
              mainAxisSpacing:  10,
              shrinkWrap:       true,
              childAspectRatio: 1.4,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MiniCard(
                  icono:  '🧾',
                  titulo: 'Contado',
                  valor:  r.totalContado,
                  color:  AppColores.success,
                ),
                _MiniCard(
                  icono:  '📋',
                  titulo: 'Fiado',
                  valor:  r.totalFiado,
                  color:  AppColores.warning,
                ),
                _MiniCard(
                  icono:  '✅',
                  titulo: 'Cobrado',
                  valor:  r.totalCobrado,
                  color:  AppColores.accent,
                ),
                _MiniCard(
                  icono:  '⚠️',
                  titulo: 'Total deudas',
                  valor:  r.totalDeudas,
                  color:  AppColores.danger,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Clientes con deuda
            _FilaInfo(
              icono:  Icons.people_outline,
              color:  AppColores.danger,
              titulo: 'Clientes con deuda pendiente',
              valor:  '${r.clientesConDeuda}',
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 2 — VENTAS POR VENDEDOR
// ══════════════════════════════════════════════════════════
class _TabVendedores extends ConsumerWidget {
  const _TabVendedores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(_periodoProvider);
    final async   = ref.watch(ventasPorVendedorProvider(periodo));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorBox(onRetry: () =>
          ref.invalidate(ventasPorVendedorProvider)),
      data: (lista) => lista.isEmpty
          ? const _Vacio(mensaje: 'Sin ventas en este periodo')
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(ventasPorVendedorProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount:   lista.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final v = lista[i];
                  return _CardVendedor(
                    vendedor: v,
                    posicion: i + 1,
                    maxVendido: lista.first.totalVendido,
                  );
                },
              ),
            ),
    );
  }
}

class _CardVendedor extends StatelessWidget {
  final VentaVendedor vendedor;
  final int           posicion;
  final double        maxVendido;
  const _CardVendedor({
    required this.vendedor,
    required this.posicion,
    required this.maxVendido,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxVendido > 0
        ? vendedor.totalVendido / maxVendido : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Posición / medalla
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: posicion == 1
                      ? const Color(0xFFFFF0C0)
                      : posicion == 2
                          ? const Color(0xFFF0F0F0)
                          : AppColores.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    posicion == 1 ? '🥇'
                        : posicion == 2 ? '🥈'
                        : posicion == 3 ? '🥉' : '$posicion',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendedor.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   15,
                          color:      AppColores.textPrimary,
                        )),
                    Text('${vendedor.totalVentas} ventas',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.textSecond)),
                  ],
                ),
              ),
              Text(
                '\$${vendedor.totalVendido.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            pct,
              minHeight:        6,
              backgroundColor:  Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColores.primary),
            ),
          ),
          const SizedBox(height: 10),

          // Fila contado / fiado / cobrado
          Row(
            children: [
              _ChipInfo(
                  label: 'Contado',
                  valor: vendedor.totalContado,
                  color: AppColores.success),
              const SizedBox(width: 8),
              _ChipInfo(
                  label: 'Fiado',
                  valor: vendedor.totalFiado,
                  color: AppColores.warning),
              const SizedBox(width: 8),
              _ChipInfo(
                  label: 'Cobrado',
                  valor: vendedor.totalCobrado,
                  color: AppColores.accent),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 3 — PRODUCTOS MÁS VENDIDOS
// ══════════════════════════════════════════════════════════
class _TabProductos extends ConsumerWidget {
  const _TabProductos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(_periodoProvider);
    final async   = ref.watch(productosMasVendidosProvider(periodo));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorBox(onRetry: () =>
          ref.invalidate(productosMasVendidosProvider)),
      data: (lista) {
        final conVentas = lista
            .where((p) => p.totalCantidad > 0).toList();
        if (conVentas.isEmpty) {
          return const _Vacio(
              mensaje: 'Sin productos vendidos en este periodo');
        }
        final maxCantidad = conVentas.first.totalCantidad;
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(productosMasVendidosProvider),
          child: ListView.separated(
            padding:      const EdgeInsets.all(16),
            itemCount:    conVentas.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (_, i) => _CardProducto(
              producto:    conVentas[i],
              posicion:    i + 1,
              maxCantidad: maxCantidad,
            ),
          ),
        );
      },
    );
  }
}

class _CardProducto extends StatelessWidget {
  final ProductoVendido producto;
  final int             posicion;
  final int             maxCantidad;
  const _CardProducto({
    required this.producto,
    required this.posicion,
    required this.maxCantidad,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxCantidad > 0
        ? producto.totalCantidad / maxCantidad : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color:        AppColores.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    posicion <= 3 ? ['🥇','🥈','🥉'][posicion-1]
                        : '🫓',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:   15,
                          color:      AppColores.textPrimary,
                        )),
                    Text(
                      '\$${producto.precioUnitario.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textSecond),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${producto.totalCantidad}',
                      style: const TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.bold,
                        color:      AppColores.primary,
                      )),
                  const Text('unidades',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColores.textSecond)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           pct,
              minHeight:       6,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColores.success),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ingresos: \$${producto.totalIngresos.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      AppColores.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 4 — DEUDAS POR CLIENTE
// ══════════════════════════════════════════════════════════
class _TabDeudas extends ConsumerWidget {
  const _TabDeudas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deudasClientesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorBox(
          onRetry: () => ref.invalidate(deudasClientesProvider)),
      data: (lista) => lista.isEmpty
          ? const _Vacio(mensaje: '🎉 Sin deudas pendientes')
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(deudasClientesProvider),
              child: Column(
                children: [
                  // Total deudas
                  Container(
                    width:   double.infinity,
                    margin:  const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        AppColores.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColores.danger.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️',
                            style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total en deudas',
                                style: TextStyle(
                                  color:    AppColores.danger,
                                  fontSize: 12,
                                )),
                            Text(
                              '\$${lista.fold(0.0, (s, d) => s + d.saldoActual).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize:   24,
                                fontWeight: FontWeight.bold,
                                color:      AppColores.danger,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${lista.length}',
                                style: const TextStyle(
                                  fontSize:   20,
                                  fontWeight: FontWeight.bold,
                                  color:      AppColores.danger,
                                )),
                            const Text('clientes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:    AppColores.danger,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount:    lista.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _CardDeuda(deuda: lista[i], posicion: i + 1),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CardDeuda extends StatelessWidget {
  final DeudaCliente deuda;
  final int          posicion;
  const _CardDeuda({required this.deuda, required this.posicion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar con inicial
          CircleAvatar(
            radius:          22,
            backgroundColor: AppColores.danger.withOpacity(0.12),
            child: Text(
              deuda.nombre.isNotEmpty
                  ? deuda.nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color:      AppColores.danger,
                fontSize:   18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deuda.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                      color:      AppColores.textPrimary,
                    )),
                if (deuda.empresa != null)
                  Text(deuda.empresa!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textSecond)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColores.danger.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '\$${deuda.saldoActual.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   15,
                color:      AppColores.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS REUTILIZABLES
// ══════════════════════════════════════════════════════════
class _CardDestacada extends StatelessWidget {
  final String titulo;
  final double valor;
  final String icono;
  final Color  color;
  final String sub;
  const _CardDestacada({
    required this.titulo, required this.valor,
    required this.icono,  required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Text(icono, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              Text(
                '\$${valor.toStringAsFixed(2)}',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String icono;
  final String titulo;
  final double valor;
  final Color  color;
  const _MiniCard({
    required this.icono, required this.titulo,
    required this.valor, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icono, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColores.textSecond)),
            ],
          ),
          const Spacer(),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final IconData icono;
  final Color    color;
  final String   titulo;
  final String   valor;
  const _FilaInfo({
    required this.icono, required this.color,
    required this.titulo, required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo,
              style: const TextStyle(
                  color: AppColores.textPrimary,
                  fontSize: 14))),
          Text(valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   16,
                color:      color,
              )),
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final String label;
  final double valor;
  final Color  color;
  const _ChipInfo({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color)),
            Text(
              '\$${valor.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.bold,
                color:      color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String mensaje;
  const _Vacio({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(mensaje,
              style: const TextStyle(
                  color: AppColores.textSecond, fontSize: 15)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('Error al cargar datos',
              style: TextStyle(color: AppColores.textSecond)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}