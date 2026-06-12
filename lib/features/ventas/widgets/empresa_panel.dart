import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

const int _kMinutosMin = 3;

class EmpresaPanel extends StatefulWidget {
  final EmpresaRuta              empresa;
  final DateTime?                llegadaEn;
  final bool                     cargando;
  final bool                     sinStock;
  final VoidCallback             onNuevaVenta;
  final VoidCallback             onVerReservas;
  final int                      cantidadReservas;
  final Future<void> Function()  onMarcarVisitada;
  final VoidCallback?            onSolicitarRecarga;
  final VoidCallback?            onFinalizarRuta;
  final VoidCallback?            onRegistrarCobro;

  const EmpresaPanel({
    super.key,
    required this.empresa,
    required this.llegadaEn,
    required this.cargando,
    required this.sinStock,
    required this.onNuevaVenta,
    required this.onVerReservas,
    required this.cantidadReservas,
    required this.onMarcarVisitada,
    this.onSolicitarRecarga,
    this.onFinalizarRuta,
    this.onRegistrarCobro,
  });

  @override
  State<EmpresaPanel> createState() => _EmpresaPanelState();
}

class _EmpresaPanelState extends State<EmpresaPanel>
    with SingleTickerProviderStateMixin {

  Timer? _timer;
  int    _minutos          = 0;
  bool   _expandido        = true;
  // ✅ false = mostrar [Marcar visitada] + [Recargar]
  // ✅ true  = ya marcó visitada → mostrar [Finalizar] + [Recargar]
  bool   _visitadaSinStock = false;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
      value:    1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    if (widget.sinStock) return;
    if (widget.llegadaEn != null) {
      _minutos = DateTime.now().difference(widget.llegadaEn!).inMinutes;
    }
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || widget.llegadaEn == null) return;
      setState(() =>
          _minutos = DateTime.now().difference(widget.llegadaEn!).inMinutes);
    });
  }

  @override
  void didUpdateWidget(EmpresaPanel old) {
    super.didUpdateWidget(old);
    if (old.empresa.id != widget.empresa.id) {
      setState(() {
        _expandido        = true;
        _minutos          = 0;
        _visitadaSinStock = false;
      });
      _animCtrl.forward();
      _iniciarTimer();
    } else if (old.sinStock != widget.sinStock && widget.sinStock) {
      _timer?.cancel();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _puedeMarcar => widget.sinStock ? true : _minutos >= _kMinutosMin;
  int  get _faltan      => (_kMinutosMin - _minutos).clamp(0, 99);

  void _togglePanel() {
    setState(() => _expandido = !_expandido);
    _expandido ? _animCtrl.forward() : _animCtrl.reverse();
  }

  Future<void> _marcarVisitadaSinStock() async {
    await widget.onMarcarVisitada();
    if (mounted) setState(() => _visitadaSinStock = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── Pestaña flotante ──────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _togglePanel,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColores.primary,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.15), blurRadius: 6)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: Colors.white, size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _expandido ? 'Ocultar' : widget.empresa.nombre,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ),
        ),

        // ── Panel principal ───────────────────────────
        SizeTransition(
          sizeFactor:    _fadeAnim,
          axisAlignment: -1,
          child: Container(
            decoration: BoxDecoration(
              color:        AppColores.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              boxShadow: [BoxShadow(
                  color:      Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset:     const Offset(0, -4))],
            ),
            padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color:        Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),

                // Empresa info + badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        AppColores.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store_rounded,
                        color: AppColores.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.empresa.nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:   17,
                              color:      AppColores.textPrimary)),
                      if (widget.empresa.direccion != null)
                        Text(widget.empresa.direccion!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColores.textSecond),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  if (widget.sinStock)
                    _BadgeSinStock()
                  else
                    _TimerBadge(puedeMarcar: _puedeMarcar, faltan: _faltan),
                ]),
                const SizedBox(height: 14),

                // ════════════════════════════════════════
                // MODO SIN STOCK
                // ════════════════════════════════════════
                if (widget.sinStock) ...[
                  _BannerSinStock(visitada: _visitadaSinStock),
                  const SizedBox(height: 12),

                  // ── FASE 1: aún no marcó visitada ─────
                  // Muestra: [Marcar visitada] + [Solicitar recarga]
                  if (!_visitadaSinStock) ...[
                    _BotonOpcion(
                      icono:    Icons.check_circle_rounded,
                      label:    'Marcar como visitada',
                      color:    AppColores.primary,
                      cargando: widget.cargando,
                      onTap:    _marcarVisitadaSinStock,
                    ),
                    const SizedBox(height: 10),
                    _BotonOpcion(
                      icono:    Icons.inventory_2_rounded,
                      label:    'Solicitar recarga',
                      color:    AppColores.success,
                      cargando: widget.cargando,
                      onTap:    widget.onSolicitarRecarga,
                    ),
                  // ── FASE 2: ya marcó visitada ──────────
                  // Muestra: [Finalizar ruta] + [Solicitar recarga]
                  ] else ...[
                    _BotonOpcionOutlined(
                      icono:    Icons.flag_rounded,
                      label:    'Finalizar ruta',
                      color:    AppColores.danger,
                      cargando: widget.cargando,
                      onTap:    widget.onFinalizarRuta,
                    ),
                    const SizedBox(height: 10),
                    _BotonOpcion(
                      icono:    Icons.inventory_2_rounded,
                      label:    'Solicitar recarga',
                      color:    AppColores.success,
                      cargando: widget.cargando,
                      onTap:    widget.onSolicitarRecarga,
                    ),
                  ],

                // ════════════════════════════════════════
                // MODO CON STOCK (normal)
                // ════════════════════════════════════════
                ] else ...[
                  Row(children: [
                    Expanded(child: _AccionCompacta(
                      icono:  Icons.payments_outlined,
                      titulo: 'Venta contado',
                      color:  AppColores.success,
                      onTap:  widget.onNuevaVenta,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _AccionCompacta(
                      icono:  Icons.receipt_long_outlined,
                      titulo: 'Venta fiado',
                      color:  AppColores.warning,
                      onTap:  widget.onNuevaVenta,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _AccionReservas(
                      cantidad: widget.cantidadReservas,
                      onTap:    widget.onVerReservas,
                    )),
                  ]),
                  const SizedBox(height: 12),

                  if (!_puedeMarcar) ...[
                    _GeofenceInfo(faltan: _faltan),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width:  double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _puedeMarcar && !widget.cargando
                          ? widget.onMarcarVisitada : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:         AppColores.success,
                        foregroundColor:         Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: widget.cargando
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _puedeMarcar
                                  ? Icons.check_circle_rounded
                                  : Icons.timer_outlined,
                              size: 16),
                      label: Text(
                        _puedeMarcar
                            ? 'Marcar empresa como visitada'
                            : 'Espera $_faltan min más...',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Banner sin stock ──────────────────────────────────────
class _BannerSinStock extends StatelessWidget {
  final bool visitada;
  const _BannerSinStock({required this.visitada});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        AppColores.danger.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColores.danger.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.inventory_2_outlined,
          color: AppColores.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(
        visitada
            ? 'Empresa visitada. Finaliza la ruta o solicita recarga.'
            : 'Sin stock. Marca como visitada o solicita recarga.',
        style: const TextStyle(fontSize: 11, color: AppColores.textSecond),
      )),
    ]),
  );
}

