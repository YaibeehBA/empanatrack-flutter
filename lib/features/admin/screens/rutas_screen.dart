
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colores.dart';
import '../providers/rutas_admin_provider.dart';
import '../providers/admin_provider.dart';

// ══════════════════════════════════════════════════════════
//  COLOR ÚNICO DE RUTA
// ══════════════════════════════════════════════════════════
const _colorRuta   = Color(0xFF1A73E8); // Azul Google
const _colorInicio = Color(0xFF1E8B3E); // Verde
const _colorFin    = Color(0xFFD32F2F); // Rojo

// ══════════════════════════════════════════════════════════
//  MODELO PARADA
// ══════════════════════════════════════════════════════════
// ignore: unused_element
class _Parada {
  final EmpresaRuta empresa;
  final double      distanciaDesdeAnterior;
  final int         indiceOriginal;
  const _Parada({
    required this.empresa,
    required this.distanciaDesdeAnterior,
    required this.indiceOriginal,
  });
  String get distanciaLabel {
    if (distanciaDesdeAnterior < 1000) {
      return '${distanciaDesdeAnterior.toStringAsFixed(0)} m';
    }
    return '${(distanciaDesdeAnterior / 1000).toStringAsFixed(1)} km';
  }
}

// ══════════════════════════════════════════════════════════
//  RUTAS ADMIN SCREEN
// ══════════════════════════════════════════════════════════
class RutasAdminScreen extends ConsumerWidget {
  const RutasAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rutasAdminProvider);
    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Rutas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.add),
            onPressed: () => _mostrarFormRuta(context, ref, null),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error al cargar rutas'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(rutasAdminProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (rutas) => rutas.isEmpty
            ? _Vacio(onAgregar: () => _mostrarFormRuta(context, ref, null))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(rutasAdminProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rutas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CardRuta(
                    ruta:       rutas[i],
                    onEditar:   () => _mostrarFormRuta(context, ref, rutas[i]),
                    onEliminar: () => _confirmarEliminar(context, ref, rutas[i]),
                    onDetalle:  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _DetalleRutaScreen(rutaId: rutas[i].id),
                      ),
                    ).then((_) => ref.invalidate(rutasAdminProvider)),
                  ),
                ),
              ),
      ),
    );
  }

  void _mostrarFormRuta(BuildContext context, WidgetRef ref, RutaAdmin? ruta) {
    final nombreCtrl = TextEditingController(text: ruta?.nombre ?? '');
    final descCtrl   = TextEditingController(text: ruta?.descripcion ?? '');
    bool estaActiva  = ruta?.estaActiva ?? true;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
              MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ruta == null ? 'Nueva ruta' : 'Editar ruta',
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
              const SizedBox(height: 20),
              TextField(controller: nombreCtrl,
                decoration: InputDecoration(labelText: 'Nombre de la ruta *',
                  prefixIcon: const Icon(Icons.route),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: AppColores.background)),
              const SizedBox(height: 14),
              TextField(controller: descCtrl, maxLines: 2,
                decoration: InputDecoration(labelText: 'Descripción (opcional)',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: AppColores.background)),
              if (ruta != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: estaActiva, onChanged: (v) => setS(() => estaActiva = v),
                  title: const Text('Ruta activa'),
                  activeColor: AppColores.success, contentPadding: EdgeInsets.zero),
              ],
              const SizedBox(height: 20),
              Consumer(builder: (ctx2, ref2, _) {
                final state = ref2.watch(rutaOpProvider);
                ref2.listen<RutaOpState>(rutaOpProvider, (_, next) {
                  if (next.exitoso) {
                    Navigator.pop(ctx2);
                    ref.invalidate(rutasAdminProvider);
                    ref2.read(rutaOpProvider.notifier).resetear();
                  }
                  if (next.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(next.error!),
                        backgroundColor: AppColores.danger));
                    ref2.read(rutaOpProvider.notifier).resetear();
                  }
                });
                return SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: state.cargando ? null : () {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      if (ruta == null) {
                        ref2.read(rutaOpProvider.notifier).crearRuta({
                          'nombre': nombre,
                          'descripcion': descCtrl.text.trim().isEmpty
                              ? null : descCtrl.text.trim()});
                      } else {
                        ref2.read(rutaOpProvider.notifier).editarRuta(ruta.id, {
                          'nombre': nombre,
                          'descripcion': descCtrl.text.trim().isEmpty
                              ? null : descCtrl.text.trim(),
                          'esta_activa': estaActiva});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: state.cargando
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(ruta == null ? 'Crear ruta' : 'Guardar cambios',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, RutaAdmin ruta) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar ruta'),
      content: Text('¿Eliminar "${ruta.nombre}"? Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ref.read(rutaOpProvider.notifier).eliminarRuta(ruta.id);
            ref.invalidate(rutasAdminProvider);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.danger, foregroundColor: Colors.white),
          child: const Text('Eliminar'),
        ),
      ],
    ));
  }
}

