import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';

class RutaHeader extends ConsumerWidget {
  final EstadoRutaHoy? estado;
  const RutaHeader({super.key, this.estado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitadas = estado?.visitadas ?? 0;
    final total = estado?.total ?? 0;

    // Stock restante en tiempo real
    final stockAsync = ref.watch(stockRestanteProvider);
    final totalRestante = stockAsync.maybeWhen(
      data: (s) => s.stockCargado ? s.totalRestante : -1,
      orElse: () => -1,
    );
    final sinStock = stockAsync.maybeWhen(
      data: (s) => s.stockCargado && s.sinStock,
      orElse: () => false,
    );

    return Container(
      color: AppColores.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 0,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ── Progreso → abre modal empresas ─────────
              Expanded(
                child: GestureDetector(
                  onTap: () => _mostrarEmpresasModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.route_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Progreso  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$visitadas',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          ' / $total',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // ── Stock restante → abre modal stock ───────
              GestureDetector(
                onTap: () => _mostrarStockModal(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: sinStock
                        ? AppColores.danger.withOpacity(0.8)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sinStock
                          ? AppColores.danger
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sinStock
                            ? Icons.warning_rounded
                            : Icons.inventory_2_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        totalRestante < 0
                            ? 'Stock'
                            : sinStock
                            ? 'Sin stock'
                            : '$totalRestante uds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: LinearProgressIndicator(
              value: total > 0 ? visitadas / total : 0,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarEmpresasModal(BuildContext context) {
    if (estado == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ModalEmpresasRuta(estado: estado!),
    );
  }

  void _mostrarStockModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _ModalStockRestante(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MODAL EMPRESAS
// ══════════════════════════════════════════════════════════
class _ModalEmpresasRuta extends StatelessWidget {
  final EstadoRutaHoy estado;
  const _ModalEmpresasRuta({required this.estado});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColores.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 16,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              const Icon(
                Icons.route_rounded,
                color: AppColores.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  estado.rutaNombre ?? 'Mi ruta de hoy',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary,
                  ),
                ),
              ),
              _BadgePill(
                texto: '${estado.visitadas}/${estado.total} visitadas',
                color: AppColores.success,
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: estado.empresas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final emp = estado.empresas[i];
              return _EmpresaListTile(empresa: emp, numero: i + 1);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _EmpresaListTile extends StatelessWidget {
  final EmpresaRuta empresa;
  final int numero;
  const _EmpresaListTile({required this.empresa, required this.numero});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: empresa.visitada
          ? AppColores.success.withOpacity(0.05)
          : AppColores.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: empresa.visitada
            ? AppColores.success.withOpacity(0.3)
            : Colors.grey.withOpacity(0.15),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: empresa.visitada
                ? AppColores.success.withOpacity(0.1)
                : AppColores.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$numero',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: empresa.visitada
                    ? AppColores.success
                    : AppColores.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                empresa.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColores.textPrimary,
                ),
              ),
              if (empresa.direccion != null)
                Text(
                  empresa.direccion!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColores.textSecond,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Icon(
          empresa.visitada
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: empresa.visitada ? AppColores.success : Colors.grey.shade400,
          size: 20,
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  MODAL STOCK RESTANTE — Bug 1 + 3
// ══════════════════════════════════════════════════════════
class _ModalStockRestante extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockRestanteProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColores.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColores.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Stock del día',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColores.textPrimary,
                    ),
                  ),
                ),
                async.maybeWhen(
                  data: (s) => _BadgePill(
                    texto: s.stockCargado
                        ? '${s.totalRestante} restantes'
                        : 'Sin cargar',
                    color: !s.stockCargado
                        ? AppColores.textSecond
                        : s.sinStock
                        ? AppColores.danger
                        : AppColores.success,
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Error cargando stock',
                    style: TextStyle(color: AppColores.danger),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(stockRestanteProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (stock) {
              if (!stock.stockCargado) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: AppColores.textSecond,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Stock no cargado aún',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColores.textSecond,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (stock.sinStock) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColores.danger,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Sin stock disponible',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColores.danger,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Has vendido todo tu stock del día.',
                        style: TextStyle(
                          color: AppColores.textSecond,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stock.productos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _StockProductoRow(producto: stock.productos[i]),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StockProductoRow extends StatelessWidget {
  final ProductoStockRestante producto;
  const _StockProductoRow({required this.producto});

  @override
  Widget build(BuildContext context) {
    final agotado = producto.cantidadRestante == 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: agotado
            ? AppColores.danger.withOpacity(0.04)
            : AppColores.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: agotado
              ? AppColores.danger.withOpacity(0.2)
              : Colors.grey.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          // Avatar inicial
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: agotado
                  ? AppColores.danger.withOpacity(0.1)
                  : AppColores.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                producto.nombre[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: agotado ? AppColores.danger : AppColores.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: agotado ? AppColores.danger : AppColores.textPrimary,
                  ),
                ),
                Text(
                  'Vendido: ${producto.cantidadVendida} '
                  '/ ${producto.cantidadInicial}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColores.textSecond,
                  ),
                ),
              ],
            ),
          ),
          // Cantidad restante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: agotado
                  ? AppColores.danger.withOpacity(0.1)
                  : AppColores.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              agotado ? 'Agotado' : '${producto.cantidadRestante} uds',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: agotado ? AppColores.danger : AppColores.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers UI ────────────────────────────────────────────
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _BadgePill extends StatelessWidget {
  final String texto;
  final Color color;
  const _BadgePill({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
    ),
  );
}
