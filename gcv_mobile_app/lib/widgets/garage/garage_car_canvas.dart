import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../overlays/part_debug_overlay.dart';
import 'garage_part_selector.dart';

class GarageCarCanvas extends StatelessWidget {
  final Uint8List? currentImage;
  final List<dynamic> parts;
  final bool showPartDebug;
  final bool adjustPartsMode;
  final bool isLandscape;
  final ValueChanged<List<dynamic>> onPartsChanged;
  final VoidCallback? onDoneAdjusting;

  const GarageCarCanvas({
    super.key,
    required this.currentImage,
    required this.parts,
    required this.showPartDebug,
    required this.adjustPartsMode,
    required this.isLandscape,
    required this.onPartsChanged,
    this.onDoneAdjusting,
  });

  @override
  Widget build(BuildContext context) {
    if (currentImage == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          final double carWidth = screenWidth * (isLandscape ? 0.62 : 0.94);
          final double carHeight = screenHeight * (isLandscape ? 0.72 : 0.62);

          final Alignment carAlignment =
              isLandscape ? const Alignment(0, 0.62) : const Alignment(0, 0.72);

          final double carLeft =
              (screenWidth - carWidth) * ((carAlignment.x + 1) / 2);
          final double carTop =
              (screenHeight - carHeight) * ((carAlignment.y + 1) / 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: carLeft,
                top: carTop,
                width: carWidth,
                height: carHeight,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    IgnorePointer(
                      child: Image.memory(
                        currentImage!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                    if (showPartDebug && !adjustPartsMode)
                      IgnorePointer(
                        child: PartDebugOverlay(
                          detections: parts,
                          visible: showPartDebug,
                        ),
                      ),
                  ],
                ),
              ),

              if (adjustPartsMode)
                Positioned.fill(
                  child: GaragePartSelector(
                    parts: parts,
                    onPartsChanged: onPartsChanged,
                    canvasLeft: carLeft,
                    canvasTop: carTop,
                    canvasWidth: carWidth,
                    canvasHeight: carHeight,
                  ),
                ),

              if (adjustPartsMode && onDoneAdjusting != null)
                Positioned(
                  right: isLandscape ? 28 : 36,
                  bottom: isLandscape ? 28 : 82,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDoneAdjusting,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withAlpha(210),
                        border: Border.all(
                          color: Colors.white.withAlpha(160),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(120),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}