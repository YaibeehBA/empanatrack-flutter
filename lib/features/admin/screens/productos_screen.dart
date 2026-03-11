import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
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
        label: const Text('Nuevo Producto',
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
                  producto:      lista[i],
                  onEditar:      () => _form(context, ref, producto: lista[i]),
                  onSubirImagen: () => _subirImagen(context, ref, lista[i]),
                  onEliminar:    () => _confirmarEliminar(context, ref, lista[i]),
                ),
              ),
      ),
    );
  }

  // ── Formulario crear / editar ────────────────────────────
  void _form(BuildContext ctx, WidgetRef ref, {ProductoAdmin? producto}) {
    ref.read(adminOpProvider.notifier).resetear();
    showModalBottomSheet(
      context:            ctx,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (modalCtx) => _FormProducto(
        producto:  producto,
        onGuardar: (datos, imagen) async {
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
          // Si seleccionó imagen nueva, subirla después de crear/editar
          if (imagen != null) {
            final idProducto = producto?.id ??
                ref.read(adminOpProvider).ultimoId;
            if (idProducto != null) {
              await ref.read(adminOpProvider.notifier)
                  .subirImagenProducto(idProducto, imagen);
            }
          }
          ref.invalidate(productosAdminProvider);
          ref.invalidate(productosProvider);
          if (modalCtx.mounted) Navigator.pop(modalCtx);
        },
      ),
    );
  }

  // ── Subir imagen desde la card ───────────────────────────
  Future<void> _subirImagen(
      BuildContext ctx, WidgetRef ref, ProductoAdmin producto) async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context:         ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Seleccionar imagen',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _OpcionImagen(
                  icono:    Icons.camera_alt_outlined,
                  etiqueta: 'Cámara',
                  onTap:    () => Navigator.pop(ctx, ImageSource.camera),
                )),
                const SizedBox(width: 12),
                Expanded(child: _OpcionImagen(
                  icono:    Icons.photo_library_outlined,
                  etiqueta: 'Galería',
                  onTap:    () => Navigator.pop(ctx, ImageSource.gallery),
                )),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (fuente == null) return;

    final imagen = await ImagePicker().pickImage(
      source:       fuente,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (imagen == null) return;

    await ref.read(adminOpProvider.notifier)
        .subirImagenProducto(producto.id, imagen);

    final state = ref.read(adminOpProvider);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(state.error ?? '✅ Imagen actualizada'),
        backgroundColor:
            state.error != null ? Colors.red : AppColores.success,
      ));
      if (state.error == null) ref.invalidate(productosAdminProvider);
    }
  }

  // ── Confirmar eliminar ───────────────────────────────────
  Future<void> _confirmarEliminar(
      BuildContext ctx, WidgetRef ref, ProductoAdmin producto) async {
    final confirmar = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto'),
        content: Text(
            '¿Eliminar "${producto.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await ref.read(adminOpProvider.notifier)
        .eliminarProducto(producto.id);

    final state = ref.read(adminOpProvider);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(state.error ?? '🗑️ Producto eliminado'),
        backgroundColor:
            state.error != null ? Colors.red : AppColores.textSecond,
      ));
      if (state.error == null) {
        ref.invalidate(productosAdminProvider);
        ref.invalidate(productosProvider);
      }
    }
  }
}

// ── Opción imagen ─────────────────────────────────────────
class _OpcionImagen extends StatelessWidget {
  final IconData     icono;
  final String       etiqueta;
  final VoidCallback onTap;
  const _OpcionImagen({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color:        AppColores.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icono, color: AppColores.primary, size: 32),
            const SizedBox(height: 8),
            Text(etiqueta, style: const TextStyle(
              color:      AppColores.primary,
              fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Card producto ─────────────────────────────────────────
class _ProductoCard extends StatelessWidget {
  final ProductoAdmin producto;
  final VoidCallback  onEditar;
  final VoidCallback  onSubirImagen;
  final VoidCallback  onEliminar;

  const _ProductoCard({
    required this.producto,
    required this.onEditar,
    required this.onSubirImagen,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneImagen =
        producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty;

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

          // ── Miniatura ──────────────────────────────
          GestureDetector(
            onTap: onSubirImagen,
            child: Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color:        AppColores.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: tieneImagen
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            '${ApiClient.baseUrl}${producto.imagenUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🫓',
                                  style: TextStyle(fontSize: 24)),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text('🫓',
                              style: TextStyle(fontSize: 24)),
                        ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color:        AppColores.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Info ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColores.textPrimary)),
                Text('\$${producto.precio.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                        color: AppColores.accent, fontSize: 13)),
              ],
            ),
          ),

          // ── Badge ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: producto.estaActivo
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
          const SizedBox(width: 4),

          // ── Editar ─────────────────────────────────
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColores.textSecond),
            onPressed: onEditar,
          ),

