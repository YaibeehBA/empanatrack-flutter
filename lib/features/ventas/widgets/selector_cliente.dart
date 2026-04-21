import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../shared/models/cliente_model.dart';

class SelectorCliente extends StatefulWidget {
  final List<ClienteModel> clientes;
  final ClienteModel? seleccionado;
  final TextEditingController buscarCtrl;
  final Function(ClienteModel) onSeleccionar;

  const SelectorCliente({
    required this.clientes,
    required this.seleccionado,
    required this.buscarCtrl,
    required this.onSeleccionar,
    super.key,
  });

  @override
  State<SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends State<SelectorCliente> {
  bool _mostrarLista = false;

  List<ClienteModel> get _filtrados {
    final q = widget.buscarCtrl.text.toLowerCase();
    if (q.isEmpty) return widget.clientes;
    return widget.clientes
        .where(
          (c) => c.nombre.toLowerCase().contains(q) || c.cedula.contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ClienteSelector(
        seleccionado: widget.seleccionado,
        mostrarLista: _mostrarLista,
        onTap: () => setState(() => _mostrarLista = !_mostrarLista),
      ),
      if (_mostrarLista) ...[
        const SizedBox(height: 8),
        _ClienteDropdown(
          filtrados: _filtrados,
          buscarCtrl: widget.buscarCtrl,
          onSeleccionar: (c) {
            widget.onSeleccionar(c);
            widget.buscarCtrl.clear();
            setState(() => _mostrarLista = false);
          },
          onBuscarChanged: () => setState(() {}),
          onRegistrarNuevo: () async {
            setState(() => _mostrarLista = false);
            final nuevoCliente = await context.push<ClienteModel>(
              '/nuevo-cliente',
              extra: true,
            );
            if (nuevoCliente != null) {
              widget.onSeleccionar(nuevoCliente);
            }
          },
        ),
      ],
    ],
  );
}

class _ClienteSelector extends StatelessWidget {
  final ClienteModel? seleccionado;
  final bool mostrarLista;
  final VoidCallback onTap;

  const _ClienteSelector({
    required this.seleccionado,
    required this.mostrarLista,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seleccionado != null
              ? AppColores.accent
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColores.textSecond),
          const SizedBox(width: 12),
          Expanded(
            child: seleccionado != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seleccionado!.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColores.textPrimary,
                        ),
                      ),
                      Text(
                        'CI: ${seleccionado!.cedula}  •  '
                        '${seleccionado!.empresa ?? 'Independiente'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textSecond,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Seleccionar cliente...',
                    style: TextStyle(color: AppColores.textSecond),
                  ),
          ),
          Icon(
            mostrarLista ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColores.textSecond,
          ),
        ],
      ),
    ),
  );
}

class _ClienteDropdown extends StatelessWidget {
  final List<ClienteModel> filtrados;
  final TextEditingController buscarCtrl;
  final Function(ClienteModel) onSeleccionar;
  final VoidCallback onBuscarChanged;
  final VoidCallback onRegistrarNuevo;

  const _ClienteDropdown({
    required this.filtrados,
    required this.buscarCtrl,
    required this.onSeleccionar,
    required this.onBuscarChanged,
    required this.onRegistrarNuevo,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: buscarCtrl,
            autofocus: true,
            onChanged: (_) => onBuscarChanged(),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o cédula...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              filled: true,
              fillColor: AppColores.background,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtrados.length,
            itemBuilder: (ctx, i) {
              final c = filtrados[i];
              return ListTile(
                title: Text(
                  c.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${c.empresa ?? 'Independiente'}  •  CI: ${c.cedula}',
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColores.accent.withOpacity(0.15),
                  child: Text(
                    c.nombre[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColores.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => onSeleccionar(c),
              );
            },
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColores.success.withOpacity(0.15),
            child: const Icon(
              Icons.person_add_outlined,
              color: AppColores.success,
            ),
          ),
          title: const Text(
            '+ Registrar nuevo cliente',
            style: TextStyle(
              color: AppColores.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text('El cliente no está en la lista'),
          onTap: onRegistrarNuevo,
        ),
      ],
    ),
  );
}