// ══════════════════════════════════════════════════════════
//  CARD RUTA
// ══════════════════════════════════════════════════════════
class _CardRuta extends StatelessWidget {
  final RutaAdmin ruta;
  final VoidCallback onEditar, onEliminar, onDetalle;
  const _CardRuta({required this.ruta, required this.onEditar,
      required this.onEliminar, required this.onDetalle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetalle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColores.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('🗺️', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ruta.nombre, style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 16, color: AppColores.textPrimary)),
              if (ruta.descripcion != null)
                Text(ruta.descripcion!, style: const TextStyle(
                    fontSize: 12, color: AppColores.textSecond)),
            ])),
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'editar') onEditar(); if (v == 'eliminar') onEliminar(); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar',
                    child: Row(children: [Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8), Text('Editar')])),
                const PopupMenuItem(value: 'eliminar',
                    child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _Chip(icono: Icons.business_outlined,
                texto: '${ruta.empresas.length} empresas', color: AppColores.accent),
            const SizedBox(width: 8),
            _Chip(icono: Icons.person_outline,
                texto: '${ruta.asignaciones.length} vendedores', color: AppColores.primary),
            const SizedBox(width: 8),
            _Chip(icono: ruta.estaActiva
                ? Icons.check_circle_outline : Icons.cancel_outlined,
                texto: ruta.estaActiva ? 'Activa' : 'Inactiva',
                color: ruta.estaActiva ? AppColores.success : AppColores.danger),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icono; final String texto; final Color color;
  const _Chip({required this.icono, required this.texto, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 13, color: color), const SizedBox(width: 4),
      Text(texto, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  DETALLE RUTA
// ══════════════════════════════════════════════════════════
class _DetalleRutaScreen extends ConsumerStatefulWidget {
  final String rutaId;
  const _DetalleRutaScreen({required this.rutaId});
  @override
  ConsumerState<_DetalleRutaScreen> createState() => _DetalleRutaScreenState();
}

class _DetalleRutaScreenState extends ConsumerState<_DetalleRutaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }
  void _recargar() {
  ref.invalidate(rutaDetalleProvider(widget.rutaId));
  ref.invalidate(rutaCalculadaProvider(widget.rutaId)); // ← agrega esta línea
}

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rutaDetalleProvider(widget.rutaId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Error al cargar la ruta'))),
      data: (ruta) => Scaffold(
        backgroundColor: AppColores.background,
        appBar: AppBar(
          backgroundColor: AppColores.primary, foregroundColor: Colors.white,
          title: Text(ruta.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabCtrl, indicatorColor: Colors.white,
            labelColor: Colors.white, unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.business), text: 'Empresas'),
              Tab(icon: Icon(Icons.people),   text: 'Vendedores'),
              Tab(icon: Icon(Icons.map),      text: 'Mapa'),
            ],
          ),
        ),
        body: TabBarView(controller: _tabCtrl, children: [
          _TabEmpresas(ruta: ruta, onRecargar: _recargar),
          _TabVendedores(ruta: ruta, onRecargar: _recargar),
          _TabMapa(ruta: ruta),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB EMPRESAS
// ══════════════════════════════════════════════════════════
class _TabEmpresas extends ConsumerWidget {
  final RutaAdmin ruta; final VoidCallback onRecargar;
  const _TabEmpresas({required this.ruta, required this.onRecargar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColores.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarSelector(context, ref),
        backgroundColor: AppColores.primary, foregroundColor: Colors.white,
        icon: const Icon(Icons.business_center), label: const Text('Gestionar empresas'),
      ),
      body: ruta.empresas.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🏢', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
              Text('Sin empresas en esta ruta', style: TextStyle(color: AppColores.textSecond))]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: ruta.empresas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CardEmpresaRuta(
                  empresa: ruta.empresas[i], numero: i + 1, onRecargar: onRecargar)),
    );
  }

  void _mostrarSelector(BuildContext context, WidgetRef ref) async {
    final todas = await ref.read(empresasAdminProvider.future);
    if (!context.mounted) return;
    final sel = Set<String>.from(ruta.empresas.map((e) => e.id));
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SelectorEmpresasSheet(
        todas: todas, seleccionadas: sel,
        onGuardar: (ids) async {
          await ref.read(rutaOpProvider.notifier).actualizarEmpresas(ruta.id, ids);
          ref.invalidate(rutaCalculadaProvider(ruta.id));
          onRecargar();
        },
      ),
    );
  }
}

