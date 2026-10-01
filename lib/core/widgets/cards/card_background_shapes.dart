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
      case 6: // Waves/Ribbon
        return Stack(
          children: [
            Positioned(
              right: -50,
              bottom: -20,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white.withValues(alpha: _getAlpha(0.10)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: 20,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 180,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: _getAlpha(0.06)),
                  ),
                ),
              ),
            ),
          ],
        );
      case 7: // Geometric Grid
        return Stack(
          children: [
            Positioned(
              right: 20,
              top: 10,
              child: _buildSmallShape(24, 6, 0.08),
            ),
            Positioned(
              right: 10,
              top: 45,
              child: _buildSmallShape(16, 16, 0.10),
            ),
            Positioned(
              right: 45,
              top: 35,
              child: _buildSmallShape(20, 4, 0.07),
            ),
            Positioned(
              right: -10,
              bottom: 10,
              child: Transform.rotate(
                angle: 0.4,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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

  Widget _buildSmallShape(double size, double radius, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: _getAlpha(alpha)),
      ),
    );
  }
}
