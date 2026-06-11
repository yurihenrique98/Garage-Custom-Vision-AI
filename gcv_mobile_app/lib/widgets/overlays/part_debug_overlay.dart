import 'package:flutter/material.dart';

class PartDebugOverlay extends StatelessWidget {
  final List<dynamic> detections;
  final bool visible;

  const PartDebugOverlay({
    super.key,
    required this.detections,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || detections.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _PartDebugPainter(detections),
      child: const SizedBox.expand(),
    );
  }
}

class _PartDebugPainter extends CustomPainter {
  final List<dynamic> detections;

  _PartDebugPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 1024;
    final double scaleY = size.height / 768;

    final Paint boxPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint fillPaint = Paint()
      ..color = Colors.blueAccent.withAlpha(35)
      ..style = PaintingStyle.fill;

    for (final item in detections) {
      if (item is! Map) continue;
      if (item['box'] == null) continue;

      final List box = item['box'];

      if (box.length < 4) continue;

      final String label = item['part']?.toString() ?? 'part';

      final double x1 = (box[0] as num).toDouble() * scaleX;
      final double y1 = (box[1] as num).toDouble() * scaleY;
      final double x2 = (box[2] as num).toDouble() * scaleX;
      final double y2 = (box[3] as num).toDouble() * scaleY;

      final Rect rect = Rect.fromLTRB(x1, y1, x2, y2);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.blueAccent,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x1, y1 - 14 < 0 ? y1 + 2 : y1 - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}