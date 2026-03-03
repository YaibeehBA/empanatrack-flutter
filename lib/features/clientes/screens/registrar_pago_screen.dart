import 'package:empanatrack_app/features/ventas/providers/ventas_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../providers/pagos_provider.dart';
import '../providers/clientes_provider.dart';
import '../providers/historial_provider.dart';
import '../../ventas/providers/reporte_provider.dart';
import '../../../shared/models/cliente_model.dart';
import '../../../shared/models/venta_model.dart';

class RegistrarPagoScreen extends ConsumerStatefulWidget {
  final String clienteId;
  const RegistrarPagoScreen({super.key, required this.clienteId});

  @override
  ConsumerState<RegistrarPagoScreen> createState() =>
      _RegistrarPagoScreenState();
}

class _RegistrarPagoScreenState extends ConsumerState<RegistrarPagoScreen> {
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String   _tipoPago      = 'efectivo';
  String?  _ventaIdSelec;       // null = adelanto general
  bool     _pagoGeneral   = true; // true = abono al saldo total

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Ingresa un monto válido'),
          backgroundColor: AppColores.danger,
        ),
      );
      return;
    }

    await ref.read(pagoProvider.notifier).registrarPago(
      clienteId: widget.clienteId,
      ventaId:   _pagoGeneral ? null : _ventaIdSelec,
      monto:     monto,
      tipo:      _tipoPago,
      notas:     _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagoState  = ref.watch(pagoProvider);
    final clienteAsync = ref.watch(clientesProvider);

    // Buscar el cliente actual
    final cliente = clienteAsync.maybeWhen(
      data: (lista) => lista.cast<ClienteModel?>().firstWhere(
        (c) => c?.id == widget.clienteId,
        orElse: () => null,
      ),
      orElse: () => null,
    );

    // Escuchar éxito o error
   ref.listen<PagoState>(pagoProvider, (prev, next) {
  if (next.exitoso) {
    // Invalidar TODOS los providers afectados
    ref.invalidate(clientesProvider);
    ref.invalidate(historialProvider(widget.clienteId));
    ref.invalidate(resumenDiaProvider);
    ref.invalidate(ventasHoyProvider);        

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:         Text('✅ Pago registrado correctamente'),
        backgroundColor: AppColores.success,
      ),
    );
    // Pequeño delay para que los providers se reconstruyan antes de navegar
    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) context.pop();
    });
  }
  if (next.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(next.error!),
        backgroundColor: AppColores.danger,
      ),
    );
  }
});

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title:           const Text('Registrar Pago',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: _BottomBarPago(
        cargando: pagoState.cargando,
        onTap:    _registrar,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Info del cliente ───────────────────────────
          if (cliente != null) _ClienteInfoCard(cliente: cliente),
          const SizedBox(height: 20),

          // ── Tipo de pago ───────────────────────────────
          _SeccionLabel(texto: '1. Tipo de pago'),
          const SizedBox(height: 10),
          _SelectorTipoPago(
            seleccionado: _tipoPago,
            onChange: (v) => setState(() => _tipoPago = v),
          ),
          const SizedBox(height: 20),

          // ── ¿A qué venta aplica? ───────────────────────
          _SeccionLabel(texto: '2. ¿A qué aplica el pago?'),
          const SizedBox(height: 10),
          _SelectorAplicacion(
            clienteId:      widget.clienteId,
            pagoGeneral:    _pagoGeneral,
            ventaIdSelec:   _ventaIdSelec,
            onCambiarModo:  (v) => setState(() {
              _pagoGeneral  = v;
              _ventaIdSelec = null;
            }),
            onSelecVenta: (id) => setState(() => _ventaIdSelec = id),
          ),
          const SizedBox(height: 20),

          // ── Monto ──────────────────────────────────────
          _SeccionLabel(texto: '3. Monto recibido'),
          const SizedBox(height: 10),
          TextField(
            controller:  _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText:   '\$  ',
              prefixStyle:  const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold,
                color:    AppColores.primary,
              ),
              hintText:     '0.00',
              hintStyle:    const TextStyle(color: AppColores.textSecond),
              border:       OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled:       true,
              fillColor:    Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // ── Notas ──────────────────────────────────────
          _SeccionLabel(texto: 'Notas (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines:   2,
            decoration: InputDecoration(
              hintText:  'Observaciones del pago...',
              border:    OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

// ── Widgets internos ───────────────────────────────────────

class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel({required this.texto});

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: const TextStyle(
      fontSize:      12,
      fontWeight:    FontWeight.bold,
      color:         AppColores.textSecond,
      letterSpacing: 1.2,
    ),
  );
}

class _ClienteInfoCard extends StatelessWidget {
  final ClienteModel cliente;
  const _ClienteInfoCard({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:     const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColores.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              cliente.nombre[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombre,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  cliente.empresa ?? 'Independiente',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Saldo actual',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(
                '\$${cliente.saldoActual.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.orangeAccent, fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectorTipoPago extends StatelessWidget {
  final String seleccionado;
  final Function(String) onChange;
  const _SelectorTipoPago({required this.seleccionado, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final tipos = [
      {'valor': 'efectivo',      'label': '💵 Efectivo'},
      {'valor': 'transferencia', 'label': '🏦 Transferencia'},
      {'valor': 'adelanto',      'label': '⏩ Adelanto'},
    ];

    return Row(
      children: tipos.map((t) {
        final activo = seleccionado == t['valor'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChange(t['valor']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:   const EdgeInsets.only(right: 8),
              padding:  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:        activo ? AppColores.success : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                  color: activo ? AppColores.success : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  t['label']!,
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                    color:      activo ? Colors.white : AppColores.textSecond,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectorAplicacion extends ConsumerWidget {
  final String   clienteId;
  final bool     pagoGeneral;
  final String?  ventaIdSelec;
  final Function(bool)   onCambiarModo;
  final Function(String) onSelecVenta;

  const _SelectorAplicacion({
    required this.clienteId,
    required this.pagoGeneral,
    required this.ventaIdSelec,
    required this.onCambiarModo,
    required this.onSelecVenta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Toggle: abono general vs venta específica
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onCambiarModo(true),
                child: _ModoBtn(
                  label:  '💰 Abono general',
                  activo: pagoGeneral,
                  color:  AppColores.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onCambiarModo(false),
                child: _ModoBtn(
                  label:  '🧾 Venta específica',
                  activo: !pagoGeneral,
                  color:  AppColores.warning,
                ),
              ),
            ),
          ],
        ),

        // Si elige venta específica, mostrar lista de ventas pendientes
        if (!pagoGeneral) ...[
          const SizedBox(height: 12),
          ref.watch(ventasPendientesProvider(clienteId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => const Text('Error cargando ventas'),
            data:    (ventas) => ventas.isEmpty
                ? Container(
                    padding:     const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        AppColores.background,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay ventas pendientes',
                        style: TextStyle(color: AppColores.textSecond),
                      ),
                    ),
                  )
                : Column(
                    children: ventas.map((v) => _VentaOpcion(
                      venta:      v,
                      seleccionada: ventaIdSelec == v.id,
                      onTap:      () => onSelecVenta(v.id),
                    )).toList(),
                  ),
          ),
        ],
      ],
    );
  }
}

class _ModoBtn extends StatelessWidget {
  final String label;
  final bool   activo;
  final Color  color;
  const _ModoBtn({required this.label, required this.activo, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:  const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color:        activo ? color : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(
          color: activo ? color : Colors.grey.shade300, width: 2,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.bold,
            color:      activo ? Colors.white : AppColores.textSecond,
          ),
        ),
      ),
    );
  }
}

class _VentaOpcion extends StatelessWidget {
  final VentaModel venta;
  final bool       seleccionada;
  final VoidCallback onTap;
  const _VentaOpcion({
    required this.venta,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:   const EdgeInsets.only(bottom: 8),
        padding:  const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        seleccionada
              ? AppColores.warning.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: seleccionada ? AppColores.warning : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              seleccionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: seleccionada ? AppColores.warning : AppColores.textSecond,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venta del ${_fecha(venta.fechaVenta)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Pendiente: \$${venta.montoPendiente.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColores.danger, fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$${venta.montoTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _fecha(String f) {
    try {
      final dt    = DateTime.parse(f);
      const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${meses[dt.month]}';
    } catch (_) { return f; }
  }
}

class _BottomBarPago extends StatelessWidget {
  final bool         cargando;
  final VoidCallback onTap;
  const _BottomBarPago({required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color:     Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width:  double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed:  cargando ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon:  cargando
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text(
            'Confirmar Pago',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}