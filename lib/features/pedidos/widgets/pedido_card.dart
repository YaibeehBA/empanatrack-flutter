import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';
import '../models/pedido_models.dart';

class PedidoCard extends StatelessWidget {
  final PedidoBase   pedido;
  final VoidCallback onAceptar;
  final bool         cargando;

  const PedidoCard({
    super.key,
    required this.pedido,
    required this.onAceptar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        AppColores.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border(
        left: BorderSide(
          color: pedido.esReserva
              ? AppColores.accent : AppColores.primary,
          width: 4,
        ),
      ),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Encabezado
        Row(children: [
          CircleAvatar(
            backgroundColor: (pedido.esReserva
                    ? AppColores.accent : AppColores.primary)
                .withOpacity(0.12),
            child: Text(
              pedido.clienteNombre.isNotEmpty
                  ? pedido.clienteNombre[0].toUpperCase() : '?',
              style: TextStyle(
                color: pedido.esReserva
                    ? AppColores.accent : AppColores.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pedido.clienteNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   15,
                      color:      AppColores.textPrimary)),
              Row(children: [
                // Badge tipo
                _TipoBadge(esReserva: pedido.esReserva),
                const SizedBox(width: 6),
                Text(_formatFecha(pedido.creadoEn),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColores.textSecond)),
              ]),
            ],
          )),
          Text('\$${pedido.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary)),
        ]),
        const SizedBox(height: 12),

        // Empresa (solo reservas)
        if (pedido.esReserva && pedido.empresaNombre != null)
          _InfoRow(
            icono: Icons.business_outlined,
            texto: pedido.empresaNombre!,
            color: AppColores.accent,
          ),

        // Dirección (pedidos normales)
        if (!pedido.esReserva && pedido.direccionEntrega != null)
          _InfoRow(
            icono: Icons.location_on_outlined,
            texto: pedido.direccionEntrega!,
            color: AppColores.textSecond,
          ),

        // Items
        const SizedBox(height: 8),
        ...pedido.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            const Icon(Icons.circle,
                size: 5, color: AppColores.textSecond),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${item['cantidad']}x ${item['nombre']}',
              style: const TextStyle(fontSize: 13),
            )),
            Text('\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        )),

        const SizedBox(height: 12),

        // Chips info + botón aceptar
        Row(children: [
          _PagoChip(tipoPago: pedido.tipoPago),
          if (pedido.tieneCoordenadas)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: _GpsChip(),
            ),
          const Spacer(),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: cargando ? null : onAceptar,
              style: ElevatedButton.styleFrom(
                backgroundColor: pedido.esReserva
                    ? AppColores.accent : AppColores.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: cargando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      pedido.esReserva ? 'Reservar' : 'Aceptar',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ],
    ),
  );

  String _formatFecha(String f) {
    try {
      final dt    = DateTime.parse(f).toLocal();
      const m     = ['','Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${m[dt.month]} '
             '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return f; }
  }
}

class _TipoBadge extends StatelessWidget {
  final bool esReserva;
  const _TipoBadge({required this.esReserva});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: (esReserva ? AppColores.accent : AppColores.primary)
          .withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      esReserva ? 'RESERVA' : 'ENTREGA',
      style: TextStyle(
          fontSize:   9,
          fontWeight: FontWeight.bold,
          color: esReserva ? AppColores.accent : AppColores.primary),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icono;
  final String   texto;
  final Color    color;
  const _InfoRow({required this.icono,
      required this.texto, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icono, size: 13, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(texto,
          style: TextStyle(fontSize: 12, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _PagoChip extends StatelessWidget {
  final String tipoPago;
  const _PagoChip({required this.tipoPago});
  @override
  Widget build(BuildContext context) {
    final esTransf = tipoPago == 'transferencia';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (esTransf ? AppColores.accent : AppColores.warning)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(esTransf
            ? Icons.account_balance : Icons.delivery_dining,
            size: 12,
            color: esTransf ? AppColores.accent : AppColores.warning),
        const SizedBox(width: 4),
        Text(esTransf ? 'Transferencia' : 'Contraentrega',
            style: TextStyle(
                fontSize: 10,
                color: esTransf ? AppColores.accent : AppColores.warning,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColores.success.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.location_on, size: 12, color: AppColores.success),
      SizedBox(width: 4),
      Text('GPS', style: TextStyle(
          fontSize: 10, color: AppColores.success,
          fontWeight: FontWeight.w600)),
    ]),
  );
}