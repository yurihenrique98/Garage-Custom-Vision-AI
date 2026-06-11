import 'package:flutter/material.dart';

class GCVPanel extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;

  const GCVPanel({super.key, this.width, this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Center(child: child),
    );
  }
}

class GCVCircleAction extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final VoidCallback tap;
  final Color iconColor;

  const GCVCircleAction({
    super.key,
    required this.icon,
    required this.bg,
    required this.tap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(color: bg.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1)
          ],
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}