import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Simple sparkline widget that paints a line chart from a list of values.
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color lineColor;
  final Color? fillColor;
  final double height;
  final String? label;
  final String? currentValue;

  const Sparkline({
    super.key,
    required this.data,
    this.lineColor = primaryColor,
    this.fillColor,
    this.height = 60,
    this.label,
    this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null || currentValue != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(label!,
                      style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                if (currentValue != null)
                  Text(currentValue!,
                      style: TextStyle(
                          color: lineColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          if (label != null || currentValue != null)
            const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: data.length < 2
                ? Center(
                    child: Text('Collecting data...',
                        style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.5),
                            fontSize: 11)))
                : CustomPaint(
                    size: Size(double.infinity, height),
                    painter: _SparklinePainter(
                      data: data,
                      lineColor: lineColor,
                      fillColor: fillColor ??
                          lineColor.withValues(alpha: 0.1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    double minVal = data.reduce(math.min);
    double maxVal = data.reduce(math.max);
    if (maxVal == minVal) {
      maxVal = minVal + 1; // Avoid division by zero
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / (maxVal - minVal)) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw current value dot at the end
    if (data.isNotEmpty) {
      final lastX = size.width;
      final lastY = size.height -
          ((data.last - minVal) / (maxVal - minVal)) * size.height;
      canvas.drawCircle(
        Offset(lastX, lastY),
        3,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor;
  }
}
