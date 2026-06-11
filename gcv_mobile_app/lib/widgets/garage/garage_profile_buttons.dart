import 'package:flutter/material.dart';

import '../gcv_widgets.dart';

class GarageProfileButtons extends StatelessWidget {
  final bool isLandscape;
  final bool showMenus;
  final bool isCapturing;
  final bool hasImage;
  final bool isLoggedIn;
  final bool showPartDebug;
  final Color gcvBlue;
  final VoidCallback onProfileTap;
  final VoidCallback onDebugTap;

  const GarageProfileButtons({
    super.key,
    required this.isLandscape,
    required this.showMenus,
    required this.isCapturing,
    required this.hasImage,
    required this.isLoggedIn,
    required this.showPartDebug,
    required this.gcvBlue,
    required this.onProfileTap,
    required this.onDebugTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showMenus || isCapturing) return const SizedBox.shrink();

    return Positioned(
      top: isLandscape ? 22 : 45,
      right: isLandscape ? 25 : 28,
      child: Column(
        children: [
          if (!showPartDebug)
            GCVCircleAction(
              icon: Icons.person,
              bg: isLoggedIn
                  ? gcvBlue.withAlpha(70)
                  : Colors.white.withAlpha(25),
              tap: onProfileTap,
            ),

          if (!showPartDebug && hasImage) const SizedBox(height: 12),

          if (!showPartDebug && hasImage)
            GCVCircleAction(
              icon: Icons.visibility,
              bg: Colors.white.withAlpha(25),
              tap: onDebugTap,
            ),
        ],
      ),
    );
  }
}