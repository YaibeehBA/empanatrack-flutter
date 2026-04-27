import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/colores.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/ubicacion_service.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────────

class DatosMapaRuta {
  final bool    tieneEmpresa;
  final bool    rutaActiva;
  final String? vendedorNombre;
  final String? vendedorId;
  final String? sesionId;
  final String? rutaNombre;
  final String? mensaje;
  final List<EmpresaMapaCliente> empresas;
  final int     totalEmpresas;
  final int     empresasVisitadas;
  final int     empresasAntesCliente;
  final bool    miEmpresaVisitada;
  final int     ordenMiEmpresa;

  const DatosMapaRuta({
    required this.tieneEmpresa,
    required this.rutaActiva,
    this.vendedorNombre,
    this.vendedorId,
    this.sesionId,
    this.rutaNombre,
    this.mensaje,
    required this.empresas,
    required this.totalEmpresas,
    required this.empresasVisitadas,
    required this.empresasAntesCliente,
    required this.miEmpresaVisitada,
    required this.ordenMiEmpresa,
  });

  factory DatosMapaRuta.fromJson(Map<String, dynamic> j) => DatosMapaRuta(
        tieneEmpresa:         j['tiene_empresa']          ?? false,
        rutaActiva:           j['ruta_activa']            ?? false,
        vendedorNombre:       j['vendedor_nombre'],
        vendedorId:           j['vendedor_id'],
        sesionId:             j['sesion_id'],
        rutaNombre:           j['ruta_nombre'],
        mensaje:              j['mensaje'],
        empresas: (j['empresas'] as List? ?? [])
            .map((e) => EmpresaMapaCliente.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalEmpresas:        j['total_empresas']         ?? 0,
        empresasVisitadas:    j['empresas_visitadas']     ?? 0,
        empresasAntesCliente: j['empresas_antes_cliente'] ?? 0,
        miEmpresaVisitada:    j['mi_empresa_visitada']    ?? false,
        ordenMiEmpresa:       j['orden_mi_empresa']       ?? 0,
      );
}

class EmpresaMapaCliente {
  final String  id;
  final String  nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final int     orden;
  final bool    visitada;
  final bool    esMiEmpresa;

  const EmpresaMapaCliente({
    required this.id,
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
    required this.orden,
    required this.visitada,
    required this.esMiEmpresa,
  });

  bool get tieneCoordenadas => latitud != null && longitud != null;

