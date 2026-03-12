import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/vendedores_screen.dart';
import 'features/admin/screens/empresas_screen.dart';
import 'features/admin/screens/productos_screen.dart';
import 'package:empanatrack_app/features/clientes/screens/registro_cliente_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/colores.dart';
import 'core/network/api_client.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';

import 'features/auth/screens/recuperar_contrasena_screen.dart';
import 'features/auth/screens/registro_screen.dart';
import 'features/ventas/screens/nueva_venta_screen.dart';
import 'features/clientes/screens/clientes_screen.dart';
import 'features/clientes/screens/registrar_pago_screen.dart';
import 'features/ventas/screens/vendedor_shell.dart';
import 'features/clientes/screens/cliente_shell.dart';


class EmpanaTrackApp extends ConsumerWidget {
  const EmpanaTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inicializar el cliente HTTP una sola vez
    ApiClient.inicializar();

    final router = GoRouter(
      initialLocation: '/login',

      // Redirección global: si ya hay sesión, ir al dashboard
      redirect: (context, state) async {
        final authState = ref.read(authProvider);
        final enLogin   = state.matchedLocation == '/login';

        if (authState.estado == AuthEstado.autenticado && enLogin) {
          final rol = authState.sesion!.rol;
          return (rol == 'cliente') ? '/mi-cuenta' : '/dashboard';
        }
        return null;
      },

      routes: [
        GoRoute(
          path:    '/login',
          builder: (ctx, state) => const LoginScreen(),
        ),
        GoRoute(
          path:    '/recuperar-contrasena',
          builder: (context, state) =>
              const RecuperarContrasenaScreen(),
        ),
          GoRoute(
          path:    '/registro',
          builder: (ctx, state) => const RegistroScreen(),
        ),
        GoRoute(
          path:    '/admin',
          builder: (ctx, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path:    '/admin/vendedores',
          builder: (ctx, state) => const VendedoresScreen(),
        ),
        GoRoute(
          path:    '/admin/empresas',
          builder: (ctx, state) => const EmpresasScreen(),
        ),
        GoRoute(
          path:    '/admin/productos',
          builder: (ctx, state) => const ProductosScreen(),
        ),
        GoRoute(
          path:    '/dashboard',
          builder: (ctx, state) => const VendedorShell(),
        ),
        GoRoute(
          path:    '/nueva-venta',
          builder: (ctx, state) => const NuevaVentaScreen(),
        ),
        GoRoute(
          path:    '/mi-cuenta',
          builder: (ctx, state) => const ClienteShell(),  // ← era MiCuentaScreen()
        ),
        GoRoute(
          path:    '/registrar-pago/:clienteId',
          builder: (ctx, state) => RegistrarPagoScreen(
            clienteId: state.pathParameters['clienteId']!,
          ),
        ),
        GoRoute(
          path:    '/nuevo-cliente',
          builder: (ctx, state) {
            final desdeNuevaVenta =
                state.extra as bool? ?? false;
            return RegistroClienteScreen(
                desdeNuevaVenta: desdeNuevaVenta);
          },
        ),
        GoRoute(
          path:    '/clientes',
          builder: (ctx, state) => const ClientesScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title:         'EmpanaTrack',
      debugShowCheckedModeBanner: false,
      routerConfig:  router,
      theme: ThemeData(
        colorScheme:  ColorScheme.fromSeed(seedColor: AppColores.primary),
        useMaterial3: true,
        fontFamily:   'Roboto',
      ),
    );
  }
}