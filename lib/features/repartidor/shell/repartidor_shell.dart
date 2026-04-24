import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';

import '../../auth/providers/auth_provider.dart';
import '../../pedidos/screens/pedidos_repartidor_screen.dart';
import '../../pedidos/providers/pedidos_providers.dart';

class RepartidorShell extends ConsumerWidget {
  const RepartidorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosCount = ref
        .watch(pedidosRepartidorProvider)
        .maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor:           AppColores.primary,
        foregroundColor:           Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('EmpanaTrack',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Badge pedidos disponibles
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (pedidosCount > 0)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: AppColores.danger,
                        shape: BoxShape.circle),
                    child: Text('$pedidosCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirma = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title:   const Text('Cerrar sesión'),
                  content: const Text(
                      '¿Estás seguro que deseas cerrar sesión?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColores.danger,
                            foregroundColor: Colors.white),
                        child: const Text('Cerrar sesión')),
                  ],
                ),
              );
              if (confirma == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: const PedidosRepartidorScreen(),
    );
  }
}