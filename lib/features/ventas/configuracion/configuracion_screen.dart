import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../auth/providers/auth_provider.dart';
import 'perfil_provider.dart';
import 'widgets/avatar_card.dart';
import 'widgets/opcion_tile.dart';
import 'widgets/sheets/editar_perfil_sheet.dart';
import 'widgets/sheets/cambiar_contrasena_sheet.dart';

class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilVendedorProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Logout siempre visible ← Bug 6
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final confirma = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro que deseas cerrar sesión?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cerrar sesión'),
                    ),
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
      body: perfilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorPerfil(
          onReintentar: () => ref.invalidate(perfilVendedorProvider),
        ),
        data: (perfil) => _Body(perfil: perfil),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final PerfilVendedor perfil;
  const _Body({required this.perfil});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      AvatarCard(perfil: perfil),
      const SizedBox(height: 20),
      const _SeccionLabel('MI CUENTA'),
      const SizedBox(height: 8),
      OpcionTile(
        icono: Icons.person_outline_rounded,
        color: AppColores.primary,
        titulo: 'Editar perfil',
        subtitulo: 'Nombre y teléfono',
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditarPerfilSheet(perfil: perfil),
        ),
      ),
      OpcionTile(
        icono: Icons.lock_outline_rounded,
        color: AppColores.warning,
        titulo: 'Cambiar contraseña',
        subtitulo: 'Actualiza tu contraseña de acceso',
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const CambiarContrasenaSheet(),
        ),
      ),
      const SizedBox(height: 20),
      const _SeccionLabel('INFORMACIÓN'),
      const SizedBox(height: 8),
      OpcionTile(
        icono: Icons.info_outline_rounded,
        color: AppColores.accent,
        titulo: 'Acerca de EmpanaTrack',
        subtitulo: 'Versión 1.0.0',
        sinFlecha: true,
        onTap: () => _mostrarAcercaDe(context),
      ),
      const SizedBox(height: 32),
      _LogoutButton(),
    ],
  );

  void _mostrarAcercaDe(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Text('🫓', style: TextStyle(fontSize: 28)),
          SizedBox(width: 10),
          Text('EmpanaTrack'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versión: 1.0.0'),
          SizedBox(height: 6),
          Text(
            'Sistema de gestión de ventas fiadas '
            'y cobranzas para negocios.',
          ),
          SizedBox(height: 12),
          Text(
            'Desarrollado con Flutter + FastAPI',
            style: TextStyle(fontSize: 12, color: AppColores.textSecond),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

// ── Logout ────────────────────────────────────────────────
class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      onPressed: () async {
        final confirma = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro que deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
        if (confirma == true && context.mounted) {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColores.danger,
        side: const BorderSide(color: AppColores.danger),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text(
        'Cerrar sesión',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────
class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColores.textSecond,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _ErrorPerfil extends StatelessWidget {
  final VoidCallback onReintentar;
  const _ErrorPerfil({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'No se pudo cargar el perfil',
          style: TextStyle(color: AppColores.textSecond),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
    ),
  );
}