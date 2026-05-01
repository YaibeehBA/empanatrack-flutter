// ══════════════════════════════════════════════════════════
//  Modelo base compartido entre repartidor y vendedor
// ══════════════════════════════════════════════════════════
class PedidoBase {
  final String  id;
  final String  tipo;          // normal | reserva
  final String  clienteId;      // ← NUEVO: solo esto
  final String  clienteNombre;
  final String? clienteTelefono;
  final String? vendedorId;
  final String? vendedorNombre;
  final String? repartidorId;
  final String? repartidorNombre;
  final String? empresaId;
  final String? empresaNombre;
  final String  estado;
  final String  tipoPago;
  final double  total;
  final double  costoEnvio;
  final String? direccionEntrega;
  final double? latitudEntrega;
  final double? longitudEntrega;
  final String? notas;
  final String? aceptadoEn;
  final String  creadoEn;
  final List<Map<String, dynamic>> items;

  const PedidoBase({
    required this.id,
    required this.tipo,
    required this.clienteId,        // ← NUEVO
    required this.clienteNombre,
    this.clienteTelefono,
    this.vendedorId,
    this.vendedorNombre,
    this.repartidorId,
    this.repartidorNombre,
    this.empresaId,
    this.empresaNombre,
    required this.estado,
    required this.tipoPago,
    required this.total,
    required this.costoEnvio,
    this.direccionEntrega,
    this.latitudEntrega,
    this.longitudEntrega,
    this.notas,
    this.aceptadoEn,
    required this.creadoEn,
    required this.items,
  });

  bool get tieneCoordenadas =>
      latitudEntrega != null && longitudEntrega != null;

  bool get esReserva => tipo == 'reserva';

  String get estadoLabel {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'aceptado':  return 'Aceptado';
      case 'en_camino': return 'En camino';
      case 'entregado': return 'Entregado';
      case 'cancelado': return 'Cancelado';
      default:          return estado;
    }
  }

  factory PedidoBase.fromJson(Map<String, dynamic> j) => PedidoBase(
    id:               j['id'],
    tipo:             j['tipo']           ?? 'normal',
    clienteId:        j['cliente_id']     ?? '',  // ← NUEVO
    clienteNombre:    j['cliente_nombre'] ?? '',
    clienteTelefono:  j['cliente_telefono'],
    vendedorId:       j['vendedor_id'],
    vendedorNombre:   j['vendedor_nombre'],
    repartidorId:     j['repartidor_id'],
    repartidorNombre: j['repartidor_nombre'],
    empresaId:        j['empresa_id'],
    empresaNombre:    j['empresa_nombre'],
    estado:           j['estado']         ?? 'pendiente',
    tipoPago:         j['tipo_pago']      ?? 'contraentrega',
    total:       (j['total']      as num).toDouble(),
    costoEnvio:  (j['costo_envio'] as num? ?? 0).toDouble(),
    direccionEntrega: j['direccion_entrega'],
    latitudEntrega:  j['latitud_entrega']  != null
        ? (j['latitud_entrega']  as num).toDouble() : null,
    longitudEntrega: j['longitud_entrega'] != null
        ? (j['longitud_entrega'] as num).toDouble() : null,
    notas:       j['notas'],
    aceptadoEn:  j['aceptado_en'],
    creadoEn:    j['creado_en'] ?? '',
    items: (j['items'] as List? ?? [])
        .map((i) => i as Map<String, dynamic>)
        .toList(),
  );
}

// Alias para no romper código existente
typedef PedidoVendedor = PedidoBase;
typedef PedidoCliente  = PedidoBase;