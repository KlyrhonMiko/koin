import 'package:flutter/material.dart';

class CardBackgroundShapes extends StatelessWidget {
  final int shapeType;
  final double opacityMultiplier;

  const CardBackgroundShapes({
    super.key,
    required this.shapeType,
    this.opacityMultiplier = 1.0,
  });

  double _getAlpha(double base) => (base * opacityMultiplier).clamp(0.0, 0.45);

  @override
  Widget build(BuildContext context) {
    switch (shapeType) {
      case 0:
        return Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.12)),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -50,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 140,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white.withValues(alpha: _getAlpha(0.10)),
                  ),
                ),
              ),
            ),
          ],
        );
      case 2:
        return Stack(
          children: [
            Positioned(
              right: 40,
              top: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.08)),
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -10,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.12)),
                ),
              ),
            ),
          ],
        );
      case 3:
        return Stack(
          children: [
            Positioned(
              left: -40,
              bottom: -40,
              child: Transform.rotate(
                angle: 0.8,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: Colors.white.withValues(alpha: _getAlpha(0.14)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: 20,
              child: Container(
                width: 80,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.white.withValues(alpha: _getAlpha(0.10)),
                ),
              ),
            ),
          ],
        );
      case 4: // Bubbles
        return Stack(
          children: [
            Positioned(
              right: 10,
              top: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.08)),
                ),
              ),
            ),
            Positioned(
              right: -15,
              top: 40,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.10)),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -25,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.06)),
                ),
              ),
            ),
          ],
        );
      case 5: // Eclipse
        return Stack(
          children: [
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.12)),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _getAlpha(0.08)),
                ),
              ),
            ),
          ],
        );
      case 6: // Glassy Overlays
        return Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 160,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: Colors.white.withValues(alpha: _getAlpha(0.08)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 15,
              bottom: 15,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 140,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: _getAlpha(0.15)),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 7: // Diamond Pattern
        return Stack(
          children: [
            Positioned(
              right: -20,
              top: 20,
              child: Transform.rotate(
                angle: 0.785,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withValues(alpha: _getAlpha(0.07)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: -20,
              child: Transform.rotate(
                angle: 0.785,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: _getAlpha(0.12)),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Transform.rotate(
                angle: 0.785,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: _getAlpha(0.09)),
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
