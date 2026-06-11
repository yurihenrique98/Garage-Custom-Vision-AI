import 'package:flutter/material.dart';

class GarageControls extends StatelessWidget {
  final Color gcvBlue;
  final bool canSave;
  final bool isBusy;
  final VoidCallback onUndo;
  final VoidCallback onApply;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const GarageControls({
    super.key,
    required this.gcvBlue,
    required this.canSave,
    required this.isBusy,
    required this.onUndo,
    required this.onApply,
    required this.onSave,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final bool isLandscape = screen.width > screen.height;

    final double dockWidth =
        isLandscape ? screen.width * 0.55 : screen.width - 32;
    final double bottomPosition = isLandscape ? 18 : 32;

    return Positioned(
      bottom: bottomPosition,
      left: (screen.width - dockWidth) / 2,
      width: dockWidth,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 18 : 8,
          vertical: isLandscape ? 10 : 0,
        ),
        decoration: BoxDecoration(
          color: isLandscape ? Colors.black.withAlpha(130) : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isLandscape
              ? Border.all(color: Colors.white.withAlpha(20))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _smallCircle(
              icon: Icons.undo,
              bg: Colors.white.withAlpha(25),
              onTap: isBusy ? null : onUndo,
              size: isLandscape ? 48 : 54,
            ),

            GestureDetector(
              onTap: isBusy ? null : onApply,
              child: Opacity(
                opacity: isBusy ? 0.45 : 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 34 : 38,
                    vertical: isLandscape ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: gcvBlue,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: gcvBlue.withAlpha(80),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Text(
                    isBusy ? "WAIT" : "APPLY",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),

            _smallCircle(
              icon: Icons.close,
              bg: Colors.redAccent.withAlpha(35),
              iconColor: Colors.redAccent,
              onTap: isBusy ? null : onClose,
              size: isLandscape ? 48 : 54,
            ),

            _smallCircle(
              icon: Icons.download_rounded,
              bg: canSave ? gcvBlue.withAlpha(80) : Colors.white.withAlpha(25),
              onTap: isBusy ? null : onSave,
              size: isLandscape ? 48 : 54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallCircle({
    required IconData icon,
    required Color bg,
    required VoidCallback? onTap,
    Color iconColor = Colors.white,
    double size = 54,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(
              color: Colors.white.withAlpha(25),
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}