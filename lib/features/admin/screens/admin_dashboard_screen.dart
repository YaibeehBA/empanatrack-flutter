import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colores.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion       = ref.watch(authProvider).sesion;
    final resumenAsync = ref.watch(resumenAdminProvider);

    return Scaffold(
      backgroundColor: AppColores.background,
      appBar: AppBar(
        backgroundColor: AppColores.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola, ${sesion?.nombre ?? ''} 👑',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Panel de administración',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon:     const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(resumenAdminProvider),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Cards de resumen ─────────────────────────
            resumenAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => const SizedBox.shrink(),
              data: (r) => GridView.count(
                crossAxisCount:   2,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12,
                shrinkWrap:       true,
                childAspectRatio: 1.25,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ResCard(
                    icono:  '💰',
                    titulo: 'Total en deudas',
                    valor:  '\$${r.totalDeudas.toStringAsFixed(2)}',
                    color:  AppColores.danger,
                  ),
                  _ResCard(
                    icono:  '🧾',
                    titulo: 'Vendido hoy',
                    valor:  '\$${r.vendidoHoy.toStringAsFixed(2)}',
                    color:  AppColores.success,
                  ),
                  _ResCard(
                    icono:  '🏪',
                    titulo: 'Clientes con deuda',
                    valor:  '${r.clientesConDeuda}',
                    color:  AppColores.warning,
                  ),
                  _ResCard(
                    icono:  '🧑‍💼',
                    titulo: 'Vendedores activos',
                    valor:  '${r.vendedoresActivos}',
                    color:  AppColores.accent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Sección: Gestión ─────────────────────────
            const _SecLabel(texto: 'GESTIÓN'),
            const SizedBox(height: 12),

            _MenuCard(
              icono:    '🧑‍💼',
              titulo:   'Vendedores',
              subtitulo: 'Crear y administrar vendedores',
              color:    AppColores.accent,
              onTap:    () => context.push('/admin/vendedores'),
            ),
            _MenuCard(
              icono:    '🏪',
              titulo:   'Clientes',
              subtitulo: 'Ver todos los clientes y deudas',
              color:    AppColores.primary,
              onTap:    () => context.push('/clientes'),
            ),
            _MenuCard(
              icono:    '🏢',
              titulo:   'Empresas',
              subtitulo: 'Registrar y editar empresas',
              color:    AppColores.warning,
              onTap:    () => context.push('/admin/empresas'),
            ),
            _MenuCard(
              icono:    '🫓',
              titulo:   'Productos',
              subtitulo: 'Catálogo de empanadas y precios',
              color:    AppColores.success,
              onTap:    () => context.push('/admin/productos'),
            ),

            const SizedBox(height: 28),

            // ── Sección: Reportes ────────────────────────
            const _SecLabel(texto: 'REPORTES'),
            const SizedBox(height: 12),

            _MenuCard(
              icono:    '📊',
              titulo:   'Deudas por cliente',
              subtitulo: 'Ver quién debe más',
              color:    AppColores.danger,
              onTap:    () => context.push('/admin/reportes/deudas'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel({required this.texto});
  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.bold,
      color: AppColores.textSecond, letterSpacing: 1.2,
    ),
  );
}

class _ResCard extends StatelessWidget {
  final String icono;
  final String titulo;
  final String valor;
  final Color  color;
  const _ResCard({
    required this.icono, required this.titulo,
    required this.valor, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icono, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const Spacer(),
          Text(valor, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: color,
          )),
          Text(titulo, style: const TextStyle(
            fontSize: 11, color: AppColores.textSecond,
          )),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String       icono;
  final String       titulo;
  final String       subtitulo;
  final Color        color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icono, required this.titulo,
    required this.subtitulo, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icono, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: AppColores.textPrimary,
                  )),
                  Text(subtitulo, style: const TextStyle(
                    fontSize: 12, color: AppColores.textSecond,
                  )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColores.textSecond),
          ],
        ),
      ),
    );
  }
}