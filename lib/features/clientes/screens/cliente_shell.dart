import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../providers/pedidos_cliente_provider.dart';
import 'mi_cuenta_screen.dart';
import 'pedidos_cliente_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// ── Provider tab activo cliente ───────────────────────────
final tabActivoClienteProvider = StateProvider<int>((ref) => 0);

// ── Provider empresa del cliente ──────────────────────────
final clienteEmpresaProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final r = await ApiClient.get('/clientes/mi-empresa');
    return r.data as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

// ── Modelo producto ───────────────────────────────────────
class ProductoDisponible {
  final String  id;
  final String  nombre;
  final double  precio;
  final String? descripcion;
  final bool    estaActivo;
  final String? imagenUrl;

  const ProductoDisponible({
    required this.id,
    required this.nombre,
    required this.precio,
    this.descripcion,
    required this.estaActivo,
    this.imagenUrl,
  });

  factory ProductoDisponible.fromJson(Map<String, dynamic> j) =>
      ProductoDisponible(
        id:          j['id'].toString(),
        nombre:      j['nombre'].toString(),
        precio:      (j['precio'] as num).toDouble(),
        descripcion: null,
        estaActivo:  j['esta_activo'] as bool? ?? true,
        imagenUrl:   j['imagen_url'] as String?,
      );
}

// ── Provider productos disponibles ───────────────────────
final productosDisponiblesProvider =
    FutureProvider.autoDispose<List<ProductoDisponible>>((ref) async {
  final response = await ApiClient.get('/productos/disponibles');
  final lista    = response.data as List;
  return lista.map((p) => ProductoDisponible.fromJson(p)).toList();
});

// ══════════════════════════════════════════════════════════
//  SHELL DEL CLIENTE
// ══════════════════════════════════════════════════════════
class ClienteShell extends ConsumerWidget {
  const ClienteShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab     = ref.watch(tabActivoClienteProvider);
    final carrito = ref.watch(carritoProvider);

    final pantallas = const [
      MiCuentaScreen(),
      _ProductosScreen(),
      PedidosClienteScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: tab, children: pantallas),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icono:       Icons.account_circle_outlined,
                  iconoActivo: Icons.account_circle_rounded,
                  label:       'Mi Cuenta',
                  activo:      tab == 0,
                  onTap: () => ref
                      .read(tabActivoClienteProvider.notifier).state = 0,
                ),
                _NavItem(
                  icono:       Icons.storefront_outlined,
                  iconoActivo: Icons.storefront_rounded,
                  label:       'Productos',
                  activo:      tab == 1,
                  badge:       carrito.cantidadTotal > 0
                      ? carrito.cantidadTotal : null,
                  onTap: () => ref
                      .read(tabActivoClienteProvider.notifier).state = 1,
                ),
                _NavItem(
                  icono:       Icons.receipt_long_outlined,
                  iconoActivo: Icons.receipt_long_rounded,
                  label:       'Mis Pedidos',
                  activo:      tab == 2,
                  onTap: () => ref
                      .read(tabActivoClienteProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NAV ITEM con badge
// ══════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final IconData     icono;
  final IconData     iconoActivo;
  final String       label;
  final bool         activo;
  final VoidCallback onTap;
  final int?         badge;

  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.primary.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  activo ? iconoActivo : icono,
                  color: activo
                      ? AppColores.primary : AppColores.textSecond,
                  size: 26,
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4, right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color:  AppColores.danger,
                        shape:  BoxShape.circle,
                      ),
                      child: Text('$badge',
                          style: const TextStyle(
                              color:    Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize:   10,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              color: activo
                  ? AppColores.primary : AppColores.textSecond,
            )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PANTALLA PRODUCTOS CON CARRITO
// ══════════════════════════════════════════════════════════
class _ProductosScreen extends ConsumerWidget {
  const _ProductosScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosDisponiblesProvider);
    final carrito        = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Productos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(productosDisponiblesProvider),
          ),
        ],
      ),

      // ── FAB carrito ──────────────────────────────────
      floatingActionButton: carrito.cantidadTotal > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CarritoScreen()),
              ),
              backgroundColor: AppColores.accent,
              foregroundColor: Colors.white,
              icon:  const Icon(Icons.shopping_cart),
              label: Text(
                '${carrito.cantidadTotal} items  '
                '\$${carrito.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,

      body: productosAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar los productos',
                style: TextStyle(color: AppColores.textSecond)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.invalidate(productosDisponiblesProvider),
              child: const Text('Reintentar'),
            ),
          ],
        )),
        data: (productos) => productos.isEmpty
            ? const _EmptyProductos()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(productosDisponiblesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      16, 16, 16, 100),
                  children: [
                    _BannerInfo(),
                    const SizedBox(height: 16),
                    ...productos.map(
                        (p) => _ProductoCard(producto: p)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BANNER INFORMATIVO
// ══════════════════════════════════════════════════════════
class _BannerInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColores.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColores.primary.withOpacity(0.20)),
      ),
      child: const Row(children: [
        Text('🫓', style: TextStyle(fontSize: 28)),
        SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haz tu pedido',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   14,
                  color:      AppColores.textPrimary,
                )),
            SizedBox(height: 2),
            Text(
              'Agrega productos al carrito y elige '
              'cómo pagar. Te lo llevamos.',
              style: TextStyle(
                  fontSize: 12, color: AppColores.textSecond),
            ),
          ],
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD DE PRODUCTO CON CONTROLES DE CANTIDAD
// ══════════════════════════════════════════════════════════
class _ProductoCard extends ConsumerWidget {
  final ProductoDisponible producto;
  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito   = ref.watch(carritoProvider);
    final cantidad  = carrito.cantidadDeProducto(producto.id);
    final enCarrito = cantidad > 0;

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: enCarrito
            ? Border.all(
                color: AppColores.primary.withOpacity(0.4),
                width: 2)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [

        // Imagen
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color:        AppColores.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: producto.imagenUrl != null &&
                    producto.imagenUrl!.isNotEmpty
                ? Image.network(
                    producto.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InicialWidget(nombre: producto.nombre),
                  )
                : _InicialWidget(nombre: producto.nombre),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(producto.nombre,
                style: const TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary,
                )),
            const SizedBox(height: 4),
            Text(
              '\$${producto.precio.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.bold,
                color:      AppColores.success,
              ),
            ),
          ],
        )),

        // Controles cantidad
        if (!enCarrito)
          GestureDetector(
            onTap: () => ref
                .read(carritoProvider.notifier)
                .agregar(producto),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        AppColores.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add,
                  color: Colors.white, size: 22),
            ),
          )
        else
          Row(children: [
            _BtnQty(
              icono: Icons.remove,
              onTap: () => ref
                  .read(carritoProvider.notifier)
                  .quitar(producto.id),
            ),
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text('$cantidad',
                  style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                    color:      AppColores.primary,
                  )),
            ),
            _BtnQty(
              icono:  Icons.add,
              filled: true,
              onTap: () => ref
                  .read(carritoProvider.notifier)
                  .agregar(producto),
            ),
          ]),
      ]),
    );
  }
}