class _CardEmpresaRuta extends ConsumerWidget {
  final EmpresaRuta empresa; final int numero; final VoidCallback onRecargar;
  const _CardEmpresaRuta({required this.empresa, required this.numero, required this.onRecargar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: AppColores.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$numero', style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColores.primary)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(empresa.nombre, style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
          if (empresa.direccion != null)
            Text(empresa.direccion!, style: const TextStyle(
                fontSize: 12, color: AppColores.textSecond)),
        ])),
        empresa.tieneCoordenadas
            ? const Icon(Icons.location_on, color: AppColores.success, size: 20)
            : IconButton(icon: const Icon(Icons.location_off, color: AppColores.danger, size: 20),
                tooltip: 'Sin coordenadas',
                onPressed: () => _mostrarFormCoordenadas(context, ref)),
      ]),
    );
  }

  void _mostrarFormCoordenadas(BuildContext context, WidgetRef ref) {
    final latCtrl = TextEditingController(text: empresa.latitud?.toString() ?? '');
    final lngCtrl = TextEditingController(text: empresa.longitud?.toString() ?? '');
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('GPS: ${empresa.nombre}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: latCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: 'Latitud (-90 a 90)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 12),
        TextField(controller: lngCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: 'Longitud (-180 a 180)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        Consumer(builder: (ctx, ref2, _) => ElevatedButton(
          onPressed: () async {
            final lat = double.tryParse(latCtrl.text);
            final lng = double.tryParse(lngCtrl.text);
            if (lat == null || lng == null) return;
            await ref2.read(rutaOpProvider.notifier).actualizarCoordenadas(empresa.id, lat, lng);
            if (ctx.mounted) { Navigator.pop(ctx); onRecargar(); }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary, foregroundColor: Colors.white),
          child: const Text('Guardar'),
        )),
      ],
    ));
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTOR EMPRESAS
// ══════════════════════════════════════════════════════════
class _SelectorEmpresasSheet extends StatefulWidget {
  final List<EmpresaAdmin> todas;
  final Set<String> seleccionadas;
  final Future Function(List<String>) onGuardar;
  const _SelectorEmpresasSheet({required this.todas,
      required this.seleccionadas, required this.onGuardar});
  @override
  State<_SelectorEmpresasSheet> createState() => _SelectorEmpresasSheetState();
}

