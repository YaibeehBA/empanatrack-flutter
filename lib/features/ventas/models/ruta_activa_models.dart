
// ── Empresa en la ruta ────────────────────────────────────
class EmpresaRuta {
  final String  id;
  final String  nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final int     orden;
  final bool    visitada;
  final String? llegadaEn; // ← NUEVO

  const EmpresaRuta({
    required this.id,
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
    required this.orden,
    required this.visitada,
    this.llegadaEn,        // ← NUEVO
  });

  bool get tieneCoordenadas => latitud != null && longitud != null;

  // Llegada registrada en backend (para recuperar timer al reentrar)
  DateTime? get llegadaDateTime {
    if (llegadaEn == null) return null;
    try { return DateTime.parse(llegadaEn!).toLocal(); }
    catch (_) { return null; }
  }

  factory EmpresaRuta.fromJson(Map<String, dynamic> j) => EmpresaRuta(
    id:        j['id'],
    nombre:    j['nombre'],
    direccion: j['direccion'],
    latitud:   j['latitud']   != null
        ? (j['latitud']   as num).toDouble() : null,
    longitud:  j['longitud']  != null
        ? (j['longitud']  as num).toDouble() : null,
    orden:     j['orden'],
    visitada:  j['visitada']  ?? false,
    llegadaEn: j['llegada_en'],  // ← NUEVO
  );

  EmpresaRuta copyWith({bool? visitada, String? llegadaEn}) =>
      EmpresaRuta(
        id:        id,
        nombre:    nombre,
        direccion: direccion,
        latitud:   latitud,
        longitud:  longitud,
        orden:     orden,
        visitada:  visitada  ?? this.visitada,
        llegadaEn: llegadaEn ?? this.llegadaEn,
      );
}
// ── Sesión activa ─────────────────────────────────────────
class SesionRuta {
  final String  id;
  final String  estado;
  final String? iniciadaEn;

  const SesionRuta({
    required this.id,
    required this.estado,
    this.iniciadaEn,
  });

  factory SesionRuta.fromJson(Map<String, dynamic> j) => SesionRuta(
    id:        j['id'],
    estado:    j['estado'],
    iniciadaEn: j['iniciada_en'],
  );
}

// ── Estado completo del día ───────────────────────────────
class EstadoRutaHoy {
  final bool             tieneRuta;
  final bool             stockLleno;
  final String?          asignacionId;
  final String?          rutaId;
  final String?          rutaNombre;
  final String?          turno;
  final SesionRuta?      sesion;
  final List<EmpresaRuta> empresas;
  final int              total;
  final int              visitadas;
  final bool             completada;
  final bool             sesionCompletada;

  const EstadoRutaHoy({
    required this.tieneRuta,
    required this.stockLleno,
    this.asignacionId,
    this.rutaId,
    this.rutaNombre,
    this.turno,
    this.sesion,
    required this.empresas,
    required this.total,
    required this.visitadas,
    required this.completada,
    this.sesionCompletada = false,
  });

  factory EstadoRutaHoy.fromJson(Map<String, dynamic> j) => EstadoRutaHoy(
    tieneRuta:        j['tiene_ruta']        ?? false,
    stockLleno:       j['stock_lleno']       ?? false,
    asignacionId:     j['asignacion_id'],
    rutaId:           j['ruta_id'],
    rutaNombre:       j['ruta_nombre'],
    turno:            j['turno'],
    sesion: j['sesion'] != null
        ? SesionRuta.fromJson(j['sesion']) : null,
    empresas: j['empresas'] != null
        ? (j['empresas'] as List)
            .map((e) => EmpresaRuta.fromJson(e))
            .toList()
        : [],
    total:            j['total']             ?? 0,
    visitadas:        j['visitadas']         ?? 0,
    completada:       j['completada']        ?? false,
    sesionCompletada: j['sesion_completada'] ?? false, 
  );

  EstadoRutaHoy marcarVisitada(String empresaId) {
    final nuevas = empresas.map((e) =>
        e.id == empresaId ? e.copyWith(visitada: true) : e).toList();
    final nv = nuevas.where((e) => e.visitada).length;
    return EstadoRutaHoy(
      tieneRuta:        tieneRuta,
      stockLleno:       stockLleno,
      asignacionId:     asignacionId,
      rutaId:           rutaId,
      rutaNombre:       rutaNombre,
      turno:            turno,
      sesion:           sesion,
      empresas:         nuevas,
      total:            total,
      visitadas:        nv,
      completada:       nv >= total,
      sesionCompletada: sesionCompletada,
    );
  }
}

