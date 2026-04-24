import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colores.dart';
import '../providers/pedidos_cliente_provider.dart';
import '../widgets/selector_tipo_pedido.dart';
import 'cliente_shell.dart';

// ══════════════════════════════════════════════════════════
//  PANTALLA CHECKOUT
//
//  Reglas de negocio:
//    Reserva  → empresa_id obligatorio, envío $0, sin GPS,
//               sin método de pago (siempre contraentrega)
//    Entrega  → GPS obligatorio, método de pago visible,
//               envío según configuración del backend
// ══════════════════════════════════════════════════════════
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState
    extends ConsumerState<CheckoutScreen> {
  String  _tipoPedido    = 'normal';
  String  _tipoPago      = 'contraentrega';
  double? _latitud;
  double? _longitud;
  bool    _obteniendoGps = false;
  final   _notasCtrl     = TextEditingController();

  bool get _esReserva => _tipoPedido == 'reserva';

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────
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
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitud  = pos.latitude;
        _longitud = pos.longitude;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text(
                'No se pudo obtener la ubicación GPS'),
            backgroundColor: AppColores.danger,
          ),
        );
      }
    }
    setState(() => _obteniendoGps = false);
  }

  // ── Confirmar ─────────────────────────────────────────
  Future<void> _confirmar() async {
    final carrito      = ref.read(carritoProvider);
    final empresaAsync = ref.read(clienteEmpresaProvider);
    if (carrito.items.isEmpty) return;

    // GPS obligatorio solo en entrega
    if (!_esReserva && _latitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text(
              'Por favor obtén tu ubicación GPS primero'),
          backgroundColor: AppColores.danger,
        ),
      );
      return;
    }

    // Reserva requiere empresa_id — obtenemos del provider
    String? empresaId;
    if (_esReserva) {
      empresaId = empresaAsync.valueOrNull?['id'] as String?;
      if (empresaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se encontró la empresa asignada'),
            backgroundColor: AppColores.danger,
          ),
        );
        return;
      }
    }

    // Transferencia → pantalla comprobante primero
    if (!_esReserva && _tipoPago == 'transferencia') {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => const PagoTransferenciaScreen()),
      );
      if (ok != true) return;
    }

    await ref.read(crearPedidoProvider.notifier).crear(
      items:      carrito.items,
      tipoPago:   _esReserva ? 'contraentrega' : _tipoPago,
      tipoPedido: _tipoPedido,
      empresaId:  empresaId,          // ← enviado al backend
      latitud:    _esReserva ? null : _latitud,
      longitud:   _esReserva ? null : _longitud,
      notas:      _notasCtrl.text.trim().isEmpty
          ? null : _notasCtrl.text.trim(),
    );
  }

  // ── Costo envío según tipo ────────────────────────────
  double _costoEnvio(ConfiguracionPago? config) {
    if (_esReserva) return 0.0;
    return double.tryParse(config?.costoEnvio ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final carrito     = ref.watch(carritoProvider);
    final crearState  = ref.watch(crearPedidoProvider);
    final configAsync = ref.watch(configuracionPagoProvider);
    final config      = configAsync.valueOrNull;
    final envio       = _costoEnvio(config);
    final totalFinal  = carrito.total + envio;

    // ── Escuchar resultado ────────────────────────────
    ref.listen<CrearPedidoState>(crearPedidoProvider,
        (_, next) {
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
      bottomNavigationBar: _BotonConfirmar(
        cargando:    crearState.cargando,
        onConfirmar: _confirmar,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 1. Resumen ────────────────────────────────
          const _SecTitulo('📋 Resumen del pedido'),
          const SizedBox(height: 10),
          _ResumenPedido(
            carrito:    carrito,
            envio:      envio,
            totalFinal: totalFinal,
            esReserva:  _esReserva,
          ),
          const SizedBox(height: 20),

          // ── 2. Tipo de pedido ─────────────────────────
          const _SecTitulo('🛍️ Tipo de pedido'),
          const SizedBox(height: 10),
          SelectorTipoPedido(
            tipoSeleccionado: _tipoPedido,
            onTipoChange: (t) => setState(() {
              _tipoPedido = t;
              // Al cambiar a reserva limpiar campos de entrega
              if (t == 'reserva') {
                _latitud  = null;
                _longitud = null;
                _tipoPago = 'contraentrega';
              }
            }),
          ),
          const SizedBox(height: 20),

          // ── 3. Método de pago (solo entrega) ──────────
          if (!_esReserva) ...[
            const _SecTitulo('💳 Método de pago'),
            const SizedBox(height: 10),
            _SelectorPago(
              tipoPago:     _tipoPago,
              onPagoChange: (p) =>
                  setState(() => _tipoPago = p),
            ),
            const SizedBox(height: 20),
          ],

          // ── 4. GPS (solo entrega) ─────────────────────
          if (!_esReserva) ...[
            const _SecTitulo('📍 Dirección de entrega'),
            const SizedBox(height: 10),
            _SelectorGps(
              latitud:      _latitud,
              longitud:     _longitud,
              obteniendo:   _obteniendoGps,
              onObtenerGps: _obtenerGps,
            ),
            const SizedBox(height: 20),
          ],

          // ── 5. Notas ──────────────────────────────────
          const _SecTitulo('📝 Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            decoration: InputDecoration(
              hintText: _esReserva
                  ? 'Indicaciones para el vendedor...'
                  : 'Instrucciones de entrega, referencias...',
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
//  RESUMEN DEL PEDIDO
// ══════════════════════════════════════════════════════════
class _ResumenPedido extends StatelessWidget {
  final CarritoState carrito;
  final double       envio;
  final double       totalFinal;
  final bool         esReserva;

  const _ResumenPedido({
    required this.carrito,
    required this.envio,
    required this.totalFinal,
    required this.esReserva,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6)],
    ),
    child: Column(children: [
      // Items
      ...carrito.items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(
            '${item.cantidad}x ${item.producto.nombre}',
            style: const TextStyle(
                color: AppColores.textPrimary),
          )),
          Text('\$${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
        ]),
      )),

      const Divider(height: 20),

      // Subtotal
      _FilaResumen(
        label: 'Subtotal',
        valor: '\$${carrito.total.toStringAsFixed(2)}',
      ),
      const SizedBox(height: 6),

      // Envío
      _FilaResumen(
        label:      'Envío 🚚',
        valor:      esReserva ? 'Gratis' : '\$${envio.toStringAsFixed(2)}',
        colorValor: esReserva ? AppColores.success : null,
      ),

      const Divider(height: 20),

      // Total
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                  color:      AppColores.textPrimary)),
          Text('\$${totalFinal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   20,
                  color:      AppColores.primary)),
        ],
      ),
    ]),
  );
}