  factory EmpresaMapaCliente.fromJson(Map<String, dynamic> j) =>
      EmpresaMapaCliente(
        id:          j['id']           as String,
        nombre:      j['nombre']       as String,
        direccion:   j['direccion']    as String?,
        latitud:     j['latitud']  != null
            ? (j['latitud']  as num).toDouble() : null,
        longitud:    j['longitud'] != null
            ? (j['longitud'] as num).toDouble() : null,
        orden:       j['orden']        as int,
        visitada:    j['visitada']     as bool? ?? false,
        esMiEmpresa: j['es_mi_empresa'] as bool? ?? false,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final mapaRutaClienteProvider =
    FutureProvider.autoDispose<DatosMapaRuta>((ref) async {
  final r = await ApiClient.get('/clientes/mapa-ruta');
  return DatosMapaRuta.fromJson(r.data as Map<String, dynamic>);
});

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class MapaVendedorScreen extends ConsumerStatefulWidget {
  const MapaVendedorScreen({super.key});

  @override
  ConsumerState<MapaVendedorScreen> createState() =>
      _MapaVendedorScreenState();
}

class _MapaVendedorScreenState
    extends ConsumerState<MapaVendedorScreen> {
  final _mapCtrl = MapController();
  final _mapaSvc = MapaRutaClienteService();

  LatLng?   _posVendedor;
  LatLng?   _posAnterior;
  EstadoWs  _estadoWs = EstadoWs.desconectado;
  bool      _panelExpandido = true;

  StreamSubscription<Map<String, dynamic>>? _posSub;
  StreamSubscription<EstadoWs>?             _estadoSub;
  String?                                   _sesionConectada;

  @override
  void dispose() {
    _posSub?.cancel();
    _estadoSub?.cancel();
    _mapaSvc.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _conectarWs(DatosMapaRuta datos) async {
    if (!datos.rutaActiva) return;
    final sesionId = datos.sesionId;
    if (sesionId == null || sesionId == _sesionConectada) return;

    final sesion = ref.read(authProvider).sesion;
    if (sesion == null) return;

    _sesionConectada = sesionId;

    _posSub    = _mapaSvc.posicion.listen(_onPosicion);
    _estadoSub = _mapaSvc.estadoConexion.listen(_onEstado);

    await _mapaSvc.conectar(
      token:    sesion.token,
      baseUrl:  ApiClient.baseUrl,
      sesionId: sesionId,
    );
  }

  void _onPosicion(Map<String, dynamic> pos) {
    if (!mounted) return;
    final nueva = LatLng(
      pos['lat'] as double,
      pos['lng'] as double,
    );
    setState(() {
      _posAnterior = _posVendedor;
      _posVendedor = nueva;
    });
    if (_posVendedor != null) {
      _mapCtrl.move(nueva, _mapCtrl.camera.zoom);
    }
  }

  void _onEstado(EstadoWs estado) {
    if (!mounted) return;
    setState(() => _estadoWs = estado);
  }

  void _centrarEnMiEmpresa(DatosMapaRuta datos) {
    final miEmp = datos.empresas
        .where((e) => e.esMiEmpresa && e.tieneCoordenadas)
        .firstOrNull;
    if (miEmp != null) {
      _mapCtrl.move(LatLng(miEmp.latitud!, miEmp.longitud!), 16);
    }
  }

  void _centrarEnVendedor() {
    if (_posVendedor != null) {
      _mapCtrl.move(_posVendedor!, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapaRutaClienteProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Mi Vendedor',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () {
              _sesionConectada = null;
              ref.invalidate(mapaRutaClienteProvider);
            },
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(onReintentar: () {
          _sesionConectada = null;
          ref.invalidate(mapaRutaClienteProvider);
        }),
        data: (datos) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _conectarWs(datos),
          );
          if (!datos.tieneEmpresa) {
            return _SinEmpresaView(mensaje: datos.mensaje);
          }
          if (!datos.rutaActiva) {
            return _RutaNoIniciadaView(datos: datos);
          }
          return _MapaActivo(
            datos:           datos,
            posVendedor:     _posVendedor,
            estadoWs:        _estadoWs,
            mapCtrl:         _mapCtrl,
            panelExpandido:  _panelExpandido,
            onTogglePanel:   () => setState(
                () => _panelExpandido = !_panelExpandido),
            onCentrarEmpresa: () => _centrarEnMiEmpresa(datos),
            onCentrarVendedor: _centrarEnVendedor,
            onRecargar: () {
              _sesionConectada = null;
              ref.invalidate(mapaRutaClienteProvider);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA MAPA ACTIVO - CON UI LIMPIA Y ESCALABLE
// ─────────────────────────────────────────────────────────────────────────────

class _MapaActivo extends StatelessWidget {
  final DatosMapaRuta datos;
  final LatLng?       posVendedor;
  final EstadoWs      estadoWs;
  final MapController mapCtrl;
  final bool          panelExpandido;
  final VoidCallback  onTogglePanel;
  final VoidCallback  onCentrarEmpresa;
  final VoidCallback  onCentrarVendedor;
  final VoidCallback  onRecargar;

  const _MapaActivo({
    required this.datos,
    required this.posVendedor,
    required this.estadoWs,
    required this.mapCtrl,
    required this.panelExpandido,
    required this.onTogglePanel,
    required this.onCentrarEmpresa,
    required this.onCentrarVendedor,
    required this.onRecargar,
  });

  LatLng get _centro {
    if (posVendedor != null) return posVendedor!;
    final miEmp = datos.empresas
        .where((e) => e.esMiEmpresa && e.tieneCoordenadas)
        .firstOrNull;
    if (miEmp != null) return LatLng(miEmp.latitud!, miEmp.longitud!);
    final primera = datos.empresas
        .where((e) => e.tieneCoordenadas)
        .firstOrNull;
    return primera != null
        ? LatLng(primera.latitud!, primera.longitud!)
        : const LatLng(-1.66, -78.65);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Stack(children: [
      // Mapa
      FlutterMap(
        mapController: mapCtrl,
        options: MapOptions(
          initialCenter: _centro,
          initialZoom:   14,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.empanatrack.app',
          ),
          MarkerLayer(markers: [
            for (final emp in datos.empresas)
              if (emp.tieneCoordenadas)
                Marker(
                  point:  LatLng(emp.latitud!, emp.longitud!),
                  width:  emp.esMiEmpresa ? 170 : 130,
                  height: 56,
                  child:  _EmpresaMarker(empresa: emp),
                ),
            if (posVendedor != null)
              Marker(
                point:  posVendedor!,
                width:  44,
                height: 56,
                child:  _VendedorMarker(
                    nombre: datos.vendedorNombre ?? 'Vendedor'),
              ),
          ]),
        ],
      ),

      // Header
      Positioned(
        top: 0, left: 0, right: 0,
        child: _HeaderInfo(datos: datos, estadoWs: estadoWs),
      ),

      // FABs
      Positioned(
        right:  16,
        bottom: panelExpandido ? 230 : 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (posVendedor != null) ...[
              FloatingActionButton.small(
                heroTag:         'centrar_vendedor',
                backgroundColor: AppColores.accent,
                foregroundColor: Colors.white,
                onPressed:       onCentrarVendedor,
                tooltip:         'Ver vendedor',
                child: const Icon(
                    Icons.directions_walk_rounded, size: 18),
              ),
              const SizedBox(height: 8),
            ],
            FloatingActionButton.small(
              heroTag:         'centrar_empresa',
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white,
              onPressed:       onCentrarEmpresa,
              tooltip:         'Mi empresa',
              child: const Icon(Icons.business_rounded, size: 18),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag:         'recargar_mapa_v',
              backgroundColor: Colors.white,
              foregroundColor: AppColores.primary,
              onPressed:       onRecargar,
              tooltip:         'Actualizar',
              child: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
      ),

      // Panel inferior REDISEÑADO - Limpio y escalable
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: _PanelInferiorRedisenado(
          datos:         datos,
          expandido:     panelExpandido,
          onToggle:      onTogglePanel,
          bottomPadding: bottom,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER (sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderInfo extends StatelessWidget {
  final DatosMapaRuta datos;
  final EstadoWs      estadoWs;

  const _HeaderInfo({required this.datos, required this.estadoWs});

  ({String texto, Color color}) get _wsInfo => switch (estadoWs) {
    EstadoWs.conectado    => (texto: 'En vivo',       color: AppColores.success),
    EstadoWs.conectando   => (texto: 'Conectando…',   color: Colors.amber),
    EstadoWs.reconectando => (texto: 'Reconectando…', color: Colors.orange),
    EstadoWs.error        => (texto: 'Error',         color: AppColores.danger),
    EstadoWs.desconectado => (texto: 'Sin señal',     color: Colors.white54),
  };

  @override
  Widget build(BuildContext context) {
    final info = _wsInfo;
    return Container(
      color: AppColores.primary,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 10,
        bottom: 12, left: 16, right: 16,
      ),
      child: Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.route_rounded,
                color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Flexible(child: Text(
              datos.vendedorNombre ?? 'Vendedor',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${datos.empresasVisitadas}/${datos.totalEmpresas}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        )),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:        info.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: info.color.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: info.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(info.texto,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL INFERIOR REDISEÑADO - Estilo Uber/Rappi/Google Maps
// ─────────────────────────────────────────────────────────────────────────────

class _PanelInferiorRedisenado extends StatelessWidget {
  final DatosMapaRuta datos;
  final bool          expandido;
  final VoidCallback  onToggle;
  final double        bottomPadding;

  const _PanelInferiorRedisenado({
    required this.datos,
    required this.expandido,
    required this.onToggle,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    curve:    Curves.easeInOut,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [BoxShadow(
          color: Colors.black12, blurRadius: 16,
          offset: Offset(0, -2))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle + botón toggle
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              const Spacer(),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Spacer(),
              Icon(
                expandido
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: AppColores.textSecond, size: 20,
              ),
            ]),
          ),
        ),

        if (expandido) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: datos.miEmpresaVisitada
                ? const _BannerVisitadaRedisenado()
                : _InfoProximaVisitaRedisenado(datos: datos),
          ),
          const SizedBox(height: 16),
          _ListaEmpresasRedisenada(empresas: datos.empresas),
          SizedBox(height: bottomPadding + 8),
        ] else
          SizedBox(height: bottomPadding + 4),
      ],
    ),
  );
}

// Banner visitada rediseñado
class _BannerVisitadaRedisenado extends StatelessWidget {
  const _BannerVisitadaRedisenado();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppColores.success.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColores.success.withOpacity(0.3)),
    ),
    child: const Row(children: [
      Icon(Icons.check_circle, color: AppColores.success, size: 24),
      SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Empresa visitada hoy',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.success,
                  fontSize:   14)),
          SizedBox(height: 2),
          Text('El vendedor ya completó la visita',
              style: TextStyle(
                  fontSize: 12, color: AppColores.textSecond)),
        ],
      )),
    ]),
  );
}

// Info próxima visita rediseñada
class _InfoProximaVisitaRedisenado extends StatelessWidget {
  final DatosMapaRuta datos;
  const _InfoProximaVisitaRedisenado({required this.datos});

  @override
  Widget build(BuildContext context) {
    final faltan = datos.empresasAntesCliente;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.primary,
            AppColores.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(faltan == 0 ? Icons.flag : Icons.store,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              faltan == 0
                  ? '¡Siguiente parada!'
                  : faltan == 1
                      ? '1 parada antes que tú'
                      : '$faltan paradas antes que tú',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              faltan == 0
                  ? 'El vendedor va directo a tu empresa'
                  : 'El vendedor está en camino hacia ti',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12),
            ),
          ],
        )),
      ]),
    );
  }
}

