import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../ventas/providers/productos_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_form_widgets.dart';   

class ProductosScreen extends ConsumerWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(productosAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Productos',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       () => _form(context, ref),
        backgroundColor: AppColores.success,
        foregroundColor: Colors.white,
        icon:            const Icon(Icons.add),
        label:           const Text('Nuevo Producto',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => const Center(child: Text('Error cargando')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('No hay productos.'))
            : ListView.builder(
                padding:     const EdgeInsets.all(16),
                itemCount:   lista.length,
                itemBuilder: (ctx, i) => _ProductoCard(
                  producto: lista[i],
                  onEditar: () => _form(context, ref, producto: lista[i]),
                ),
              ),
      ),
    );
  }

void _form(BuildContext ctx, WidgetRef ref, {ProductoAdmin? producto}) {
  ref.read(adminOpProvider.notifier).resetear();

  showModalBottomSheet(
    context:            ctx,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (modalCtx) => _FormProducto(
      producto:  producto,
      onGuardar: (datos) async {
        if (producto == null) {
          await ref.read(adminOpProvider.notifier).crearProducto(datos);
        } else {
          await ref.read(adminOpProvider.notifier)
              .editarProducto(producto.id, datos);
        }
        final state = ref.read(adminOpProvider);
        if (state.error != null) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content:         Text(state.error!),
              backgroundColor: Colors.red,
            ));
          }
          return;
        }
        ref.invalidate(productosAdminProvider);
        ref.invalidate(productosProvider);
        if (modalCtx.mounted) Navigator.pop(modalCtx);
      },
    ),
  );
}
}

// ── Card de producto ───────────────────────────────────────
class _ProductoCard extends StatelessWidget {
  final ProductoAdmin producto;
  final VoidCallback  onEditar;
  const _ProductoCard({required this.producto, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              color:        AppColores.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🫓', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto.nombre, style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary,
                )),
                Text(
                  '\$${producto.precio.toStringAsFixed(2)} c/u',
                  style: const TextStyle(
                    color: AppColores.accent, fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        producto.estaActivo
                  ? AppColores.success.withOpacity(0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              producto.estaActivo ? 'Activo' : 'Inactivo',
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.bold,
                color:      producto.estaActivo
                    ? AppColores.success
                    : AppColores.textSecond,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon:      const Icon(Icons.edit_outlined,
                color: AppColores.textSecond),
            onPressed: onEditar,
          ),
        ],
      ),
    );
  }
}

// ── Formulario producto ────────────────────────────────────
class _FormProducto extends StatefulWidget {
  final ProductoAdmin?                 producto;
  final Function(Map<String, dynamic>) onGuardar;
  const _FormProducto({this.producto, required this.onGuardar});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  late final _nombreCtrl =
      TextEditingController(text: widget.producto?.nombre);
  late final _precioCtrl = TextEditingController(
      text: widget.producto?.precio.toStringAsFixed(2) ?? '');
  bool _estaActivo = true;
  bool _cargando   = false;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) _estaActivo = widget.producto!.estaActivo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    final precio = double.tryParse(_precioCtrl.text);
    if (precio == null || precio <= 0) return;
    setState(() => _cargando = true);
    await widget.onGuardar({
      'nombre':      _nombreCtrl.text.trim(),
      'precio':      precio,
      'esta_activo': _estaActivo,
    });
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.producto != null;
    return BottomForm(                          // ← sin guion bajo
      titulo:    esEdicion ? 'Editar Producto' : 'Nuevo Producto',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear producto',
      children: [
        AdminInput(                             // ← sin guion bajo
          ctrl:  _nombreCtrl,
          label: 'Nombre del producto *',
          icono: Icons.fastfood_outlined,
        ),
        const SizedBox(height: 12),
        AdminInput(
          ctrl:    _precioCtrl,
          label:   'Precio *',
          icono:   Icons.attach_money,
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (esEdicion) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value:          _estaActivo,
            onChanged:      (v) => setState(() => _estaActivo = v),
            title:          const Text('Producto activo'),
            subtitle:       const Text(
                'Los inactivos no aparecen en ventas'),
            activeColor:    AppColores.success,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}