class _FilaResumen extends StatelessWidget {
  final String label;
  final String valor;
  final Color? colorValor;

  const _FilaResumen({
    required this.label,
    required this.valor,
    this.colorValor,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(
              color: AppColores.textSecond)),
      Text(valor,
          style: TextStyle(
              color:      colorValor ?? AppColores.textSecond,
              fontWeight: colorValor != null
                  ? FontWeight.bold : FontWeight.normal)),
    ],
  );
}

// ══════════════════════════════════════════════════════════
//  SELECTOR DE PAGO
// ══════════════════════════════════════════════════════════
class _SelectorPago extends StatelessWidget {
  final String           tipoPago;
  final Function(String) onPagoChange;

  const _SelectorPago({
    required this.tipoPago,
    required this.onPagoChange,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    _OpcionPago(
      label:        '🚚 Contraentrega',
      sub:          'Pagas cuando recibes',
      seleccionado: tipoPago == 'contraentrega',
      onTap:        () => onPagoChange('contraentrega'),
    ),
    const SizedBox(width: 10),
    _OpcionPago(
      label:        '🏦 Transferencia',
      sub:          'Depósito anticipado',
      seleccionado: tipoPago == 'transferencia',
      onTap:        () => onPagoChange('transferencia'),
    ),
  ]);
}

class _OpcionPago extends StatelessWidget {
  final String       label;
  final String       sub;
  final bool         seleccionado;
  final VoidCallback onTap;

  const _OpcionPago({
    required this.label,
    required this.sub,
    required this.seleccionado,
    required this.onTap,
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
                ? AppColores.primary
                : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      seleccionado
                      ? AppColores.primary
                      : AppColores.textPrimary)),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color:    AppColores.textSecond)),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  SELECTOR GPS
// ══════════════════════════════════════════════════════════
class _SelectorGps extends StatelessWidget {
  final double?      latitud;
  final double?      longitud;
  final bool         obteniendo;
  final VoidCallback onObtenerGps;

