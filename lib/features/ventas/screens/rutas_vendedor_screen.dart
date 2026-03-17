import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../admin/providers/rutas_admin_provider.dart';

// ══════════════════════════════════════════════════════════
//  COLORES
// ══════════════════════════════════════════════════════════
const _colorRuta   = Color(0xFF1A73E8);
const _colorInicio = Color(0xFF1E8B3E);
const _colorFin    = Color(0xFFD32F2F);

// ══════════════════════════════════════════════════════════
//  MODELOS
// ══════════════════════════════════════════════════════════
class RutaVendedor {
  final String asignacionId;
  final String turno;
  final String rutaId;
  final String rutaNombre;
  final String? rutaDescripcion;
  final bool   rutaActiva;
  final List<EmpresaRuta> empresas;

  const RutaVendedor({
    required this.asignacionId,
    required this.turno,
    required this.rutaId,
    required this.rutaNombre,
    this.rutaDescripcion,
    required this.rutaActiva,
    required this.empresas,
  });

  factory RutaVendedor.fromJson(Map<String, dynamic> j) {
    final ruta = j['ruta'] as Map<String, dynamic>;
    return RutaVendedor(
      asignacionId:    j['asignacion_id'],
      turno:           j['turno'],
      rutaId:          ruta['id'],
      rutaNombre:      ruta['nombre'],
      rutaDescripcion: ruta['descripcion'],
      rutaActiva:      ruta['esta_activa'],
      empresas: (ruta['empresas'] as List)
          .map((e) => EmpresaRuta.fromJson(e))
          .toList(),
    );
  }

  String get turnoLabel {
    switch (turno) {
      case 'mañana': return '🌅 Mañana';
      case 'tarde':  return '🌇 Tarde';
      default:       return '🕐 Única';
    }
  }

  int get empresasConGps =>
      empresas.where((e) => e.tieneCoordenadas).length;
}

// ══════════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════════
final misRutasProvider = FutureProvider<List<RutaVendedor>>((ref) async {
  final r = await ApiClient.get('/rutas/mis-rutas');
  return (r.data as List)
      .map((r) => RutaVendedor.fromJson(r))
      .toList();
});

