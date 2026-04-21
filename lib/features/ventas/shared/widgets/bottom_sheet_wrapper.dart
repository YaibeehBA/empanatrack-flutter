import 'package:flutter/material.dart';
import '../../../../core/constants/colores.dart';

class BottomSheetWrapper extends StatelessWidget {
  final String titulo;
  final Widget child;

  const BottomSheetWrapper({
    super.key,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.only(
      left:   24,
      right:  24,
      top:    20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color:        Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        Text(titulo, style: const TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.bold,
            color:      AppColores.textPrimary)),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}