class _SelectorEmpresasSheetState extends State<_SelectorEmpresasSheet> {
  late Set<String> _sel;
  String _busqueda = '';
  bool   _cargando = false;
  @override
  void initState() { super.initState(); _sel = Set.from(widget.seleccionadas); }

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.todas
        .where((e) => e.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('Selecciona empresas', style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
          const Spacer(),
          Text('${_sel.length} selec.', style: const TextStyle(
              color: AppColores.primary, fontWeight: FontWeight.w600)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: AppColores.background))),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(
          itemCount: filtradas.length,
          itemBuilder: (_, i) {
            final e = filtradas[i];
            final sel = _sel.contains(e.id.toString());
            return CheckboxListTile(
              value: sel,
              onChanged: (v) => setState(() {
                if (v == true) _sel.add(e.id.toString());
                else _sel.remove(e.id.toString());
              }),
              title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: e.direccion != null
                  ? Text(e.direccion!, style: const TextStyle(fontSize: 12)) : null,
              activeColor: AppColores.primary,
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        )),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _cargando ? null : () async {
                setState(() => _cargando = true);
                await widget.onGuardar(_sel.toList());
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _cargando
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar selección',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB VENDEDORES
// ══════════════════════════════════════════════════════════
class _TabVendedores extends ConsumerWidget {
  final RutaAdmin ruta; final VoidCallback onRecargar;
  const _TabVendedores({required this.ruta, required this.onRecargar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColores.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarAsignar(context, ref),
        backgroundColor: AppColores.primary, foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add), label: const Text('Asignar vendedor'),
      ),
      body: ruta.asignaciones.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('👤', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
              Text('Sin vendedores asignados',
                  style: TextStyle(color: AppColores.textSecond))]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: ruta.asignaciones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CardAsignacion(
                asignacion: ruta.asignaciones[i],
                onEliminar: () async {
                  await ref.read(rutaOpProvider.notifier)
                      .eliminarAsignacion(ruta.asignaciones[i].id);
                  onRecargar();
                },
              )),
    );
  }

  void _mostrarAsignar(BuildContext context, WidgetRef ref) {
    String? vendedorSelec;
    String turnoSelec = 'unica';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final vendedoresAsync = ref.watch(vendedoresAdminProvider);
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
              MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Asignar vendedor', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
            const SizedBox(height: 20),
            vendedoresAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error cargando vendedores'),
              data: (vendedores) => DropdownButtonFormField<String>(
                value: vendedorSelec, hint: const Text('Selecciona un vendedor'),
                onChanged: (v) => setS(() => vendedorSelec = v),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: AppColores.background),
                items: vendedores.where((v) => v.estaActivo).map((v) =>
                    DropdownMenuItem(value: v.id.toString(), child: Text(v.nombreCompleto))).toList(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Turno', style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              _BtnTurno(label: '🌅 Mañana', valor: 'mañana',
                  seleccionado: turnoSelec == 'mañana',
                  onTap: () => setS(() => turnoSelec = 'mañana')),
              const SizedBox(width: 8),
              _BtnTurno(label: '🌇 Tarde', valor: 'tarde',
                  seleccionado: turnoSelec == 'tarde',
                  onTap: () => setS(() => turnoSelec = 'tarde')),
              const SizedBox(width: 8),
              _BtnTurno(label: '🕐 Única', valor: 'unica',
                  seleccionado: turnoSelec == 'unica',
                  onTap: () => setS(() => turnoSelec = 'unica')),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: vendedorSelec == null ? null : () async {
                  await ref.read(rutaOpProvider.notifier)
                      .asignarVendedor(ruta.id, vendedorSelec!, turnoSelec);
                  if (ctx.mounted) Navigator.pop(ctx);
                  onRecargar();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Asignar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _CardAsignacion extends StatelessWidget {
  final AsignacionRuta asignacion; final VoidCallback onEliminar;
  const _CardAsignacion({required this.asignacion, required this.onEliminar});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Row(children: [
      CircleAvatar(backgroundColor: AppColores.primary.withOpacity(0.12),
        child: Text(asignacion.nombre[0].toUpperCase(),
            style: const TextStyle(color: AppColores.primary, fontWeight: FontWeight.bold))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(asignacion.nombre, style: const TextStyle(
            fontWeight: FontWeight.bold, color: AppColores.textPrimary)),
        Text(asignacion.turnoLabel, style: const TextStyle(
            fontSize: 12, color: AppColores.textSecond)),
      ])),
      IconButton(icon: const Icon(Icons.delete_outline, color: AppColores.danger),
          onPressed: onEliminar),
    ]),
  );
}

