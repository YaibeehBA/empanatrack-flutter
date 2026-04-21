import 'package:flutter/material.dart';
import '../../../core/constants/colores.dart';

class BottomBar extends StatelessWidget {
  final double total;
  final bool cargando;
  final VoidCallback onTap;

  const BottomBar({
    required this.total,
    required this.cargando,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.of(context).padding.bottom + 16,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total a registrar',
              style: TextStyle(color: AppColores.textSecond, fontSize: 12),
            ),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColores.primary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: cargando ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Registrar Venta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