  const _SelectorGps({
    required this.latitud,
    required this.longitud,
    required this.obteniendo,
    required this.onObtenerGps,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(
      width:  double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: obteniendo ? null : onObtenerGps,
        style: ElevatedButton.styleFrom(
          backgroundColor: latitud != null
              ? AppColores.success : AppColores.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: obteniendo
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(latitud != null
                ? Icons.my_location
                : Icons.location_searching),
        label: Text(
          obteniendo
              ? 'Obteniendo ubicación...'
              : latitud != null
                  ? 'Ubicación obtenida ✓'
                  : 'Obtener mi ubicación GPS',
          style: const TextStyle(
              fontWeight: FontWeight.bold),
        ),
      ),
    ),
    if (latitud != null) ...[
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        AppColores.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
              color: AppColores.success.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle,
              color: AppColores.success, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            '${latitud!.toStringAsFixed(6)}, '
            '${longitud!.toStringAsFixed(6)}',
            style: const TextStyle(
                fontSize: 12,
                color:    AppColores.success),
          )),
          TextButton(
            onPressed: onObtenerGps,
            style: TextButton.styleFrom(
                padding:     EdgeInsets.zero,
                minimumSize: const Size(50, 24)),
            child: const Text('Actualizar',
                style: TextStyle(fontSize: 11)),
          ),
        ]),
      ),
    ],
  ]);
}

// ══════════════════════════════════════════════════════════
//  BOTÓN CONFIRMAR
// ══════════════════════════════════════════════════════════
class _BotonConfirmar extends StatelessWidget {
  final bool         cargando;
  final VoidCallback onConfirmar;

  const _BotonConfirmar({
    required this.cargando,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16),
    color: Colors.white,
    child: SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: cargando ? null : onConfirmar,
        style: ElevatedButton.styleFrom(
          backgroundColor:         AppColores.success,
          foregroundColor:         Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: cargando
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('Confirmar Pedido',
                style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  WIDGET UTILITARIO
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
        error: (_, __) => const Center(
            child: Text('Error cargando datos de pago')),
        data: (config) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Instrucciones
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
                          fontSize:   16,
                          color:      AppColores.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                    '1. Realiza el depósito al número de cuenta indicado.\n'
                    '2. Toma una foto del comprobante.\n'
                    '3. Toca "Enviar comprobante por WhatsApp".\n'
                    '4. Confirma tu pedido.',
                    style: TextStyle(
                        color:    AppColores.textSecond,
                        fontSize: 13,
                        height:   1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Monto
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto a depositar',
                        style: TextStyle(
                            color:    AppColores.textSecond,
                            fontSize: 12)),
                    Text('\$${carrito.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color:      AppColores.success,
                            fontSize:   28,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Datos bancarios
            Container(
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
                          fontSize:   16,
                          color:      AppColores.textPrimary)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _FilaDato('Titular', config.cuentaTitular),
                  const SizedBox(height: 8),
                  _FilaDato('Cuenta',  config.cuentaBanco),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón WhatsApp
            SizedBox(
              width:  double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _abrirWhatsApp(context, config, carrito),
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

            // Confirmar
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
                  style: TextStyle(
                      color: AppColores.textSecond)),
            )),
          ],
        ),
      ),
    );
  }

  void _abrirWhatsApp(
      BuildContext context,
      ConfiguracionPago config,
      CarritoState carrito) async {
    final items = carrito.items.map((i) =>
        '• ${i.cantidad}x ${i.producto.nombre} '
        '- \$${i.subtotal.toStringAsFixed(2)}').join('\n');

    final mensaje =
        '🫓 *Comprobante de pago - EmpanaTrack*\n\n'
        '*Pedido:*\n$items\n\n'
        '*Total:* \$${carrito.total.toStringAsFixed(2)}\n\n'
        '📎 Adjunto el comprobante de depósito.';

    final numero = config.whatsappNumero
        .replaceAll('+', '').replaceAll(' ', '');
    final uri    = Uri.parse(
        'https://wa.me/$numero'
        '?text=${Uri.encodeComponent(mensaje)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('No se pudo abrir WhatsApp'),
          backgroundColor: AppColores.danger,
        ),
      );
    }
  }
}

class _FilaDato extends StatelessWidget {
  final String label;
  final String valor;
  const _FilaDato(this.label, this.valor);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(
              color: AppColores.textSecond, fontSize: 13)),
      Flexible(child: Text(valor,
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color:      AppColores.textPrimary))),
    ],
  );
}