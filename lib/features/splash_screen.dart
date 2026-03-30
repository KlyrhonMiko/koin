import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _meshController;
  late final AnimationController _entranceController;
  late final AnimationController _ringController;
  late final AnimationController _progressController;
  late final AnimationController _exitController;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // Continuous fluid mesh background
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Orchestrated entrance sequence
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Orbiting ring around logo
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Progress line at bottom
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Exit fade
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Start entrance after a brief pause
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _entranceController.forward();
        _progressController.forward();
        HapticService.light();
      }
    });

    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && !_navigating) {
        _navigating = true;
        HapticService.selection();

        _exitController.forward().then((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const MainLayout(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _meshController.dispose();
    _entranceController.dispose();
    _ringController.dispose();
    _progressController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final primaryColor = settings.themeColor;
    final size = MediaQuery.of(context).size;

    final bgColor = isDark
        ? const Color(0xFF050508)
        : const Color(0xFFF8F9FC);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: AnimatedBuilder(
          animation: _exitController,
          builder: (context, child) {
            return Opacity(
              opacity: 1.0 - _exitController.value,
              child: child,
            );
          },
          child: Stack(
            children: [
              // 1. Fluid gradient mesh background
              _FluidMeshBackground(
                animation: _meshController,
                primaryColor: primaryColor,
                isDark: isDark,
                size: size,
              ),

              // 2. Centered content
              Center(
                child: AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo with orbital ring
                        _buildLogo(primaryColor, isDark),

                        const SizedBox(height: 48),

                        // App name with staggered letter reveal
                        _buildAppName(isDark),

                        const SizedBox(height: 8),

                        // Subtle tagline
                        _buildTagline(isDark),
                      ],
                    );
                  },
                ),
              ),

              // 3. Bottom progress indicator
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 60,
                left: 0,
                right: 0,
                child: _buildProgressLine(primaryColor, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color primaryColor, bool isDark) {
    // Entrance: scale + fade from 0.6 to 1.0 (first 60% of entrance)
    final logoProgress = Curves.easeOutBack.transform(
      (_entranceController.value / 0.6).clamp(0.0, 1.0),
    );
    final logoOpacity = Curves.easeOut.transform(
      (_entranceController.value / 0.5).clamp(0.0, 1.0),
    );

    return Opacity(
      opacity: logoOpacity,
      child: Transform.scale(
        scale: 0.6 + 0.4 * logoProgress,
        child: SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer orbital ring
              AnimatedBuilder(
                animation: _ringController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(140, 140),
                    painter: _OrbitalRingPainter(
                      progress: _ringController.value,
                      color: primaryColor,
                      isDark: isDark,
                      opacity: logoOpacity,
                    ),
                  );
                },
              ),

              // Glow behind logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(isDark ? 50 : 30),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),

              // Main logo container
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1A1A2E),
                            const Color(0xFF0F0F1A),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF0F1F5),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.black.withAlpha(8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(isDark ? 30 : 15),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Center(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        Color.lerp(primaryColor, Colors.white, 0.3)!,
                      ],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppName(bool isDark) {
    const letters = ['K', 'O', 'I', 'N'];
    // Text starts at 30% of entrance, finishes at 80%
    final textProgress = ((_entranceController.value - 0.3) / 0.5).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (i) {
        // Stagger each letter
        final letterDelay = i * 0.15;
        final letterProgress = Curves.easeOutCubic.transform(
          ((textProgress - letterDelay) / (1.0 - letterDelay)).clamp(0.0, 1.0),
        );

        return Opacity(
          opacity: letterProgress,
          child: Transform.translate(
            offset: Offset(0, 12 * (1.0 - letterProgress)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                letters[i],
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 10,
                  color: isDark
                      ? Colors.white.withAlpha(230)
                      : const Color(0xFF111827),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTagline(bool isDark) {
    // Tagline appears at 50%-90% of entrance
    final tagProgress = Curves.easeOut.transform(
      ((_entranceController.value - 0.5) / 0.4).clamp(0.0, 1.0),
    );

    return Opacity(
      opacity: tagProgress * 0.5, // Keep subtle
      child: Transform.translate(
        offset: Offset(0, 8 * (1.0 - tagProgress)),
        child: Text(
          'Smart Finance',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 4,
            color: isDark
                ? Colors.white.withAlpha(130)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_progressController.value);
        return Center(
          child: SizedBox(
            width: 48,
            height: 2,
            child: CustomPaint(
              painter: _ProgressLinePainter(
                progress: progress,
                color: primaryColor,
                isDark: isDark,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Fluid Mesh Background ─────────────────────────────────────────────

class _FluidMeshBackground extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final bool isDark;
  final Size size;

  const _FluidMeshBackground({
    required this.animation,
    required this.primaryColor,
    required this.isDark,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _MeshGradientPainter(
            time: animation.value,
            primaryColor: primaryColor,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double time;
  final Color primaryColor;
  final bool isDark;

  _MeshGradientPainter({
    required this.time,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * 2 * math.pi;

    // Create soft, flowing gradient blobs
    final points = [
      Offset(
        size.width * (0.3 + 0.15 * math.sin(t * 0.7)),
        size.height * (0.2 + 0.1 * math.cos(t * 0.5)),
      ),
      Offset(
        size.width * (0.7 + 0.12 * math.cos(t * 0.6)),
        size.height * (0.3 + 0.15 * math.sin(t * 0.8)),
      ),
      Offset(
        size.width * (0.5 + 0.2 * math.sin(t * 0.4 + 1)),
        size.height * (0.7 + 0.1 * math.cos(t * 0.6 + 2)),
      ),
      Offset(
        size.width * (0.2 + 0.1 * math.cos(t * 0.5 + 3)),
        size.height * (0.8 + 0.08 * math.sin(t * 0.7 + 1)),
      ),
    ];

    // Primary color hue-shifted variants
    final hslColor = HSLColor.fromColor(primaryColor);
    final colors = [
      hslColor.withLightness((hslColor.lightness + 0.1).clamp(0, 1)).toColor(),
      hslColor.withHue((hslColor.hue + 30) % 360).toColor(),
      hslColor.withHue((hslColor.hue - 20) % 360).withLightness((hslColor.lightness + 0.15).clamp(0, 1)).toColor(),
      primaryColor,
    ];

    // Draw each glow blob
    for (var i = 0; i < points.length; i++) {
      final alpha = isDark ? 25 + (i * 5) : 12 + (i * 3);
      final radius = size.width * (0.4 + i * 0.05);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withAlpha(alpha),
            colors[i].withAlpha(0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(
          Rect.fromCircle(center: points[i], radius: radius),
        );

      canvas.drawCircle(points[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) =>
      time != oldDelegate.time;
}

// ─── Orbital Ring Painter ───────────────────────────────────────────────

class _OrbitalRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;
  final double opacity;

  _OrbitalRingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Faint full ring
    final basePaint = Paint()
      ..color = color.withAlpha((isDark ? 20 : 12) * opacity ~/ 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, basePaint);

    // Animated arc segment — bright accent sweep
    final sweepAngle = math.pi * 0.6;
    final startAngle = progress * 2 * math.pi - math.pi / 2;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          color.withAlpha(0),
          color.withAlpha((isDark ? 120 : 80) * opacity ~/ 1),
          color.withAlpha(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Small bright dot at the leading edge of the arc
    final dotAngle = startAngle + sweepAngle;
    final dotPos = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );

    final dotPaint = Paint()
      ..color = color.withAlpha((isDark ? 180 : 120) * opacity ~/ 1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotPos, 2.5, dotPaint);

    // Glow around dot
    final glowPaint = Paint()
      ..color = color.withAlpha((isDark ? 40 : 25) * opacity ~/ 1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(dotPos, 5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingPainter oldDelegate) =>
      progress != oldDelegate.progress || opacity != oldDelegate.opacity;
}

// ─── Progress Line Painter ──────────────────────────────────────────────

class _ProgressLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _ProgressLinePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    // Background track
    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), trackPaint);

    // Filled progress
    if (progress > 0) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            color.withAlpha(isDark ? 200 : 150),
            color,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width * progress, size.height))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress, y),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLinePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
