import 'package:flutter/material.dart';
import '../theme.dart';

class HeapBar extends StatelessWidget {
  final int used;
  final int max;
  const HeapBar({super.key, required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    if (max <= 0) return const SizedBox.shrink();
    final pct = (used / max * 100).clamp(0.0, 100.0);
    final color = heapBarColor(pct);

    return Container(
      height: 6,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