// ══════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL — MIS RUTAS
// ══════════════════════════════════════════════════════════
class RutasVendedorScreen extends ConsumerWidget {
  const RutasVendedorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misRutasProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Mis Rutas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(misRutasProvider),
            tooltip:   'Actualizar',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorVista(
            onReintentar: () => ref.invalidate(misRutasProvider)),
        data: (rutas) {
          final activas = rutas.where((r) => r.rutaActiva).toList();
          if (activas.isEmpty) return const _SinRutas();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(misRutasProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: activas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CardRutaVendedor(
                ruta: activas[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _DetalleRutaVendedor(ruta: activas[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD RUTA
// ══════════════════════════════════════════════════════════
class _CardRutaVendedor extends StatelessWidget {
  final RutaVendedor ruta;
  final VoidCallback onTap;
  const _CardRutaVendedor({required this.ruta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Ícono ruta
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppColores.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                    child: Text('🗺️', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ruta.rutaNombre, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: AppColores.textPrimary)),
                  if (ruta.rutaDescripcion != null)
                    Text(ruta.rutaDescripcion!, style: const TextStyle(
                        fontSize: 12, color: AppColores.textSecond)),
                ],
              )),
              const Icon(Icons.chevron_right,
                  color: AppColores.textSecond),
            ]),
            const SizedBox(height: 14),
            // Chips info
            Row(children: [
              _InfoChip(
                icono: Icons.access_time_rounded,
                texto: ruta.turnoLabel,
                color: AppColores.primary,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icono: Icons.business_outlined,
                texto: '${ruta.empresas.length} empresas',
                color: AppColores.accent,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icono: ruta.empresasConGps == ruta.empresas.length
                    ? Icons.location_on
                    : Icons.location_off,
                texto: '${ruta.empresasConGps} con GPS',
                color: ruta.empresasConGps == ruta.empresas.length
                    ? AppColores.success : AppColores.warning,
              ),
            ]),
            // Aviso sin GPS
            if (ruta.empresasConGps < 2) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppColores.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColores.warning.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: AppColores.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(
                    'Necesitas al menos 2 empresas con coordenadas '
                    'GPS para ver el mapa.',
                    style: TextStyle(
                        fontSize: 11, color: AppColores.warning),
                  )),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icono; final String texto; final Color color;
  const _InfoChip({required this.icono, required this.texto,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 13, color: color),
      const SizedBox(width: 4),
      Text(texto, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  DETALLE RUTA VENDEDOR — con tabs Lista y Mapa
// ══════════════════════════════════════════════════════════
class _DetalleRutaVendedor extends ConsumerStatefulWidget {
  final RutaVendedor ruta;
  const _DetalleRutaVendedor({required this.ruta});

  @override
  ConsumerState<_DetalleRutaVendedor> createState() =>
      _DetalleRutaVendedorState();
}

class _DetalleRutaVendedorState
    extends ConsumerState<_DetalleRutaVendedor>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ruta.rutaNombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.ruta.turnoLabel,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller:           _tabCtrl,
          indicatorColor:       Colors.white,
          labelColor:           Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Lista'),
            Tab(icon: Icon(Icons.map),      text: 'Mapa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TabLista(ruta: widget.ruta),
          _TabMapaVendedor(rutaId: widget.ruta.rutaId),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB LISTA — empresas en orden con distancia
// ══════════════════════════════════════════════════════════
class _TabLista extends ConsumerWidget {
  final RutaVendedor ruta;
  const _TabLista({required this.ruta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rutaCalculadaProvider(ruta.rutaId));

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
      error: (e, _) => _SinGps(),
      data: (calculada) => ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Resumen ─────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColores.primary,
                    AppColores.primary.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: AppColores.primary.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const Text('🚶', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Tu ruta de hoy',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
                Text(calculada.distanciaLabel,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('Aprox. ${calculada.tiempoLabel} caminando',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ]),
              const Spacer(),
              Column(children: [
                Text('${calculada.paradas.length}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const Text('paradas',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ]),
            ]),
          ),

          // ── Encabezado lista ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              const Text('ORDEN DE VISITA', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: AppColores.textSecond, letterSpacing: 1.0)),
              const Spacer(),
              Text(
                calculada.fuente == 'osrm'
                    ? 'Ruta optimizada ✓' : 'Orden aproximado',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: calculada.fuente == 'osrm'
                      ? _colorRuta : AppColores.warning,
                ),
              ),
            ]),
          ),

          // ── Paradas ──────────────────────────────────
          ...calculada.paradas.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            return _FilaParadaVendedor(
              parada:   p,
              numero:   i + 1,
              esUltima: p.esFin,
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FILA PARADA VENDEDOR
// ══════════════════════════════════════════════════════════
class _FilaParadaVendedor extends StatelessWidget {
  final ParadaRuta parada;
  final int        numero;
  final bool       esUltima;
  const _FilaParadaVendedor({
    required this.parada,
    required this.numero,
    required this.esUltima,
  });

  Color get _c => parada.esInicio
      ? _colorInicio : parada.esFin ? _colorFin : _colorRuta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Línea + círculo
        SizedBox(width: 32, child: Column(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _c, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(
                  color: _c.withOpacity(0.3), blurRadius: 4)],
            ),
            child: Center(child: parada.esInicio
                ? const Icon(Icons.play_arrow,
                    color: Colors.white, size: 16)
                : parada.esFin
                    ? const Icon(Icons.flag,
                        color: Colors.white, size: 14)
                    : Text('$numero', style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold))),
          ),
          if (!esUltima)
            Container(
              width: 2.5, height: 56,
              decoration: BoxDecoration(
                  color: _colorRuta.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2)),
            ),
        ])),

        const SizedBox(width: 12),

