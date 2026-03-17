import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/cliente_model.dart';

final clientesProvider = FutureProvider<List<ClienteModel>>((ref) async {
  final response = await ApiClient.get('/clientes/');
  final lista    = response.data as List;
  return lista.map((c) => ClienteModel.fromJson(c)).toList();
});

// ══════════════════════════════════════════════════════════
//  PROVIDER PAGINADO
// ══════════════════════════════════════════════════════════
final clientesPaginadosProvider =
    StateNotifierProvider<ClientesPaginadosNotifier, ClientesPaginadosState>(
  (ref) => ClientesPaginadosNotifier(),
);

class ClientesPaginadosState {
  final List<ClienteModel> clientes;
  final int                pagina;
  final bool               hayMas;
  final bool               cargando;
  final bool               cargandoMas;
  final String?            error;
  final String             busqueda;

  const ClientesPaginadosState({
    this.clientes    = const [],
    this.pagina      = 1,
    this.hayMas      = true,
    this.cargando    = false,
    this.cargandoMas = false,
    this.error,
    this.busqueda    = '',
  });

  ClientesPaginadosState copyWith({
    List<ClienteModel>? clientes,
    int?                pagina,
    bool?               hayMas,
    bool?               cargando,
    bool?               cargandoMas,
    String?             error,
    String?             busqueda,
  }) =>
      ClientesPaginadosState(
        clientes:    clientes    ?? this.clientes,
        pagina:      pagina      ?? this.pagina,
        hayMas:      hayMas      ?? this.hayMas,
        cargando:    cargando    ?? this.cargando,
        cargandoMas: cargandoMas ?? this.cargandoMas,
        error:       error,
        busqueda:    busqueda    ?? this.busqueda,
      );
}

class ClientesPaginadosNotifier extends StateNotifier<ClientesPaginadosState> {
  ClientesPaginadosNotifier() : super(const ClientesPaginadosState()) {
    cargarPrimera();
  }

  static const int _porPagina = 20;

  Future<void> cargarPrimera({String busqueda = ''}) async {
    state = state.copyWith(
      cargando: true,
      pagina: 1,
      hayMas: true,
      clientes: [],
      busqueda: busqueda,
    );
    try {
      final r = await ApiClient.get('/clientes/', params: {
        'pagina': 1,
        'por_pagina': _porPagina,
        if (busqueda.isNotEmpty) 'buscar': busqueda,
      });
      final lista = (r.data['clientes'] as List)
          .map((c) => ClienteModel.fromJson(c))
          .toList();
      state = state.copyWith(
        cargando: false,
        clientes: lista,
        pagina: 1,
        hayMas: lista.length == _porPagina,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        error: 'Error al cargar clientes',
      );
    }
  }

  Future<void> cargarMas() async {
    if (!state.hayMas || state.cargandoMas) return;
    state = state.copyWith(cargandoMas: true);
    try {
      final sig = state.pagina + 1;
      final r = await ApiClient.get('/clientes/', params: {
        'pagina': sig,
        'por_pagina': _porPagina,
        if (state.busqueda.isNotEmpty) 'buscar': state.busqueda,
      });
      final lista = (r.data['clientes'] as List)
          .map((c) => ClienteModel.fromJson(c))
          .toList();
      state = state.copyWith(
        cargandoMas: false,
        clientes: [...state.clientes, ...lista],
        pagina: sig,
        hayMas: lista.length == _porPagina,
      );
    } catch (_) {
      state = state.copyWith(cargandoMas: false);
    }
  }

  void resetBusqueda() {
    if (state.busqueda.isNotEmpty) {
      cargarPrimera();
    }
  }
}