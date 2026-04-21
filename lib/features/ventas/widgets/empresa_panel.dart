import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/colores.dart';
import '../models/ruta_activa_models.dart';

const int _kMinutosMin = 3;

class EmpresaPanel extends StatefulWidget {
  final EmpresaRuta  empresa;
  final DateTime?    llegadaEn;
  final bool         cargando;
  final VoidCallback onNuevaVenta;
  final VoidCallback onRegistrarCobro;
  final VoidCallback onMarcarVisitada;

  const EmpresaPanel({
    super.key,
    required this.empresa,
    required this.llegadaEn,
    required this.cargando,
    required this.onNuevaVenta,
    required this.onRegistrarCobro,
    required this.onMarcarVisitada,
  });

  @override
  State<EmpresaPanel> createState() => _EmpresaPanelState();
}

class _EmpresaPanelState extends State<EmpresaPanel>
    with SingleTickerProviderStateMixin {

  Timer? _timer;
  int    _minutos   = 0;
  bool   _expandido = true;
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
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeInOut);
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    if (widget.llegadaEn != null) {
      _minutos = DateTime.now()
          .difference(widget.llegadaEn!)
          .inMinutes;
    }
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || widget.llegadaEn == null) return;
      setState(() => _minutos =
          DateTime.now().difference(widget.llegadaEn!).inMinutes);
    });
  }

  @override
  void didUpdateWidget(EmpresaPanel old) {
    super.didUpdateWidget(old);
    if (old.empresa.id != widget.empresa.id) {
      setState(() { _expandido = true; _minutos = 0; });
      _animCtrl.forward();
      _iniciarTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _puedeMarcar => _minutos >= _kMinutosMin;
  int  get _faltan      => (_kMinutosMin - _minutos).clamp(0, 99);

  void _togglePanel() {
    setState(() => _expandido = !_expandido);
    if (_expandido) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColores.primary,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
                boxShadow: [BoxShadow(
                    color:      Colors.black.withOpacity(0.15),
                    blurRadius: 6)],
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
                      color:      Colors.white,
                      fontSize:   11,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

                // Empresa info
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
                                fontSize: 12,
                                color:    AppColores.textSecond),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  _TimerBadge(
                      puedeMarcar: _puedeMarcar,
                      faltan:      _faltan),
                ]),
                const SizedBox(height: 14),

                // Acciones compactas en fila
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
                  Expanded(child: _AccionCompacta(
                    icono:  Icons.account_balance_wallet_outlined,
                    titulo: 'Cobrar fiado',
                    color:  AppColores.accent,
                    onTap:  widget.onRegistrarCobro,
                  )),
                ]),
                const SizedBox(height: 12),

                // Info geofence
                if (!_puedeMarcar) ...[
                  _GeofenceInfo(faltan: _faltan),
                  const SizedBox(height: 10),
                ],

                // Botón marcar visitada
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
                                strokeWidth: 2,
                                color:       Colors.white))
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
                          fontWeight: FontWeight.bold,
                          fontSize:   13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Timer badge ───────────────────────────────────────────
class _TimerBadge extends StatelessWidget {
  final bool puedeMarcar;
  final int  faltan;
  const _TimerBadge({
      required this.puedeMarcar, required this.faltan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 6),
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
        color: puedeMarcar
            ? AppColores.success : AppColores.warning,
      ),
      const SizedBox(width: 4),
      Text(
        puedeMarcar ? 'Listo' : '$faltan min',
        style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.bold,
            color: puedeMarcar
                ? AppColores.success : AppColores.warning),
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
      border: Border.all(
          color: AppColores.warning.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded,
          color: AppColores.warning, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Permanece $faltan min más en la empresa '
        'para verificar la visita.',
        style: const TextStyle(
            fontSize: 11, color: AppColores.textSecond),
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
    required this.icono,
    required this.titulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 6),
          Text(titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.bold,
                  color:      color)),
        ],
      ),
    ),
  );
}