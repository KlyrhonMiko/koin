import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/main_layout.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _ringController;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && !_navigating) {
        _navigating = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainLayout(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final primaryColor = settings.themeColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF8F9FA),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF8F9FA),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0A0A0A),
                      const Color(0xFF0F0F0F),
                      const Color(0xFF0A0A0A),
                    ]
                  : [
                      const Color(0xFFF8F9FA),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF8F9FA),
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle background particles
              ...List.generate(
                6,
                (i) => _buildParticle(i, primaryColor, isDark),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated logo with glow
                    _buildAnimatedLogo(primaryColor, isDark),
                    const SizedBox(height: 32),

                    // App name
                    Text(
                          'KOIN',
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                            color: isDark
                                ? const Color(0xFFF5F5F5)
                                : const Color(0xFF1A1A1A),
                          ),
                        )
                        .animate()
                        .fadeIn(
                          delay: 600.ms,
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        )
                        .slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 600.ms,
                          duration: 600.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 12),

                    // Tagline
                    Text(
                          'Smart money management',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                        )
                        .animate()
                        .fadeIn(
                          delay: 1000.ms,
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        )
                        .slideY(
                          begin: 0.4,
                          end: 0,
                          delay: 1000.ms,
                          duration: 600.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),

              // Bottom loading indicator
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildLoadingIndicator(primaryColor, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowIntensity = 0.15 + (_glowController.value * 0.2);
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: glowIntensity),
                    blurRadius: 40 + (_glowController.value * 20),
                    spreadRadius: 5 + (_glowController.value * 10),
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: glowIntensity * 0.5),
                    blurRadius: 80 + (_glowController.value * 40),
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RingPainter(
                      progress: _ringController.value,
                      color: primaryColor,
                      isDark: isDark,
                    ),
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: isDark ? 0.15 : 0.12),
                        primaryColor.withValues(alpha: isDark ? 0.05 : 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.7),
                        ],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildLoadingIndicator(Color primaryColor, bool isDark) {
    return SizedBox(
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shimmer line
          Container(
            height: 2,
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
              ).animate().fadeIn(delay: 1400.ms, duration: 400.ms),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1400.ms, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildParticle(int index, Color primaryColor, bool isDark) {
    final random = math.Random(index * 42);
    final size = 3.0 + random.nextDouble() * 4;
    final left = random.nextDouble();
    final top = random.nextDouble();
    final delay = (random.nextDouble() * 1500).toInt();

    return Positioned(
      left: MediaQuery.of(context).size.width * left,
      top: MediaQuery.of(context).size.height * top,
      child:
          Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.06),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(
                delay: Duration(milliseconds: 800 + delay),
                duration: const Duration(milliseconds: 1500),
              )
              .fadeOut(
                delay: Duration(milliseconds: 2300 + delay),
                duration: const Duration(milliseconds: 1500),
              )
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.2, 1.2),
                delay: Duration(milliseconds: 800 + delay),
                duration: const Duration(milliseconds: 3000),
                curve: Curves.easeInOut,
              ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 8;

    // Rotating arc
    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final startAngle = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 0.7,
      false,
      arcPaint,
    );

    // Second, thinner arc going opposite direction
    final arcPaint2 = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      -startAngle,
      math.pi * 0.5,
      false,
      arcPaint2,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
