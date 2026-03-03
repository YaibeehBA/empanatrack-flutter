 
import 'package:empanatrack_app/features/clientes/screens/registro_cliente_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/colores.dart';
import 'core/network/api_client.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/ventas/screens/dashboard_screen.dart';
import 'features/ventas/screens/nueva_venta_screen.dart';
import 'features/clientes/screens/clientes_screen.dart';
import 'features/clientes/screens/mi_cuenta_screen.dart';
import 'features/clientes/screens/registrar_pago_screen.dart';

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
          path:    '/dashboard',
          builder: (ctx, state) => const DashboardScreen(),
        ),
        GoRoute(
          path:    '/nueva-venta',
          builder: (ctx, state) => const NuevaVentaScreen(),
        ),
        GoRoute(
          path:    '/mi-cuenta',
          builder: (ctx, state) => const MiCuentaScreen(),
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