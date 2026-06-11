import 'package:flutter/material.dart';
import '../gcv_widgets.dart';

class GarageTopBar extends StatelessWidget {
  final PageController controller;
  final List<Map<String, dynamic>> categories;
  final int activeCategoryIndex;
  final int loopFactor;
  final double top;
  final double left;
  final double right;
  final Color gcvBlue;
  final ValueChanged<int> onCategoryChanged;

  const GarageTopBar({
    super.key,
    required this.controller,
    required this.categories,
    required this.activeCategoryIndex,
    required this.loopFactor,
    required this.top,
    required this.left,
    required this.right,
    required this.gcvBlue,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: top,
      left: left,
      right: right,
      child: GCVPanel(
        height: 105,
        child: PageView.builder(
          controller: controller,
          itemCount: loopFactor,
          onPageChanged: (i) => onCategoryChanged(i % categories.length),
          itemBuilder: (context, index) {
            final int realIndex = index % categories.length;
            final category = categories[realIndex];

            return GestureDetector(
              onTap: () {
                controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: _item(
                category['icon'],
                category['name'],
                activeCategoryIndex == realIndex,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isSelected ? gcvBlue : Colors.white38,
          size: isSelected ? 31 : 25,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? gcvBlue : Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isSelected) ...[
          const SizedBox(height: 6),
          Container(
            width: 35,
            height: 2,
            decoration: BoxDecoration(
              color: gcvBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}