// LISTA DE EMPRESAS REDISEÑADA - Scroll interno con diseño tipo lista moderna
class _ListaEmpresasRedisenada extends StatelessWidget {
  final List<EmpresaMapaCliente> empresas;
  const _ListaEmpresasRedisenada({required this.empresas});

  @override
  Widget build(BuildContext context) {
    if (empresas.isEmpty) return const SizedBox.shrink();

    // Separamos las empresas visitadas y no visitadas
    final visitadas = empresas.where((e) => e.visitada).toList();
    final pendientes = empresas.where((e) => !e.visitada).toList();
    final miEmpresa = empresas.where((e) => e.esMiEmpresa).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini resumen compacto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.route, size: 14, color: AppColores.textSecond),
                const SizedBox(width: 6),
                Text(
                  'Ruta del vendedor • ${empresas.length} paradas',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textSecond,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Scroll interno para la lista de empresas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: empresas.length,
              itemBuilder: (context, index) {
                final empresa = empresas[index];
                final esUltima = index == empresas.length - 1;
                
                return Column(
                  children: [
                    _EmpresaListTile(empresa: empresa, index: index + 1),
                    if (!esUltima) const _ListDivider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Item de empresa estilo lista moderna
class _EmpresaListTile extends StatelessWidget {
  final EmpresaMapaCliente empresa;
  final int index;

  const _EmpresaListTile({
    required this.empresa,
    required this.index,
  });

  Color get _statusColor {
    if (empresa.visitada) return AppColores.success;
    if (empresa.esMiEmpresa) return AppColores.primary;
    return Colors.grey.shade400;
  }

  IconData get _statusIcon {
    if (empresa.visitada) return Icons.check_circle;
    if (empresa.esMiEmpresa) return Icons.location_on;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Número de orden circular
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: _statusColor,
                width: empresa.esMiEmpresa ? 2 : 1,
              ),
            ),
            child: Center(
              child: empresa.visitada
                  ? Icon(Icons.check, size: 16, color: _statusColor)
                  : Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _statusColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Información de la empresa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        empresa.nombre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: empresa.esMiEmpresa
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: empresa.visitada
                              ? AppColores.success
                              : AppColores.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (empresa.esMiEmpresa && !empresa.visitada)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColores.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TU EMPRESA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (empresa.direccion != null && empresa.direccion!.isNotEmpty)
                  Text(
                    empresa.direccion!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColores.textSecond,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Indicador de estado
          Icon(
            _statusIcon,
            color: _statusColor,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// Divisor entre items
class _ListDivider extends StatelessWidget {
  const _ListDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        height: 1,
        color: Colors.grey.shade200,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARCADORES (sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _EmpresaMarker extends StatelessWidget {
  final EmpresaMapaCliente empresa;
  const _EmpresaMarker({required this.empresa});

  Color get _color {
    if (empresa.visitada)    return AppColores.success;
    if (empresa.esMiEmpresa) return AppColores.primary;
    return const Color(0xFF607D8B);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withOpacity(0.5),
                width: empresa.esMiEmpresa ? 2 : 1),
            boxShadow: [BoxShadow(
                color:      Colors.black.withOpacity(0.15),
                blurRadius: 4)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (empresa.esMiEmpresa)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Text('⭐', style: TextStyle(fontSize: 9)),
              ),
            Icon(
              empresa.visitada
                  ? Icons.check_circle
                  : Icons.store_outlined,
              size: 10, color: color,
            ),
            const SizedBox(width: 3),
            Flexible(child: Text(
              empresa.nombre.length > 14
                  ? '${empresa.nombre.substring(0, 14)}…'
                  : empresa.nombre,
              style: TextStyle(
                  fontSize:   9,
                  fontWeight: empresa.esMiEmpresa
                      ? FontWeight.bold : FontWeight.normal,
                  color:      color),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
        Icon(
          empresa.esMiEmpresa
              ? Icons.location_on_rounded
              : empresa.visitada
                  ? Icons.check_circle
                  : Icons.location_on,
          color: color,
          size:  empresa.esMiEmpresa ? 22 : 18,
        ),
      ],
    );
  }
}

class _VendedorMarker extends StatelessWidget {
  final String nombre;
  const _VendedorMarker({required this.nombre});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        AppColores.accent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(
              color:      AppColores.accent.withOpacity(0.4),
              blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.directions_walk_rounded,
              color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            nombre.split(' ').first,
            style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ]),
      ),
      Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color:  AppColores.accent,
          shape:  BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(
              color:       AppColores.accent.withOpacity(0.5),
              blurRadius:  8,
              spreadRadius: 2)],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTAS DE ESTADO (sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _SinEmpresaView extends StatelessWidget {
  final String? mensaje;
  const _SinEmpresaView({this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏢', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          const Text('Sin empresa asignada',
              style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
          const SizedBox(height: 10),
          Text(
            mensaje ??
                'No estás asociado a ninguna empresa. '
                'Contacta al administrador.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColores.textSecond, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class _RutaNoIniciadaView extends StatelessWidget {
  final DatosMapaRuta datos;
  const _RutaNoIniciadaView({required this.datos});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          const Text('Ruta no iniciada',
              style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      AppColores.textPrimary)),
          const SizedBox(height: 10),
          Text(
            datos.mensaje ??
                (datos.vendedorNombre != null
                    ? '${datos.vendedorNombre} aún no inicia su ruta.'
                    : 'No hay vendedor asignado a tu empresa.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColores.textSecond, fontSize: 14),
          ),
          if (datos.vendedorNombre != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColores.primary.withOpacity(0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.person_outline_rounded,
                    color: AppColores.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tu vendedor',
                        style: TextStyle(
                            fontSize: 11,
                            color:    AppColores.textSecond)),
                    Text(datos.vendedorNombre!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color:      AppColores.primary,
                            fontSize:   14)),
                  ],
                )),
              ]),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorView({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('No se pudo cargar el mapa',
            style: TextStyle(color: AppColores.textSecond)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onReintentar,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primary,
              foregroundColor: Colors.white),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}