        // Contenido
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(parada.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColores.textPrimary))),
                  if (numero > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: _colorRuta.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min,
                          children: [
                        const Icon(Icons.directions_walk,
                            size: 11, color: _colorRuta),
                        const SizedBox(width: 3),
                        Text(parada.distanciaLabel,
                            style: const TextStyle(
                                fontSize: 11, color: _colorRuta,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
                if (parada.direccion != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColores.textSecond),
                    const SizedBox(width: 4),
                    Expanded(child: Text(parada.direccion!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.textSecond))),
                  ]),
                ],
                if (parada.esInicio || parada.esFin) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _c.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      parada.esInicio
                          ? '🟢 Punto de inicio'
                          : '🔴 Punto final',
                      style: TextStyle(fontSize: 10, color: _c,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB MAPA VENDEDOR
// ══════════════════════════════════════════════════════════
class _TabMapaVendedor extends ConsumerWidget {
  final String rutaId;
  const _TabMapaVendedor({required this.rutaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rutaCalculadaProvider(rutaId));

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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                ref.invalidate(rutaCalculadaProvider(rutaId)),
            icon:  const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primary,
                foregroundColor: Colors.white),
          ),
        ],
      )),
      data: (calculada) => _MapaVendedorRenderizado(
        calculada:  calculada,
        onRecargar: () =>
            ref.invalidate(rutaCalculadaProvider(rutaId)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MAPA RENDERIZADO VENDEDOR
// ══════════════════════════════════════════════════════════
class _MapaVendedorRenderizado extends StatefulWidget {
  final RutaCalculada calculada;
  final VoidCallback  onRecargar;
  const _MapaVendedorRenderizado({
    required this.calculada,
    required this.onRecargar,
  });

  @override
  State<_MapaVendedorRenderizado> createState() =>
      _MapaVendedorRenderizadoState();
}

class _MapaVendedorRenderizadoState
    extends State<_MapaVendedorRenderizado> {
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
    final calculada    = widget.calculada;
    final puntosLatLng = calculada.puntosPolilinea
        .map((p) => LatLng(p.latitud, p.longitud))
        .toList();
    final centro = calculada.paradas.isEmpty
        ? const LatLng(0, 0)
        : LatLng(
            calculada.paradas.map((p) => p.latitud)
                    .reduce((a, b) => a + b) /
                calculada.paradas.length,
            calculada.paradas.map((p) => p.longitud)
                    .reduce((a, b) => a + b) /
                calculada.paradas.length,
          );

    return Stack(children: [

      // ── MAPA ──────────────────────────────────────
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

          // Borde blanco
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
                    _mapCtrl.move(
                        LatLng(p.latitud, p.longitud), 17);
                  },
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        color:  color, shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white,
                            width: activo ? 3 : 2.5),
                        boxShadow: [BoxShadow(
                            color: color.withOpacity(
                                activo ? 0.5 : 0.25),
                            blurRadius: activo ? 10 : 4,
                            spreadRadius: activo ? 2 : 0,
                            offset: const Offset(0, 2))],
                      ),
                      child: Center(child: p.esInicio
                          ? Icon(Icons.play_arrow,
                              color: Colors.white,
                              size: activo ? 22 : 18)
                          : p.esFin
                              ? Icon(Icons.flag,
                                  color: Colors.white,
                                  size: activo ? 20 : 16)
                              : Text('${i + 1}', style: TextStyle(
                                  color: Colors.white,
                                  fontSize: activo ? 15 : 12,
                                  fontWeight: FontWeight.bold))),
                    ),
                    CustomPaint(
                      size: Size(activo ? 12 : 9, activo ? 9 : 6),
                      painter: _PinPainterV(color),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),

      // ── PANEL DESLIZABLE ───────────────────────────
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
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(20)),
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
                      Text('Tu ruta', style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColores.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _ChipResumen(icono: Icons.route,
                            texto: calculada.distanciaLabel,
                            color: AppColores.primary),
                        const SizedBox(width: 6),
                        _ChipResumen(icono: Icons.access_time,
                            texto: calculada.tiempoLabel,
                            color: _colorRuta),
                        const SizedBox(width: 6),
                        _ChipResumen(
                            icono: Icons.location_on,
                            texto: '${calculada.paradas.length} paradas',
                            color: _colorInicio),
                      ]),
                    ],
                  )),
                  IconButton(
                    onPressed: widget.onRecargar,
                    icon: const Icon(Icons.refresh,
                        color: AppColores.primary),
                    tooltip: 'Recalcular',
                  ),
                ]),
              ),

              // Banner fallback
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
                        'Sin conexión — distancias aproximadas',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColores.warning))),
                    TextButton(
                      onPressed: widget.onRecargar,
                      child: const Text('Reintentar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),

              // Lista paradas
              if (calculada.paradas.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(children: [
                    const Text('ORDEN DE VISITA', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: AppColores.textSecond,
                        letterSpacing: 1.0)),
                    const Spacer(),
                    Text(
                      calculada.fuente == 'osrm'
                          ? 'Optimizada ✓' : 'Aproximada',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: calculada.fuente == 'osrm'
                            ? _colorRuta : AppColores.warning,
                      ),
                    ),
                  ]),
                ),

                ...calculada.paradas.asMap().entries.map((entry) {
                  final i      = entry.key;
                  final p      = entry.value;
                  final activo = _paradaActiva == i;
                  final color  = _colorMarcador(i);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: activo
                        ? color.withOpacity(0.07)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _paradaActiva = i);
                        _mapCtrl.move(
                            LatLng(p.latitud, p.longitud), 17);
                        _panelCtrl.animateTo(0.22,
                            duration:
                                const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 6, 20, 6),
                        child: Row(children: [
                          // Pin
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: activo ? color
                                  : color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: p.esInicio
                                ? Icon(Icons.play_arrow,
                                    color: activo
                                        ? Colors.white : color,
                                    size: 14)
                                : p.esFin
                                    ? Icon(Icons.flag,
                                        color: activo
                                            ? Colors.white : color,
                                        size: 13)
                                    : Text('${i + 1}', style: TextStyle(
                                        color: activo
                                            ? Colors.white : color,
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.bold))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre, style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: activo
                                      ? color
                                      : AppColores.textPrimary)),
                              if (p.direccion != null)
                                Text(p.direccion!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColores.textSecond)),
                            ],
                          )),
                          if (i > 0)
                            Text(p.distanciaLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: activo
                                        ? color
                                        : AppColores.textSecond,
                                    fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: activo
                                  ? color : AppColores.textSecond),
                        ]),
                      ),
                    ),
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
//  WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════
class _ChipResumen extends StatelessWidget {
  final IconData icono; final String texto; final Color color;
  const _ChipResumen({required this.icono, required this.texto,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 12, color: color),
      const SizedBox(width: 3),
      Text(texto, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _PinPainterV extends CustomPainter {
  final Color color;
  const _PinPainterV(this.color);
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
  bool shouldRepaint(_PinPainterV old) => old.color != color;
}

class _SinRutas extends StatelessWidget {
  const _SinRutas();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🗺️', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text('Sin rutas asignadas', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold,
            color: AppColores.textPrimary)),
        SizedBox(height: 8),
        Text('El administrador aún no te ha\nasignado ninguna ruta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColores.textSecond)),
      ],
    ),
  );
}

class _SinGps extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('📍', style: TextStyle(fontSize: 52)),
        SizedBox(height: 16),
        Text('Sin coordenadas GPS', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            color: AppColores.textPrimary)),
        SizedBox(height: 8),
        Text(
          'Pide al administrador que agregue\n'
          'coordenadas GPS a las empresas.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColores.textSecond),
        ),
      ],
    ),
  );
}

class _ErrorVista extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorVista({required this.onReintentar});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Error al cargar las rutas',
            style: TextStyle(color: AppColores.textSecond)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onReintentar,
          icon:  const Icon(Icons.refresh),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white),
        ),
      ],
    ),
  );
}