class _BtnQty extends StatelessWidget {
  final IconData     icono;
  final bool         filled;
  final VoidCallback onTap;
  const _BtnQty({
    required this.icono,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: filled
            ? AppColores.primary
            : AppColores.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icono,
          color: filled ? Colors.white : AppColores.primary,
          size:  18),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  PANTALLA CARRITO
// ══════════════════════════════════════════════════════════
class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Mi Carrito',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (carrito.items.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(carritoProvider.notifier).limpiar();
                Navigator.pop(context);
              },
              child: const Text('Vaciar',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: carrito.items.isEmpty
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🛒', style: TextStyle(fontSize: 60)),
                SizedBox(height: 16),
                Text('Tu carrito está vacío',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppColores.textPrimary)),
              ]))
          : Column(children: [
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: carrito.items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ItemCarritoCard(item: carrito.items[i]),
              )),

              // Total + botón checkout
              Container(
                padding: EdgeInsets.fromLTRB(
                  20, 16, 20,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color:     Colors.white,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4))],
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColores.textPrimary)),
                      Text(
                        '\$${carrito.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          color:      AppColores.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width:  double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const CheckoutScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                      icon:  const Icon(Icons.arrow_forward),
                      label: const Text('Continuar',
                          style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }
}

class _ItemCarritoCard extends ConsumerWidget {
  final ItemCarrito item;
  const _ItemCarritoCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6)],
      ),
      child: Row(children: [
        // Imagen
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color:        AppColores.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.producto.imagenUrl != null
                ? Image.network(
                    item.producto.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InicialWidget(nombre: item.producto.nombre),
                  )
                : _InicialWidget(nombre: item.producto.nombre),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.producto.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColores.textPrimary)),
            Text(
              '\$${item.producto.precio.toStringAsFixed(2)} c/u',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColores.textSecond),
            ),
          ],
        )),

        // Controles
        Row(children: [
          _BtnQty(
            icono: Icons.remove,
            onTap: () => ref
                .read(carritoProvider.notifier)
                .quitar(item.producto.id),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text('${item.cantidad}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: AppColores.primary)),
          ),
          _BtnQty(
            icono:  Icons.add,
            filled: true,
            onTap: () => ref
                .read(carritoProvider.notifier)
                .agregar(item.producto),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref
                .read(carritoProvider.notifier)
                .eliminar(item.producto.id),
            child: const Icon(Icons.delete_outline,
                color: AppColores.danger, size: 22),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PANTALLA CHECKOUT — GPS + TIPO DE PEDIDO  ← PASO 13
// ══════════════════════════════════════════════════════════
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String  _tipoPago      = 'contraentrega';
  String  _tipoPedido    = 'normal';          // ← nuevo
  final   _notasCtrl     = TextEditingController();
  double? _latitud;
  double? _longitud;
  bool    _obteniendoGps = false;

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _obtenerGps() async {
    setState(() => _obteniendoGps = true);
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw Exception('Permiso denegado');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitud  = pos.latitude;
        _longitud = pos.longitude;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación GPS'),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    }
    setState(() => _obteniendoGps = false);
  }

  Future<void> _confirmar() async {
    final carrito = ref.read(carritoProvider);
    if (carrito.items.isEmpty) return;

    if (_latitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor obtén tu ubicación GPS primero'),
          backgroundColor: AppColores.danger,
        ),
      );
      return;
    }

    if (_tipoPago == 'transferencia') {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => const PagoTransferenciaScreen()),
      );
      if (ok != true) return;
    }

    await ref.read(crearPedidoProvider.notifier).crear(
      items:      carrito.items,
      tipoPago:   _tipoPago,
      tipoPedido: _tipoPedido,             // ← nuevo
      latitud:    _latitud,
      longitud:   _longitud,
      notas:      _notasCtrl.text.trim().isEmpty
          ? null : _notasCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    final state   = ref.watch(crearPedidoProvider);

    ref.listen<CrearPedidoState>(crearPedidoProvider, (_, next) {
      if (next.exitoso) {
        ref.read(carritoProvider.notifier).limpiar();
        ref.invalidate(misPedidosProvider);
        ref.read(crearPedidoProvider.notifier).resetear();
        Navigator.of(context).popUntil((r) => r.isFirst);
        ref.read(tabActivoClienteProvider.notifier).state = 2;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Pedido realizado. Los vendedores ya lo ven.'),
            backgroundColor: AppColores.success,
          ),
        );
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(next.error!),
          backgroundColor: AppColores.danger,
        ));
        ref.read(crearPedidoProvider.notifier).resetear();
      }
    });

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Confirmar Pedido',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            MediaQuery.of(context).padding.bottom + 16),
        color: Colors.white,
        child: SizedBox(
          width:  double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.cargando ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: state.cargando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Confirmar Pedido',
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Resumen del pedido ──────────────────────────
          _SecTitulo('📋 Resumen del pedido'),
          const SizedBox(height: 10),
          Container(
            padding:     const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6)],
            ),
            child: Column(children: [
              ...carrito.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(
                    '${item.cantidad}x ${item.producto.nombre}',
                    style: const TextStyle(
                        color: AppColores.textPrimary),
                  )),
                  Text(
                    '\$${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColores.textPrimary),
                  ),
                ]),
              )),

              // Desglose envío
              Consumer(builder: (ctx, ref, _) {
                final configAsync =
                    ref.watch(configuracionPagoProvider);
                return configAsync.maybeWhen(
                  data: (config) {
                    final envio =
                        double.tryParse(config.costoEnvio) ?? 0.0;
                    if (envio <= 0) return const Divider();
                    return Column(children: [
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal',
                              style: TextStyle(
                                  color: AppColores.textSecond)),
                          Text('\$${carrito.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColores.textSecond)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Envío 🚚',
                              style: TextStyle(
                                  color: AppColores.textSecond)),
                          Text('\$${envio.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColores.textSecond)),
                        ],
                      ),
                      const Divider(),
                    ]);
                  },
                  orElse: () => const Divider(),
                );
              }),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Consumer(builder: (ctx, ref, _) {
                    final configAsync =
                        ref.watch(configuracionPagoProvider);
                    final envio = configAsync.maybeWhen(
                      data: (c) =>
                          double.tryParse(c.costoEnvio) ?? 0.0,
                      orElse: () => 0.0,
                    );
                    return Text(
                      '\$${(carrito.total + envio).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   20,
                        color:      AppColores.primary,
                      ),
                    );
                  }),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── TIPO DE PEDIDO — PASO 13 ────────────────────
          _SecTitulo('🛍️ Tipo de pedido'),
          const SizedBox(height: 10),
          _SelectorTipoPedido(
            tipoSeleccionado: _tipoPedido,
            onTipoChange: (t) => setState(() => _tipoPedido = t),
          ),
          const SizedBox(height: 20),

          // ── Tipo de pago ────────────────────────────────
          _SecTitulo('💳 Método de pago'),
          const SizedBox(height: 10),
          Row(children: [
            _OpcionPago(
              label:        '🚚 Contraentrega',
              sub:          'Pagas cuando recibes',
              seleccionado: _tipoPago == 'contraentrega',
              onTap: () =>
                  setState(() => _tipoPago = 'contraentrega'),
            ),
            const SizedBox(width: 10),
            _OpcionPago(
              label:        '🏦 Transferencia',
              sub:          'Depósito anticipado',
              seleccionado: _tipoPago == 'transferencia',
              onTap: () =>
                  setState(() => _tipoPago = 'transferencia'),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Dirección de entrega ────────────────────────
          _SecTitulo('📍 Dirección de entrega'),
          const SizedBox(height: 10),
          SizedBox(
            width:  double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _obteniendoGps ? null : _obtenerGps,
              style: ElevatedButton.styleFrom(
                backgroundColor: _latitud != null
                    ? AppColores.success : AppColores.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _obteniendoGps
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(_latitud != null
                      ? Icons.my_location : Icons.location_searching),
              label: Text(
                _obteniendoGps
                    ? 'Obteniendo ubicación...'
                    : _latitud != null
                        ? 'Ubicación obtenida ✓'
                        : 'Obtener mi ubicación GPS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_latitud != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColores.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColores.success.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: AppColores.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_latitud!.toStringAsFixed(6)}, '
                  '${_longitud!.toStringAsFixed(6)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.success),
                )),
                TextButton(
                  onPressed: _obtenerGps,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24)),
                  child: const Text('Actualizar',
                      style: TextStyle(fontSize: 11)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // ── Notas ───────────────────────────────────────
          _SecTitulo('📝 Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            decoration: InputDecoration(
              hintText:  'Instrucciones de entrega, referencias...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled:    true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTOR TIPO PEDIDO — PASO 13
// ══════════════════════════════════════════════════════════
class _SelectorTipoPedido extends ConsumerWidget {
  final String           tipoSeleccionado;
  final Function(String) onTipoChange;

  const _SelectorTipoPedido({
    required this.tipoSeleccionado,
    required this.onTipoChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresaAsync = ref.watch(clienteEmpresaProvider);

    return empresaAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (empresa) {
        // Sin empresa → solo entrega a domicilio
        if (empresa == null) {
          return _InfoTipo(
            icono: Icons.delivery_dining_rounded,
            texto: 'Tu pedido será entregado a domicilio.',
            color: AppColores.primary,
          );
        }

        // Con empresa → elige Entrega o Reserva
        return Column(children: [
          Row(children: [
            Expanded(child: _TipoBtn(
              icono:  Icons.delivery_dining_rounded,
              titulo: 'Entrega',
              subtit: 'A domicilio',
              activo: tipoSeleccionado == 'normal',
              color:  AppColores.primary,
              onTap:  () => onTipoChange('normal'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _TipoBtn(
              icono:  Icons.bookmark_outlined,
              titulo: 'Reserva',
              subtit: empresa['nombre'] ?? 'Mi empresa',
              activo: tipoSeleccionado == 'reserva',
              color:  AppColores.accent,
              onTap:  () => onTipoChange('reserva'),
            )),
          ]),
          if (tipoSeleccionado == 'reserva') ...[
            const SizedBox(height: 10),
            _InfoTipo(
              icono: Icons.info_outline_rounded,
              texto: 'El vendedor de ${empresa['nombre']} '
                     'te traerá tu pedido en su próxima visita.',
              color: AppColores.accent,
            ),
          ],
        ]);
      },
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final IconData     icono;
  final String       titulo;
  final String       subtit;
  final bool         activo;
  final Color        color;
  final VoidCallback onTap;

  const _TipoBtn({
    required this.icono,
    required this.titulo,
    required this.subtit,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:  const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activo
            ? color.withOpacity(0.08) : AppColores.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo ? color : Colors.grey.withOpacity(0.2),
          width: activo ? 2 : 1,
        ),
      ),
      child: Column(children: [
        Icon(icono,
            color: activo ? color : AppColores.textSecond,
            size:  26),
        const SizedBox(height: 6),
        Text(titulo,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   13,
                color: activo ? color : AppColores.textPrimary)),
        Text(subtit,
            style: const TextStyle(
                fontSize: 10, color: AppColores.textSecond),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _InfoTipo extends StatelessWidget {
  final IconData icono;
  final String   texto;
  final Color    color;

  const _InfoTipo({
    required this.icono,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icono, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(texto,
          style: TextStyle(fontSize: 12, color: color))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  PANTALLA PAGO POR TRANSFERENCIA
// ══════════════════════════════════════════════════════════
class PagoTransferenciaScreen extends ConsumerWidget {
  const PagoTransferenciaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configuracionPagoProvider);
    final carrito     = ref.watch(carritoProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Datos de Pago',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: configAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
            child: Text('Error cargando datos de pago')),
        data: (config) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColores.primary.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Instrucciones',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColores.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                    '1. Realiza el depósito al número de cuenta indicado.\n'
                    '2. Toma una foto del comprobante.\n'
                    '3. Toca "Enviar comprobante por WhatsApp".\n'
                    '4. Confirma tu pedido.',
                    style: TextStyle(
                        color: AppColores.textSecond,
                        fontSize: 13,
                        height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColores.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColores.success.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.attach_money,
                    color: AppColores.success, size: 32),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Monto a depositar',
                      style: TextStyle(
                          color: AppColores.textSecond,
                          fontSize: 12)),
                  Text(
                    '\$${carrito.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color:      AppColores.success,
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            _DatosBancarios(config: config),
            const SizedBox(height: 20),

            SizedBox(
              width:  double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _abrirWhatsApp(
                    context, config, carrito),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon:  const Text('📱',
                    style: TextStyle(fontSize: 20)),
                label: const Text(
                  'Enviar comprobante por WhatsApp',
                  style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              width:  double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Ya deposité — Confirmar pedido',
                  style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColores.textSecond)),
            )),
          ],
        ),
      ),
    );
  }

  void _abrirWhatsApp(
      BuildContext context,
      ConfiguracionPago config,
      CarritoState carrito) {
    final items = carrito.items.map((i) =>
        '• ${i.cantidad}x ${i.producto.nombre} '
        '- \$${i.subtotal.toStringAsFixed(2)}').join('\n');

    final mensaje =
        '🫓 *Comprobante de pago - EmpanaTrack*\n\n'
        '*Pedido:*\n$items\n\n'
        '*Total:* \$${carrito.total.toStringAsFixed(2)}\n\n'
        '📎 Adjunto el comprobante de depósito.';

    final numero  = config.whatsappNumero
        .replaceAll('+', '').replaceAll(' ', '');
    final encoded = Uri.encodeComponent(mensaje);
    final url     = 'https://wa.me/$numero?text=$encoded';
    _launchUrl(context, url);
  }

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp'),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    }
  }
}

class _DatosBancarios extends StatelessWidget {
  final ConfiguracionPago config;
  const _DatosBancarios({required this.config});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🏦 Datos bancarios',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColores.textPrimary)),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        _FilaDato('Titular', config.cuentaTitular),
        const SizedBox(height: 8),
        _FilaDato('Cuenta',  config.cuentaBanco),
      ],
    ),
  );
}

class _FilaDato extends StatelessWidget {
  final String label;
  final String valor;
  const _FilaDato(this.label, this.valor);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(
          color: AppColores.textSecond, fontSize: 13)),
      Flexible(child: Text(valor,
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColores.textPrimary))),
    ],
  );
}

