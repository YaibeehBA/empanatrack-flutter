import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colores.dart';
import '../screens/cliente_shell.dart';

// ══════════════════════════════════════════════════════════
//  SELECTOR TIPO PEDIDO
//
//  Uso:
//    SelectorTipoPedido(
//      tipoSeleccionado: _tipoPedido,
//      onTipoChange:     (t) => setState(() => _tipoPedido = t),
//    )
//
//  Lógica:
//    - Sin empresa asignada  → solo muestra banner "A domicilio"
//    - Con empresa asignada  → muestra botones Entrega / Reserva
// ══════════════════════════════════════════════════════════
class SelectorTipoPedido extends ConsumerWidget {
  final String           tipoSeleccionado;
  final Function(String) onTipoChange;

  const SelectorTipoPedido({
    super.key,
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
        // Sin empresa → solo entrega a domicilio, sin opciones
        if (empresa == null) {
          return const TipoBanner(
            icono: Icons.delivery_dining_rounded,
            texto: 'Tu pedido será entregado a domicilio.',
            color: AppColores.primary,
          );
        }

        // Con empresa → puede elegir Entrega o Reserva
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
            TipoBanner(
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

// ── Botón de tipo seleccionable ───────────────────────────
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
            ? color.withOpacity(0.08)
            : AppColores.surface,
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

// ── Banner informativo reutilizable ──────────────────────
class TipoBanner extends StatelessWidget {
  final IconData icono;
  final String   texto;
  final Color    color;

  const TipoBanner({
    super.key,
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