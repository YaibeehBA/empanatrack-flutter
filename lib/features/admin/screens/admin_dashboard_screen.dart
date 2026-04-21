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
            Text(_fechaHoy(),
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(resumenAdminProvider),
          ),
          IconButton(
            icon:      const Icon(Icons.logout),
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
          padding: const EdgeInsets.all(16),
          children: [

            // ── Resumen de hoy ───────────────────────────
            resumenAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child:   CircularProgressIndicator(),
              )),
              error: (e, _) => const SizedBox.shrink(),
              data:  (r) => _BloqueResumen(r: r),
            ),

            const SizedBox(height: 24),

            // ── Gestión ──────────────────────────────────
            const _SecLabel('GESTIÓN'),
            const SizedBox(height: 12),
            _MenuCard(
              icono: '🧑‍💼', titulo: 'Vendedores',
              subtitulo: 'Crear y administrar vendedores',
              color: AppColores.accent,
              onTap: () => context.push('/admin/vendedores'),
            ),
            _MenuCard(
              icono: '🏪', titulo: 'Clientes',
              subtitulo: 'Ver todos los clientes y deudas',
              color: AppColores.primary,
              onTap: () => context.push('/clientes'),
            ),
            _MenuCard(
              icono: '🏢', titulo: 'Empresas',
              subtitulo: 'Registrar y editar empresas',
              color: AppColores.warning,
              onTap: () => context.push('/admin/empresas'),
            ),
            _MenuCard(
              icono: '🫓', titulo: 'Productos',
              subtitulo: 'Catálogo de empanadas y precios',
              color: AppColores.success,
              onTap: () => context.push('/admin/productos'),
            ),
            _MenuCard(
              icono: '🗺️', titulo: 'Rutas',
              subtitulo: 'Crear y asignar rutas de entrega',
              color: AppColores.primary,
              onTap: () => context.push('/admin/rutas'),
            ),
            _MenuCard(
              icono: '⚙️', titulo: 'Configuración',
              subtitulo: 'WhatsApp, banco y costos de envío',
              color: AppColores.primary,
              onTap: () => context.push('/admin/configuracion'),
            ),

            const SizedBox(height: 24),

            // ── Reportes ─────────────────────────────────
            const _SecLabel('REPORTES'),
            const SizedBox(height: 12),
            _MenuCard(
              icono: '📊', titulo: 'Reportes generales',
              subtitulo: 'Ventas, pedidos, deudas y más',
              color: AppColores.primary,
              onTap: () => context.push('/admin/reportes'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _fechaHoy() {
    final now   = DateTime.now();
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    const dias  = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    return '${dias[now.weekday % 7]} ${now.day} '
           '${meses[now.month]} ${now.year}';
  }
}

// ══════════════════════════════════════════════════════════
//  BLOQUE RESUMEN DE HOY
// ══════════════════════════════════════════════════════════
class _BloqueResumen extends StatelessWidget {
  final ResumenAdmin r;
  const _BloqueResumen({required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const _SecLabel('RESUMEN DE HOY'),
        const SizedBox(height: 12),

        // ── Fila 1: ventas + deudas ──────────────────
        Row(children: [
          Expanded(child: _ResCard(
            icono:  '🧾',
            titulo: 'Vendido hoy',
            valor:  '\$${r.vendidoHoy.toStringAsFixed(2)}',
            sub:    '${r.ventasHoy} ventas',
            color:  AppColores.success,
          )),
          const SizedBox(width: 12),
          Expanded(child: _ResCard(
            icono:  '💰',
            titulo: 'Total deudas',
            valor:  '\$${r.totalDeudas.toStringAsFixed(2)}',
            sub:    '${r.clientesConDeuda} clientes',
            color:  AppColores.danger,
          )),
        ]),
        const SizedBox(height: 12),

        // ── Fila 2: vendedores + pedidos pendientes ──
        Row(children: [
          Expanded(child: _ResCard(
            icono:  '🧑‍💼',
            titulo: 'Vendedores',
            valor:  '${r.vendedoresActivos}',
            sub:    'activos',
            color:  AppColores.accent,
          )),
          const SizedBox(width: 12),
          Expanded(child: _ResCard(
            icono:  '⏳',
            titulo: 'Pedidos',
            valor:  '${r.pedidosPendientes}',
            sub:    'pendientes',
            color:  r.pedidosPendientes > 0
                ? AppColores.warning : AppColores.textSecond,
          )),
        ]),

        // ── Card pedidos hoy (si hay) ────────────────
        if (r.pedidosHoy > 0) ...[
          const SizedBox(height: 12),
          _CardPedidosHoy(r: r),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CARD PEDIDOS HOY
// ══════════════════════════════════════════════════════════
class _CardPedidosHoy extends StatelessWidget {
  final ResumenAdmin r;
  const _CardPedidosHoy({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [

        // Encabezado
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        AppColores.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🛵',
                style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pedidos de hoy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                    color:      AppColores.textPrimary,
                  )),
              Text(
                '${r.pedidosHoy} pedidos — '
                '\$${r.montoPedidosHoy.toStringAsFixed(2)} total',
                style: const TextStyle(
                    fontSize: 12, color: AppColores.textSecond),
              ),
            ],
          )),
        ]),

        const SizedBox(height: 14),
        Divider(color: Colors.grey.withOpacity(0.15)),
        const SizedBox(height: 12),

        // Desglose pendientes / entregados
        Row(children: [
          Expanded(child: _DesglosePedido(
            emoji:  '⏳',
            label:  'Pendientes',
            valor:  r.pedidosPendientes,
            color:  r.pedidosPendientes > 0
                ? AppColores.warning : AppColores.textSecond,
          )),
          Container(width: 1, height: 40,
              color: Colors.grey.withOpacity(0.2)),
          Expanded(child: _DesglosePedido(
            emoji:  '✅',
            label:  'Entregados',
            valor:  r.pedidosEntregados,
            color:  AppColores.success,
          )),
        ]),
      ]),
    );
  }
}

class _DesglosePedido extends StatelessWidget {
  final String emoji, label;
  final int    valor;
  final Color  color;
  const _DesglosePedido({
    required this.emoji, required this.label,
    required this.valor, required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColores.textSecond)),
      ]),
      const SizedBox(height: 4),
      Text('$valor', style: TextStyle(
          fontSize:   22,
          fontWeight: FontWeight.bold,
          color:      color)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  RES CARD
// ══════════════════════════════════════════════════════════
class _ResCard extends StatelessWidget {
  final String icono, titulo, valor, sub;
  final Color  color;
  const _ResCard({
    required this.icono, required this.titulo,
    required this.valor, required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
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
            child: Center(child: Text(icono,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 12),
          Text(valor, style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.bold,
              color:      color)),
          Text(titulo, style: const TextStyle(
              fontSize: 11, color: AppColores.textSecond)),
          Text(sub, style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MENU CARD
// ══════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final String       icono, titulo, subtitulo;
  final Color        color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icono, required this.titulo,
    required this.subtitulo, required this.color,
    required this.onTap,
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
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icono,
                style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: AppColores.textPrimary)),
              Text(subtitulo, style: const TextStyle(
                  fontSize: 12, color: AppColores.textSecond)),
            ],
          )),
          const Icon(Icons.chevron_right,
              color: AppColores.textSecond),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SEC LABEL
// ══════════════════════════════════════════════════════════
class _SecLabel extends StatelessWidget {
  final String texto;
  const _SecLabel(this.texto);

  @override
  Widget build(BuildContext context) => Text(texto,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold,
          color: AppColores.textSecond, letterSpacing: 1.2));
}