          // ── Eliminar ───────────────────────────────
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red),
            onPressed: onEliminar,
          ),
        ],
      ),
    );
  }
}

// ── Formulario ────────────────────────────────────────────
class _FormProducto extends StatefulWidget {
  final ProductoAdmin?                          producto;
  final Function(Map<String, dynamic>, XFile?)  onGuardar;
  const _FormProducto({this.producto, required this.onGuardar});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  late final _nombreCtrl =
      TextEditingController(text: widget.producto?.nombre);
  late final _precioCtrl = TextEditingController(
      text: widget.producto?.precio.toStringAsFixed(2) ?? '');
  bool   _estaActivo = true;
  bool   _cargando   = false;
  XFile? _imagenSeleccionada;

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

  Future<void> _seleccionarImagen() async {
    final imagen = await ImagePicker().pickImage(
      source:       ImageSource.gallery,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (imagen != null) setState(() => _imagenSeleccionada = imagen);
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    final precio = double.tryParse(_precioCtrl.text);
    if (precio == null || precio <= 0) return;
    setState(() => _cargando = true);
    await widget.onGuardar(
      {
        'nombre':      _nombreCtrl.text.trim(),
        'precio':      precio,
        'esta_activo': _estaActivo,
      },
      _imagenSeleccionada,
    );
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion  = widget.producto != null;
    final tieneImgRed = widget.producto?.imagenUrl != null &&
        widget.producto!.imagenUrl!.isNotEmpty;

    return BottomForm(
      titulo:    esEdicion ? 'Editar Producto' : 'Nuevo Producto',
      cargando:  _cargando,
      onGuardar: _guardar,
      btnLabel:  esEdicion ? 'Guardar cambios' : 'Crear producto',
      children: [

        // ── Preview imagen ────────────────────────
        GestureDetector(
          onTap: _seleccionarImagen,
          child: Container(
            height:      120,
            decoration: BoxDecoration(
              color:        AppColores.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColores.primary.withOpacity(0.30),
              ),
            ),
            child: _imagenSeleccionada != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagenSeleccionada!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : tieneImgRed
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${ApiClient.baseUrl}${widget.producto!.imagenUrl}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderImagen(esEdicion: esEdicion),
                        ),
                      )
                    : _PlaceholderImagen(esEdicion: esEdicion),
          ),
        ),
        const SizedBox(height: 12),

        // ── Nombre ────────────────────────────────
        AdminInput(
          ctrl:  _nombreCtrl,
          label: 'Nombre del producto *',
          icono: Icons.fastfood_outlined,
        ),
        const SizedBox(height: 12),

        // ── Precio ────────────────────────────────
        AdminInput(
          ctrl:    _precioCtrl,
          label:   'Precio *',
          icono:   Icons.attach_money,
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),

        // ── Switch activo (solo edición) ──────────
        if (esEdicion) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value:          _estaActivo,
            onChanged:      (v) => setState(() => _estaActivo = v),
            title:          const Text('Producto activo'),
            subtitle: const Text('Los inactivos no aparecen en ventas'),
            activeColor:    AppColores.success,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

// ── Placeholder imagen ────────────────────────────────────
class _PlaceholderImagen extends StatelessWidget {
  final bool esEdicion;
  const _PlaceholderImagen({required this.esEdicion});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: AppColores.primary.withOpacity(0.50), size: 36),
        const SizedBox(height: 6),
        Text(
          esEdicion ? 'Toca para cambiar imagen' : 'Toca para agregar imagen',
          style: TextStyle(
            color:    AppColores.textSecond,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}