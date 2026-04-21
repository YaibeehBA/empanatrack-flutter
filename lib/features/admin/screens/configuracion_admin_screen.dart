import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colores.dart';
import '../providers/admin_provider.dart';

class ConfiguracionAdminScreen extends ConsumerWidget {
  const ConfiguracionAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configuracionAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: const Text('Configuración del negocio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(configuracionAdminProvider),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error cargando configuración'),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(configuracionAdminProvider),
              child: const Text('Reintentar'),
            ),
          ],
        )),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // Banner informativo
            Container(
              padding: const EdgeInsets.all(14),
              margin:  const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color:        AppColores.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColores.primary.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Text('⚙️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configuración del negocio',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColores.textPrimary)),
                    SizedBox(height: 2),
                    Text(
                      'Estos valores afectan toda la app. '
                      'Toca cualquier campo para editarlo.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColores.textSecond),
                    ),
                  ],
                )),
              ]),
            ),

            // Sección WhatsApp y Banco
            _SecLabel('📱 CONTACTO Y PAGOS'),
            const SizedBox(height: 10),
            ...items
                .where((c) => [
                      'whatsapp_numero',
                      'cuenta_banco',
                      'cuenta_titular',
                    ].contains(c.clave))
                .map((c) => _ConfigCard(
                      config: c,
                      onEditar: () =>
                          _mostrarEditor(context, ref, c),
                    )),

            const SizedBox(height: 20),

            // Sección Envío
            _SecLabel('🚚 COSTOS'),
            const SizedBox(height: 10),
            ...items
                .where((c) => ['costo_envio'].contains(c.clave))
                .map((c) => _ConfigCard(
                      config: c,
                      onEditar: () =>
                          _mostrarEditor(context, ref, c),
                      esMoneda: c.clave == 'costo_envio',
                    )),
          ],
        ),
      ),
    );
  }

  void _mostrarEditor(
      BuildContext context, WidgetRef ref,
      ConfiguracionNegocio config) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _EditorConfiguracion(
        config: config,
        onGuardar: (nuevoValor) async {
          await ref
              .read(adminOpProvider.notifier)
              .actualizarConfiguracion(config.clave, nuevoValor);

          final state = ref.read(adminOpProvider);
          if (state.error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:         Text(state.error!),
              backgroundColor: AppColores.danger,
            ));
            ref.read(adminOpProvider.notifier).resetear();
            return;
          }
          ref.invalidate(configuracionAdminProvider);
          ref.read(adminOpProvider.notifier).resetear();
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:         Text('✅ Configuración actualizada'),
                backgroundColor: AppColores.success,
              ),
            );
          }
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD DE CONFIGURACIÓN
// ══════════════════════════════════════════════════════════
class _ConfigCard extends StatelessWidget {
  final ConfiguracionNegocio config;
  final VoidCallback         onEditar;
  final bool                 esMoneda;

  const _ConfigCard({
    required this.config,
    required this.onEditar,
    this.esMoneda = false,
  });

  String get _label {
    switch (config.clave) {
      case 'whatsapp_numero': return 'Número WhatsApp';
      case 'cuenta_banco':    return 'Cuenta bancaria';
      case 'cuenta_titular':  return 'Titular de la cuenta';
      case 'costo_envio':     return 'Costo de envío';
      default: return config.clave;
    }
  }

  IconData get _icono {
    switch (config.clave) {
      case 'whatsapp_numero': return Icons.phone;
      case 'cuenta_banco':    return Icons.account_balance;
      case 'cuenta_titular':  return Icons.person;
      case 'costo_envio':     return Icons.delivery_dining;
      default: return Icons.settings;
    }
  }

  Color get _color {
    switch (config.clave) {
      case 'whatsapp_numero': return const Color(0xFF25D366);
      case 'cuenta_banco':    return AppColores.primary;
      case 'cuenta_titular':  return AppColores.accent;
      case 'costo_envio':     return AppColores.warning;
      default: return AppColores.textSecond;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        _color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icono, color: _color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label, style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   13,
                color:      AppColores.textSecond)),
            const SizedBox(height: 3),
            Text(
              esMoneda
                  ? '\$${double.tryParse(config.valor)
                        ?.toStringAsFixed(2) ?? config.valor}'
                  : config.valor,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   16,
                color:      AppColores.textPrimary,
              ),
            ),
            if (config.descripcion != null)
              Text(config.descripcion!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColores.textSecond)),
          ],
        )),
        IconButton(
          icon:      const Icon(Icons.edit_outlined,
              color: AppColores.textSecond),
          onPressed: onEditar,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EDITOR DE CONFIGURACIÓN (bottom sheet)
// ══════════════════════════════════════════════════════════
class _EditorConfiguracion extends StatefulWidget {
  final ConfiguracionNegocio    config;
  final Function(String)        onGuardar;
  const _EditorConfiguracion({
    required this.config, required this.onGuardar});

  @override
  State<_EditorConfiguracion> createState() =>
      _EditorConfiguracionState();
}

class _EditorConfiguracionState
    extends State<_EditorConfiguracion> {
  late final _ctrl = TextEditingController(
      text: widget.config.valor);
  bool _cargando = false;

  bool get _esMoneda =>
      widget.config.clave == 'costo_envio';

  bool get _esTelefono =>
      widget.config.clave == 'whatsapp_numero';

  String get _titulo {
    switch (widget.config.clave) {
      case 'whatsapp_numero': return 'Editar número WhatsApp';
      case 'cuenta_banco':    return 'Editar cuenta bancaria';
      case 'cuenta_titular':  return 'Editar titular';
      case 'costo_envio':     return 'Editar costo de envío';
      default: return 'Editar configuración';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left:   24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),

          Text(_titulo, style: const TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.bold,
            color:      AppColores.textPrimary,
          )),
          const SizedBox(height: 20),

          // Campo
          TextField(
            controller:   _ctrl,
            autofocus:    true,
            keyboardType: _esMoneda
                ? const TextInputType.numberWithOptions(
                    decimal: true)
                : _esTelefono
                    ? TextInputType.phone
                    : TextInputType.text,
            inputFormatters: _esMoneda
                ? [FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))]
                : _esTelefono
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
            decoration: InputDecoration(
              prefixText: _esMoneda ? '\$ ' : null,
              prefixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      AppColores.primary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled:    true,
              fillColor: AppColores.background,
            ),
          ),
          const SizedBox(height: 20),

          // Botón guardar
          SizedBox(
            width:  double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _cargando ? null : () async {
                final val = _ctrl.text.trim();
                if (val.isEmpty) return;
                setState(() => _cargando = true);
                await widget.onGuardar(val);
                setState(() => _cargando = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _cargando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar',
                      style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGET UTILITARIO
// ══════════════════════════════════════════════════════════
class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(texto, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: AppColores.textSecond, letterSpacing: 1.1)),
  );
}