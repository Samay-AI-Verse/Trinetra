import 'package:flutter/material.dart';

/// Floating SOS button widget - Smaller, cleaner design
class SOSButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const SOSButton({super.key, required this.onPressed, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFDC2626), // Emergency red
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing animation when active
            if (isActive)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.4),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOut,
                onEnd: () {
                  // Animation will restart via setState in parent
                },
                builder: (context, value, child) {
                  return Container(
                    width: 56 * value,
                    height: 56 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(
                          0xFFDC2626,
                        ).withOpacity(0.3 * (1.4 - value)),
                        width: 3,
                      ),
                    ),
                  );
                },
              ),
            // Shield icon for emergency
            const Icon(Icons.shield, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