// ── Producto para stock ───────────────────────────────────
class ProductoStock {
  final String  productoId;
  final String  nombre;
  final double  precio;
  final String? imagenUrl;
  int           cantidad;

  ProductoStock({
    required this.productoId,
    required this.nombre,
    required this.precio,
    this.imagenUrl,
    required this.cantidad,
  });

  factory ProductoStock.fromJson(Map<String, dynamic> j) => ProductoStock(
    productoId: j['producto_id'],
    nombre:     j['nombre'],
    precio:     (j['precio'] as num).toDouble(),
    imagenUrl:  j['imagen_url'],
    cantidad:   j['cantidad'] ?? 0,
  );
}

// ── Resumen final ─────────────────────────────────────────
class ResumenRutaFinal {
  final int    empresasVisitadas;
  final int    totalVentas;
  final double totalVendido;
  final double totalContado;
  final double totalFiado;
  final double totalCobrado;
  final double dineroEnMano;
  final int?   duracionMinutos;

  const ResumenRutaFinal({
    required this.empresasVisitadas,
    required this.totalVentas,
    required this.totalVendido,
    required this.totalContado,
    required this.totalFiado,
    required this.totalCobrado,
    required this.dineroEnMano,
    this.duracionMinutos,
  });

  factory ResumenRutaFinal.fromJson(Map<String, dynamic> j) => ResumenRutaFinal(
    empresasVisitadas: j['empresas_visitadas'] ?? 0,
    totalVentas:       j['total_ventas']       ?? 0,
    totalVendido:      (j['total_vendido']  as num).toDouble(),
    totalContado:      (j['total_contado']  as num).toDouble(),
    totalFiado:        (j['total_fiado']    as num).toDouble(),
    totalCobrado:      (j['total_cobrado']  as num).toDouble(),
    dineroEnMano:      (j['dinero_en_mano'] as num).toDouble(),
    duracionMinutos:   j['duracion_minutos'],
  );
}

// ── Fase del mapa ─────────────────────────────────────────
enum FaseRuta { cargando, sinRuta, llenarStock, listo, enRuta, completada }



class ProductoStockRestante {
  final String  productoId;
  final String  nombre;
  final double  precio;
  final String? imagenUrl;
  final int     cantidadInicial;
  final int     cantidadVendida;
  final int     cantidadReservada; 
  final int     cantidadRestante;
  final bool    enStockHoy;  
  int? cantidad;     // ← NUEVO

   ProductoStockRestante({
    required this.productoId,
    required this.nombre,
    required this.precio,
    this.imagenUrl,
    required this.cantidadInicial,
    required this.cantidadVendida,
    this.cantidadReservada = 0,
    required this.cantidadRestante,
    this.enStockHoy = true,  
    this.cantidad,     // ← NUEVO
  });

  factory ProductoStockRestante.fromJson(Map<String, dynamic> j) =>
      ProductoStockRestante(
        productoId:       j['producto_id'],
        nombre:           j['nombre'],
        precio:           (j['precio'] as num).toDouble(),
        imagenUrl:        j['imagen_url'],
        cantidadInicial:  j['cantidad_inicial']  ?? 0,
        cantidadVendida:  j['cantidad_vendida']   ?? 0,
        cantidadReservada: j['cantidad_reservada'] ?? 0,
        cantidadRestante: j['cantidad_restante']  ?? 0,
        enStockHoy:       j['en_stock_hoy']       ?? true,
      );
}

class StockRestanteHoy {
  final List<ProductoStockRestante> productos;
  final int  totalRestante;
  final bool sinStock;
  final bool stockCargado; 

  const StockRestanteHoy({
    required this.productos,
    required this.totalRestante,
    required this.sinStock,
    required this.stockCargado,
  });

  factory StockRestanteHoy.fromJson(Map<String, dynamic> j) =>
      StockRestanteHoy(
        productos: (j['productos'] as List)
            .map((p) => ProductoStockRestante.fromJson(p))
            .toList(),
        totalRestante: j['total_restante'] ?? 0,
        sinStock:      j['sin_stock'] ?? false,
        stockCargado:  j['stock_cargado'] ?? false,
      );
}