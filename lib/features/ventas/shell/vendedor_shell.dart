import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/mapa_ruta_screen.dart';
import '../screens/pedidos_vendedor_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../../clientes/screens/clientes_screen.dart';
import 'shell_providers.dart';
import 'bottom_nav.dart';

class VendedorShell extends ConsumerWidget {
  const VendedorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabActivoProvider);

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          MapaRutaScreen(),          // 0 — Ruta (pantalla principal)
          PedidosVendedorScreen(),   // 1 — Pedidos
          ClientesScreen(),          // 2 — Clientes
          ConfiguracionScreen(),     // 3 — Configuración
        ],
      ),
      bottomNavigationBar: BottomNav(
        tabActivo:   tab,
        onTabChange: (nuevo) =>
            ref.read(tabActivoProvider.notifier).state = nuevo,
      ),
    );
  }
}