// ── Badge sin stock ───────────────────────────────────────
class _BadgeSinStock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color:        AppColores.danger.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColores.danger.withOpacity(0.3)),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 12, color: AppColores.danger),
      SizedBox(width: 4),
      Text('Sin stock',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: AppColores.danger)),
    ]),
  );
}

// ── Botón filled ──────────────────────────────────────────
class _BotonOpcion extends StatelessWidget {
  final IconData      icono;
  final String        label;
  final Color         color;
  final bool          cargando;
  final VoidCallback? onTap;

  const _BotonOpcion({
    required this.icono, required this.label,
    required this.color, required this.cargando, this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 44,
    child: ElevatedButton.icon(
      onPressed: (cargando || onTap == null) ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:         color,
        foregroundColor:         Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: cargando
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icono, size: 16),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}

// ── Botón outlined ────────────────────────────────────────
class _BotonOpcionOutlined extends StatelessWidget {
  final IconData      icono;
  final String        label;
  final Color         color;
  final bool          cargando;
  final VoidCallback? onTap;

  const _BotonOpcionOutlined({
    required this.icono, required this.label,
    required this.color, required this.cargando, this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 44,
    child: OutlinedButton.icon(
      onPressed: (cargando || onTap == null) ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icono, size: 16),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}

// ── Timer badge ───────────────────────────────────────────
class _TimerBadge extends StatelessWidget {
  final bool puedeMarcar;
  final int  faltan;
  const _TimerBadge({required this.puedeMarcar, required this.faltan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: puedeMarcar
          ? AppColores.success.withOpacity(0.1)
          : AppColores.warning.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: puedeMarcar
            ? AppColores.success.withOpacity(0.3)
            : AppColores.warning.withOpacity(0.3),
      ),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        puedeMarcar
            ? Icons.check_circle_outline_rounded
            : Icons.timer_outlined,
        size:  12,
        color: puedeMarcar ? AppColores.success : AppColores.warning,
      ),
      const SizedBox(width: 4),
      Text(
        puedeMarcar ? 'Listo' : '$faltan min',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: puedeMarcar ? AppColores.success : AppColores.warning),
      ),
    ]),
  );
}

// ── Geofence info ─────────────────────────────────────────
class _GeofenceInfo extends StatelessWidget {
  final int faltan;
  const _GeofenceInfo({required this.faltan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        AppColores.warning.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColores.warning.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded,
          color: AppColores.warning, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Permanece $faltan min más en la empresa para verificar la visita.',
        style: const TextStyle(fontSize: 11, color: AppColores.textSecond),
      )),
    ]),
  );
}

// ── Acción compacta ───────────────────────────────────────
class _AccionCompacta extends StatelessWidget {
  final IconData     icono;
  final String       titulo;
  final Color        color;
  final VoidCallback onTap;

  const _AccionCompacta({
    required this.icono, required this.titulo,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, color: color, size: 22),
        const SizedBox(height: 6),
        Text(titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

class _AccionReservas extends StatelessWidget {
  final int          cantidad;
  final VoidCallback onTap;
  const _AccionReservas({required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:        AppColores.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: cantidad > 0
                  ? AppColores.accent.withOpacity(0.4)
                  : AppColores.accent.withOpacity(0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_rounded, color: AppColores.accent, size: 22),
          const SizedBox(height: 6),
          const Text('Reservas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: AppColores.accent)),
        ]),
      ),
      if (cantidad > 0)
        Positioned(
          top: -6, right: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: AppColores.danger, shape: BoxShape.circle),
            child: Text('$cantidad',
                style: const TextStyle(color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        ),
    ]),
  );
}