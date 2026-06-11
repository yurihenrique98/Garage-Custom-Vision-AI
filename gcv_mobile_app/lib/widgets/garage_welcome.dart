import 'package:flutter/material.dart';

import 'gcv_widgets.dart';

class GarageWelcome extends StatelessWidget {
  final Color gcvBlue;
  final VoidCallback onEnterGarage;
  final VoidCallback onHelpTap;

  const GarageWelcome({
    super.key,
    required this.gcvBlue,
    required this.onEnterGarage,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const Spacer(flex: 9),

            Text(
              "WELCOME TO\nGCV-AI",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gcvBlue,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                shadows: [
                  Shadow(
                    color: gcvBlue,
                    blurRadius: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Personalise your car with one shot.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              "Built for enthusiasts, GCV-AI turns your vision into reality. Design, refine, and save your dream build directly to your gallery.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              "Ready to build? Tap 'Enter Garage' and upload your car to begin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gcvBlue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(flex: 2),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onEnterGarage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gcvBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 42,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(35),
                    ),
                  ),
                  child: const Text(
                    "ENTER GARAGE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                GCVCircleAction(
                  icon: Icons.help_outline,
                  bg: Colors.white.withAlpha(25),
                  tap: onHelpTap,
                ),
              ],
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}