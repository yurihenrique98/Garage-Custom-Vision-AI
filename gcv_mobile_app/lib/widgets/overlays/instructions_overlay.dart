import 'package:flutter/material.dart';

class InstructionsOverlay extends StatelessWidget {
  final Color gcvBlue;
  final VoidCallback onClose;

  const InstructionsOverlay({
    super.key,
    required this.gcvBlue,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(245),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gcvBlue.withAlpha(120),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "HOW TO USE GCV-AI",
              style: TextStyle(
                color: gcvBlue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "1. Tap ENTER GARAGE and upload a clear car photo.\n\n"
              "2. The app removes the background automatically.\n\n"
              "3. Choose stance, paint, wheels, aero or lights.\n\n"
              "4. Pick an option on the right side and tap APPLY.\n\n"
              "5. You can apply more than one customisation. Each new change keeps the previous result.\n\n"
              "6. Login or register to save your final build to your gallery.",
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                height: 1.55,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 25),
            TextButton(
              onPressed: onClose,
              child: Text(
                "GOT IT",
                style: TextStyle(
                  color: gcvBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}