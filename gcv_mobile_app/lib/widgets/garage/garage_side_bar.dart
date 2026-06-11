import 'package:flutter/material.dart';
import '../gcv_widgets.dart';

class GarageSideBar extends StatelessWidget {
  final String category;
  final List<String> options;
  final int activeOptionIndex;
  final bool isLandscape;
  final Color gcvBlue;
  final Color pickerColor;
  final VoidCallback onColorTap;
  final ValueChanged<int> onOptionSelected;

  const GarageSideBar({
    super.key,
    required this.category,
    required this.options,
    required this.activeOptionIndex,
    required this.isLandscape,
    required this.gcvBlue,
    required this.pickerColor,
    required this.onColorTap,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (category == "PAINT" || category == "WINDOW" || category == "LIGHTS") {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        right: isLandscape ? 32 : 25,
        top: MediaQuery.of(context).size.height / 2 - 95,
        child: GCVCircleAction(
          icon: Icons.colorize,
          bg: pickerColor,
          tap: onColorTap,
        ),
      );
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: isLandscape ? 32 : 20,
      top: MediaQuery.of(context).size.height / 2 - 165,
      child: GCVPanel(
        width: 95,
        height: 230,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final bool isSelected = activeOptionIndex == index;

            return GestureDetector(
              onTap: () => onOptionSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? gcvBlue.withAlpha(50)
                      : Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? gcvBlue : Colors.white24,
                  ),
                ),
                child: Text(
                  options[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? gcvBlue : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}