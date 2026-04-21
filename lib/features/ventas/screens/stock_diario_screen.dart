import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';

class StockDiarioScreen extends ConsumerStatefulWidget {
  final VoidCallback onStockConfirmado;
  const StockDiarioScreen({super.key, required this.onStockConfirmado});

  @override
  ConsumerState<StockDiarioScreen> createState() =>
      _StockDiarioScreenState();
}

class _StockDiarioScreenState
    extends ConsumerState<StockDiarioScreen> {
  List<ProductoStock> _productos = [];
  bool    _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await ref.read(stockHoyProvider.future);
      setState(() { _productos = r; _cargando = false; });
    } catch (_) {
      setState(() { _cargando = false; _error = 'Error al cargar'; });
    }
  }

  int get _total => _productos.fold(0, (s, p) => s + p.cantidad);

  @override
  Widget build(BuildContext context) {
    final accionState = ref.watch(rutaAccionProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('¿Cuánto llevas hoy?',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [

              // Banner instructivo
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColores.primary,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registra tu stock',
                          style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:   15)),
                      SizedBox(height: 2),
                      Text(
                        'Ingresa cuántas unidades de cada '
                        'producto llevas hoy.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  )),
                ]),
              ),

              // Lista productos
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount:        _productos.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) => _StockItem(
                  producto: _productos[i],
                  onChange: (v) => setState(
                      () => _productos[i].cantidad = v),
                ),
              )),
            ]),
      bottomNavigationBar: _BottomStockBar(
        total:       _total,
        cargando:    accionState.cargando,
        error:       _error ?? accionState.error,
        onConfirmar: () async {
          final ok = await ref
              .read(rutaAccionProvider.notifier)
              .guardarStock(_productos);
          if (ok && mounted) widget.onStockConfirmado();
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ITEM STOCK
// ══════════════════════════════════════════════════════════
class _StockItem extends StatelessWidget {
  final ProductoStock     producto;
  final ValueChanged<int> onChange;

  const _StockItem({
    required this.producto, required this.onChange});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        AppColores.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: producto.cantidad > 0
            ? AppColores.primary.withOpacity(0.3)
            : Colors.grey.withOpacity(0.12),
        width: producto.cantidad > 0 ? 1.5 : 1,
      ),
    ),
    child: Row(children: [

      // Avatar con imagen o inicial
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: producto.cantidad > 0
              ? AppColores.primary.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: producto.imagenUrl != null &&
                producto.imagenUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  producto.imagenUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      producto.nombre[0].toUpperCase(),
                      style: TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          color: producto.cantidad > 0
                              ? AppColores.primary
                              : Colors.grey.shade400),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  producto.nombre[0].toUpperCase(),
                  style: TextStyle(
                      fontSize:   22,
                      fontWeight: FontWeight.bold,
                      color: producto.cantidad > 0
                          ? AppColores.primary
                          : Colors.grey.shade400),
                ),
              ),
      ),
      const SizedBox(width: 14),

      // Nombre y precio
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(producto.nombre, style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   15,
              color:      AppColores.textPrimary)),
          const SizedBox(height: 2),
          Text('\$${producto.precio.toStringAsFixed(2)} c/u',
              style: const TextStyle(
                  fontSize: 13,
                  color:    AppColores.textSecond)),
          if (producto.cantidad > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Total: \$${(producto.precio * producto.cantidad).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      AppColores.success),
            ),
          ],
        ],
      )),
      const SizedBox(width: 8),

      // Control cantidad
      Column(mainAxisSize: MainAxisSize.min, children: [
        _BtnCantidad(
          icono: Icons.add,
          color: AppColores.primary,
          onTap: () => onChange(producto.cantidad + 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${producto.cantidad}',
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color: producto.cantidad > 0
                  ? AppColores.primary : AppColores.textSecond,
            ),
          ),
        ),
        _BtnCantidad(
          icono: Icons.remove,
          color: producto.cantidad > 0
              ? AppColores.danger : Colors.grey,
          onTap: producto.cantidad > 0
              ? () => onChange(producto.cantidad - 1) : null,
        ),
      ]),
    ]),
  );
}

class _BtnCantidad extends StatelessWidget {
  final IconData      icono;
  final Color         color;
  final VoidCallback? onTap;

  const _BtnCantidad({
    required this.icono,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(onTap == null ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withOpacity(onTap == null ? 0.1 : 0.2)),
      ),
      child: Icon(icono, size: 16,
          color: onTap == null
              ? Colors.grey.shade300 : color),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  BOTTOM BAR
// ══════════════════════════════════════════════════════════
class _BottomStockBar extends StatelessWidget {
  final int          total;
  final bool         cargando;
  final String?      error;
  final VoidCallback onConfirmar;

  const _BottomStockBar({
    required this.total,
    required this.cargando,
    required this.onConfirmar,
    this.error,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        MediaQuery.of(context).padding.bottom + 12),
    decoration: const BoxDecoration(
      color: AppColores.surface,
      border: Border(
          top: BorderSide(color: Color(0xFFE8ECF0))),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(error!, style: const TextStyle(
              color: AppColores.danger, fontSize: 13)),
        ),
      Row(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total cargado',
                style: TextStyle(
                    fontSize: 11,
                    color:    AppColores.textSecond)),
            RichText(text: TextSpan(children: [
              TextSpan(
                text: '$total ',
                style: const TextStyle(
                    fontSize:   22,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.primary),
              ),
              const TextSpan(
                text: 'unidades',
                style: TextStyle(
                    fontSize: 13,
                    color:    AppColores.textSecond),
              ),
            ])),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 48, width: 190,
          child: ElevatedButton(
            onPressed: (cargando || total == 0) ? null : onConfirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor:         AppColores.success,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: cargando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color:       Colors.white,
                        strokeWidth: 2))
                : const Text('Confirmar stock',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ]),
  );
}