// ══════════════════════════════════════════════════════════
//  WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════
class _SecTitulo extends StatelessWidget {
  final String texto;
  const _SecTitulo(this.texto);
  @override
  Widget build(BuildContext context) => Text(texto,
      style: const TextStyle(
          fontSize:   15,
          fontWeight: FontWeight.bold,
          color:      AppColores.textPrimary));
}

class _OpcionPago extends StatelessWidget {
  final String       label;
  final String       sub;
  final bool         seleccionado;
  final VoidCallback onTap;
  const _OpcionPago({
    required this.label, required this.sub,
    required this.seleccionado, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColores.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? AppColores.primary : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(children: [
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:      seleccionado
                    ? AppColores.primary : AppColores.textPrimary,
              )),
          Text(sub, textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColores.textSecond)),
        ]),
      ),
    ),
  );
}

class _InicialWidget extends StatelessWidget {
  final String nombre;
  const _InicialWidget({required this.nombre});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
      style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold,
          color: AppColores.primary),
    ),
  );
}

class _EmptyProductos extends StatelessWidget {
  const _EmptyProductos();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🫓', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text('No hay productos disponibles',
              style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
          SizedBox(height: 8),
          Text(
            'El catálogo se actualizará pronto.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColores.textSecond),
          ),
        ],
      ),
    ),
  );
}