class _BtnTurno extends StatelessWidget {
  final String label, valor; final bool seleccionado; final VoidCallback onTap;
  const _BtnTurno({required this.label, required this.valor,
      required this.seleccionado, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? AppColores.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: seleccionado ? AppColores.primary : Colors.grey.shade300)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: seleccionado ? Colors.white : AppColores.textSecond)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  TAB MAPA - SIMPLIFICADO
//  Ahora solo renderiza usando el provider rutaCalculadaProvider
// ══════════════════════════════════════════════════════════
class _TabMapa extends ConsumerWidget {
  final RutaAdmin ruta;
  const _TabMapa({required this.ruta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rutaCalculadaProvider(ruta.id));

    return async.when(
      loading: () => const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Calculando ruta óptima...',
              style: TextStyle(color: AppColores.textSecond)),
        ],
      )),
      error: (e, _) => Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No se pudo calcular la ruta',
              style: TextStyle(color: AppColores.textSecond)),
          const SizedBox(height: 8),
          Text(e.toString().contains('coordenadas')
              ? 'Agrega coordenadas GPS a las empresas'
              : 'Verifica tu conexión a internet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColores.textSecond)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(rutaCalculadaProvider(ruta.id)),
            icon:  const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primary,
                foregroundColor: Colors.white),
          ),
        ],
      )),
      data: (calculada) => _MapaRenderizado(
        ruta:      ruta,
        calculada: calculada,
        onRecargar: () => ref.invalidate(rutaCalculadaProvider(ruta.id)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MAPA RENDERIZADO — solo dibuja, sin lógica de cálculo
// ══════════════════════════════════════════════════════════
class _MapaRenderizado extends StatefulWidget {
  final RutaAdmin     ruta;
  final RutaCalculada calculada;
  final VoidCallback  onRecargar;
  const _MapaRenderizado({
    required this.ruta,
    required this.calculada,
    required this.onRecargar,
  });

  @override
  State<_MapaRenderizado> createState() => _MapaRenderizadoState();
}

class _MapaRenderizadoState extends State<_MapaRenderizado> {
  final _mapCtrl   = MapController();
  final _panelCtrl = DraggableScrollableController();
  int?  _paradaActiva;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ajustarZoom());
  }

  @override
  void dispose() { _panelCtrl.dispose(); super.dispose(); }

  void _ajustarZoom() {
    final pts = widget.calculada.paradas
        .map((p) => LatLng(p.latitud, p.longitud))
        .toList();
    if (pts.isEmpty) return;

    double minLat = pts.first.latitude,  maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapCtrl.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(minLat - 0.001, minLng - 0.001),
        LatLng(maxLat + 0.001, maxLng + 0.001),
      ),
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 220),
    ));
  }

  Color _colorMarcador(int i) {
    if (i == 0) return _colorInicio;
    if (i == widget.calculada.paradas.length - 1) return _colorFin;
    return _colorRuta;
  }

  @override
  Widget build(BuildContext context) {
    final calculada = widget.calculada;
    final puntosLatLng = calculada.puntosPolilinea
        .map((p) => LatLng(p.latitud, p.longitud))
        .toList();

    final centro = calculada.paradas.isEmpty
        ? const LatLng(0, 0)
        : LatLng(
            calculada.paradas
                    .map((p) => p.latitud)
                    .reduce((a, b) => a + b) /
                calculada.paradas.length,
            calculada.paradas
                    .map((p) => p.longitud)
                    .reduce((a, b) => a + b) /
                calculada.paradas.length,
          );

    return Stack(children: [

      // ── MAPA ────────────────────────────────────────
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: centro,
          initialZoom:   15,
          onMapReady:    _ajustarZoom,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.empanatrack.app',
          ),

          // Borde blanco para visibilidad
          if (puntosLatLng.isNotEmpty)
            PolylineLayer(polylines: [
              Polyline(
                points:      puntosLatLng,
                color:       Colors.white,
                strokeWidth: 8,
                strokeCap:   StrokeCap.round,
                strokeJoin:  StrokeJoin.round,
              ),
            ]),

          // Ruta principal
          if (puntosLatLng.isNotEmpty)
            PolylineLayer(polylines: [
              Polyline(
                points:      puntosLatLng,
                color:       _colorRuta,
                strokeWidth: 5,
                strokeCap:   StrokeCap.round,
                strokeJoin:  StrokeJoin.round,
              ),
            ]),

          // Marcadores
          MarkerLayer(
            markers: calculada.paradas.asMap().entries.map((entry) {
              final i      = entry.key;
              final p      = entry.value;
              final activo = _paradaActiva == i;
              final color  = _colorMarcador(i);
              final sz     = activo ? 42.0 : 34.0;

              return Marker(
                point:  LatLng(p.latitud, p.longitud),
                width:  sz + 10,
                height: sz + 14,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _paradaActiva = i);
                    _mapCtrl.move(LatLng(p.latitud, p.longitud), 17);
                  },
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        color:  color, shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: activo ? 3 : 2.5),
                        boxShadow: [BoxShadow(
                            color: color.withOpacity(activo ? 0.5 : 0.25),
                            blurRadius: activo ? 10 : 4,
                            spreadRadius: activo ? 2 : 0,
                            offset: const Offset(0, 2))],
                      ),
                      child: Center(child: p.esInicio
                          ? Icon(Icons.play_arrow,
                              color: Colors.white, size: activo ? 22 : 18)
                          : p.esFin
                              ? Icon(Icons.flag,
                                  color: Colors.white, size: activo ? 20 : 16)
                              : Text('${i + 1}', style: TextStyle(
                                  color: Colors.white,
                                  fontSize: activo ? 15 : 12,
                                  fontWeight: FontWeight.bold))),
                    ),
                    CustomPaint(
                      size: Size(activo ? 12 : 9, activo ? 9 : 6),
                      painter: _PinPainter(color),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),

      // ── PANEL DESLIZABLE ────────────────────────────
      DraggableScrollableSheet(
        controller:       _panelCtrl,
        initialChildSize: 0.22,
        minChildSize:     0.12,
        maxChildSize:     0.70,
        snap:             true,
        snapSizes:        const [0.12, 0.22, 0.70],
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(
                color: Colors.black26, blurRadius: 12,
                offset: Offset(0, -2))],
          ),
          child: ListView(
            controller: scrollCtrl,
            padding:    EdgeInsets.zero,
            children: [
              // Handle
              Center(child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),

              // Resumen
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: AppColores.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('🚶',
                        style: TextStyle(fontSize: 22)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.ruta.nombre, style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15,
                          color: AppColores.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _ResumenChip(icono: Icons.route,
                            texto: calculada.distanciaLabel,
                            color: AppColores.primary),
                        const SizedBox(width: 6),
                        _ResumenChip(icono: Icons.access_time,
                            texto: calculada.tiempoLabel,
                            color: _colorRuta),
                        const SizedBox(width: 6),
                        _ResumenChip(icono: Icons.location_on,
                            texto: '${calculada.paradas.length} paradas',
                            color: _colorInicio),
                      ]),
                    ],
                  )),
                  IconButton(
                    onPressed: widget.onRecargar,
                    icon: const Icon(Icons.refresh, color: AppColores.primary),
                    tooltip: 'Recalcular',
                  ),
                ]),
              ),

              // Badge fuente
              if (calculada.fuente == 'haversine')
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:        AppColores.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColores.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_off,
                        color: AppColores.warning, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(child: Text(
                        'Sin conexión — distancias en línea recta',
                        style: TextStyle(
                            fontSize: 12, color: AppColores.warning))),
                    TextButton(
                      onPressed: widget.onRecargar,
                      child: const Text('Reintentar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),

              // Lista de paradas
              if (calculada.paradas.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(children: [
                    const Text('ORDEN DE VISITA', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: AppColores.textSecond, letterSpacing: 1.0)),
                    const Spacer(),
                    Text(
                      calculada.fuente == 'osrm'
                          ? 'Ruta optimizada ✓' : 'Orden aproximado',
                      style: TextStyle(
                        fontSize: 11,
                        color: calculada.fuente == 'osrm'
                            ? _colorRuta : AppColores.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),

                ...calculada.paradas.asMap().entries.map((entry) {
                  final i      = entry.key;
                  final p      = entry.value;
                  final activo = _paradaActiva == i;

                  return _FilaParada(
                    parada: p, numero: i + 1,
                    esInicio: p.esInicio, esFin: p.esFin,
                    esUltima: p.esFin,   activo: activo,
                    onTap: () {
                      setState(() => _paradaActiva = i);
                      _mapCtrl.move(LatLng(p.latitud, p.longitud), 17);
                      _panelCtrl.animateTo(0.22,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    },
                  );
                }),

                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════
//  CHIP RESUMEN
// ══════════════════════════════════════════════════════════
class _ResumenChip extends StatelessWidget {
  final IconData icono; final String texto; final Color color;
  const _ResumenChip(
      {required this.icono, required this.texto, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 12, color: color), const SizedBox(width: 3),
      Text(texto, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  FILA DE PARADA
// ══════════════════════════════════════════════════════════
class _FilaParada extends StatelessWidget {
  final ParadaRuta parada; final int numero;
  final bool esInicio, esFin, esUltima, activo;
  final VoidCallback onTap;
  const _FilaParada({
    required this.parada,   required this.numero,
    required this.esInicio, required this.esFin,
    required this.esUltima, required this.activo,
    required this.onTap,
  });

  Color get _c =>
      esInicio ? _colorInicio : esFin ? _colorFin : _colorRuta;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: activo ? _c.withOpacity(0.07) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            SizedBox(width: 32, child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: activo ? 32 : 28, height: activo ? 32 : 28,
                decoration: BoxDecoration(
                  color: _c, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                      color: _c.withOpacity(activo ? 0.4 : 0.15),
                      blurRadius: activo ? 8 : 3)],
                ),
                child: Center(child: esInicio
                    ? Icon(Icons.play_arrow,
                        color: Colors.white, size: activo ? 16 : 14)
                    : esFin
                        ? Icon(Icons.flag,
                            color: Colors.white, size: activo ? 15 : 13)
                        : Text('$numero', style: TextStyle(
                            color: Colors.white,
                            fontSize: activo ? 13 : 11,
                            fontWeight: FontWeight.bold))),
              ),
              if (!esUltima)
                Container(
                  width: 2.5, height: 52,
                  decoration: BoxDecoration(
                      color: _colorRuta.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(2)),
                ),
            ])),

            const SizedBox(width: 12),

            Expanded(child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(parada.nombre,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: activo ? _c : AppColores.textPrimary))),
                  if (numero > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _colorRuta.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.directions_walk,
                            size: 11, color: _colorRuta),
                        const SizedBox(width: 3),
                        Text(parada.distanciaLabel, style: const TextStyle(
                            fontSize: 11, color: _colorRuta,
                            fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
                if (parada.direccion != null) ...[
                  const SizedBox(height: 2),
                  Text(parada.direccion!, style: const TextStyle(
                      fontSize: 12, color: AppColores.textSecond)),
                ],
                if (esInicio || esFin) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                        esInicio ? '🟢 Punto de inicio' : '🔴 Punto final',
                        style: TextStyle(fontSize: 10, color: _c,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            )),

            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(Icons.chevron_right, size: 18,
                  color: activo ? _c : AppColores.textSecond),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Pin personalizado ──────────────────────────────────────
class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════
//  VACÍO
// ══════════════════════════════════════════════════════════
class _Vacio extends StatelessWidget {
  final VoidCallback onAgregar;
  const _Vacio({required this.onAgregar});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🗺️', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('Sin rutas creadas', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: AppColores.textPrimary)),
      const SizedBox(height: 8),
      const Text('Crea tu primera ruta de entrega',
          style: TextStyle(color: AppColores.textSecond)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAgregar,
        icon: const Icon(Icons.add),
        label: const Text('Nueva ruta'),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      ),
    ]),
  );
}