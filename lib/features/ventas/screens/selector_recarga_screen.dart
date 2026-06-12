import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';
import '../providers/ruta_activa_provider.dart';
import '../providers/recarga_stock_provider.dart';

class SelectorRecargaScreen extends ConsumerStatefulWidget {
  final VoidCallback onRecargaSolicitada;

  const SelectorRecargaScreen({
    super.key,
    required this.onRecargaSolicitada,
  });

  @override
  ConsumerState<SelectorRecargaScreen> createState() =>
      _SelectorRecargaScreenState();
}

class _SelectorRecargaScreenState
    extends ConsumerState<SelectorRecargaScreen> {
  List<ProductoStockRestante> _productos = [];
  bool    _cargando    = true;
  bool    _solicitando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await ref.read(stockRestanteProvider.future);
      final productos = r.productos.toList();
      // Inicializar cantidad en 0 (igual que StockDiarioScreen)
      for (final p in productos) {
        p.cantidad = 0;
      }
      setState(() { _productos = productos; _cargando = false; });
    } catch (_) {
      setState(() { _cargando = false; _error = 'Error al cargar el stock'; });
    }
  }

  int get _totalSolicitado =>
      _productos.fold(0, (s, p) => s + (p.cantidad ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Selecciona tu recarga',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon:      const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColores.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _cargar,
                          child: const Text('Reintentar')),
                    ],
                  ),
                )
              : _productos.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos disponibles para recargar',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColores.textSecond),
                      ),
                    )
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('¿Qué necesitas?',
                                    style: TextStyle(
                                        color:      Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize:   15)),
                                SizedBox(height: 2),
                                Text(
                                  'Selecciona cuánto de cada producto '
                                  'necesitas que el admin te recargue.',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),

                      // Lista productos
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          itemCount:        _productos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ProductoRecargaItem(
                            producto: _productos[i],
                            onChange: (v) =>
                                setState(() => _productos[i].cantidad = v),
                          ),
                        ),
                      ),
                    ]),
      bottomNavigationBar: _BottomRecargaBar(
        total:    _totalSolicitado,
        cargando: _solicitando,
        onSolicitar: () async {
          if (_totalSolicitado == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:         Text('Selecciona al menos un producto'),
                backgroundColor: AppColores.warning,
              ),
            );
            return;
          }

          setState(() => _solicitando = true);

          final resultado = await ref
              .read(recargaStockProvider.notifier)
              .solicitarRecarga(productos: _productos);

          if (!mounted) return;
          setState(() => _solicitando = false);

          if (resultado.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:         Text(resultado.error!),
              backgroundColor: AppColores.danger,
            ));
            return;
          }

          widget.onRecargaSolicitada(); // ✅ primero callback
          if (mounted) Navigator.pop(context); // ✅ luego pop
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ITEM PRODUCTO — igual estructura que _StockItem
// ══════════════════════════════════════════════════════════
class _ProductoRecargaItem extends StatelessWidget {
  final ProductoStockRestante producto;
  final ValueChanged<int>     onChange;

  const _ProductoRecargaItem({
    required this.producto,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cantidad = producto.cantidad ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColores.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cantidad > 0
              ? AppColores.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.12),
          width: cantidad > 0 ? 1.5 : 1,
        ),
      ),
      child: Row(children: [

        // Avatar con imagen o inicial
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: cantidad > 0
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
                            color: cantidad > 0
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
                        color: cantidad > 0
                            ? AppColores.primary
                            : Colors.grey.shade400),
                  ),
                ),
        ),
        const SizedBox(width: 14),

        // Nombre, precio y disponible
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(producto.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                    color:      AppColores.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Text(
                '\$${producto.precio.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13, color: AppColores.textSecond),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColores.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'En stock: ${producto.cantidadRestante}',
                  style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.bold,
                      color: producto.cantidadRestante == 0
                          ? AppColores.danger
                          : AppColores.accent),
                ),
              ),
            ]),
            if (cantidad > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Solicitar: $cantidad uds',
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
            onTap: () => onChange(cantidad + 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '$cantidad',
              style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color: cantidad > 0
                      ? AppColores.primary
                      : AppColores.textSecond),
            ),
          ),
          _BtnCantidad(
            icono: Icons.remove,
            color: cantidad > 0 ? AppColores.danger : Colors.grey,
            onTap: cantidad > 0 ? () => onChange(cantidad - 1) : null,
          ),
        ]),
      ]),
    );
  }
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
          color: onTap == null ? Colors.grey.shade300 : color),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  BOTTOM BAR
// ══════════════════════════════════════════════════════════
class _BottomRecargaBar extends StatelessWidget {
  final int          total;
  final bool         cargando;
  final VoidCallback onSolicitar;

  const _BottomRecargaBar({
    required this.total,
    required this.cargando,
    required this.onSolicitar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        MediaQuery.of(context).padding.bottom + 12),
    decoration: const BoxDecoration(
      color:  AppColores.surface,
      border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
    ),
    child: Row(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [
          const Text('Total a solicitar',
              style: TextStyle(
                  fontSize: 11, color: AppColores.textSecond)),
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
                  fontSize: 13, color: AppColores.textSecond),
            ),
          ])),
        ],
      ),
      const Spacer(),
      SizedBox(
        height: 48,
        width:  160,
        child: ElevatedButton(
          onPressed: (cargando || total == 0) ? null : onSolicitar,
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
                      color: Colors.white, strokeWidth: 2))
              : const Text('Solicitar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );
}