import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  late final AnimationController _blobController;
  late final AnimationController _logoPulseController;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scheduleNavigation();
    
    // Initial haptic to signal app start
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticService.light();
    });
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_navigating) {
        _navigating = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainLayout(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _blobController.dispose();
    _logoPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final primaryColor = settings.themeColor;

    final bgColor = isDark 
        ? const Color(0xFF0C0C0C) 
        : const Color(0xFFF9FAFB);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // Premium Moving Blobs
            _buildAnimatedBlobs(primaryColor, isDark),

            // Glassmorphic Overlay (subtle)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor.withAlpha(isDark ? 100 : 150),
                ),
              ),
            ),

            // Main Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with sophisticated glow
                  _buildRefinedLogo(primaryColor, isDark),
                  
                  const SizedBox(height: 48),

                  // App Name with staggered letter animation
                  _buildAnimatedAppName(isDark),

                  const SizedBox(height: 16),

                  // Premium Tagline
                  _buildTagline(isDark),
                ],
              ),
            ),

            // Minimalist Loading Line
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: _buildMinimalistLoading(primaryColor, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBlobs(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        return Stack(
          children: [
            _buildBlob(
              color: primaryColor.withAlpha(isDark ? 35 : 25),
              size: 400,
              offset: Offset(
                math.sin(_blobController.value * 2 * math.pi) * 50 - 50,
                math.cos(_blobController.value * 2 * math.pi) * 30 - 100,
              ),
              blur: 80,
            ),
            _buildBlob(
              color: primaryColor.withAlpha(isDark ? 25 : 15),
              size: 300,
              offset: Offset(
                math.cos(_blobController.value * 2 * math.pi) * 80 + 150,
                math.sin(_blobController.value * 2 * math.pi) * 60 + 200,
              ),
              blur: 100,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlob({
    required Color color,
    required double size,
    required Offset offset,
    required double blur,
  }) {
    return Positioned(
      top: offset.dy + (MediaQuery.of(context).size.height / 2) - (size / 2),
      left: offset.dx + (MediaQuery.of(context).size.width / 2) - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ).animate().fadeIn(duration: 2.seconds).blur(
            begin: Offset(blur, blur),
            end: Offset(blur, blur),
          ),
    );
  }

  Widget _buildRefinedLogo(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _logoPulseController,
      builder: (context, child) {
        final pulse = _logoPulseController.value;
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha((40 + (pulse * 20)).toInt()),
                blurRadius: 40 + (pulse * 20),
                spreadRadius: 5 + (pulse * 5),
              ),
            ],
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
              primaryColor,
              primaryColor.withValues(alpha: 0.8),
            ],
          ),
          border: Border.all(
            color: Colors.white.withAlpha(50),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(30),
            ),
            child: const Icon(
              Icons.all_inclusive_rounded, // More abstract and premium than a dollar sign
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    ).animate()
      .scale(
        begin: const Offset(0.4, 0.4),
        end: const Offset(1.0, 1.0),
        duration: 1200.ms,
        curve: Curves.elasticOut,
      )
      .fadeIn(duration: 800.ms);
  }

  Widget _buildAnimatedAppName(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: "KOIN".split("").asMap().entries.map((entry) {
        return Text(
          entry.value,
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: entry.key < 2 ? FontWeight.w800 : FontWeight.w300,
            letterSpacing: 4,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate()
          .fadeIn(delay: (400 + entry.key * 100).ms, duration: 600.ms)
          .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack, delay: (400 + entry.key * 100).ms);
      }).toList(),
    );
  }

  Widget _buildTagline(bool isDark) {
    return Text(
      "Refining your financial flow",
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
        color: isDark 
            ? Colors.white.withAlpha(120) 
            : const Color(0xFF6B7280),
      ),
    ).animate()
      .fadeIn(delay: 1000.ms, duration: 800.ms)
      .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic, delay: 1000.ms);
  }

  Widget _buildMinimalistLoading(Color primaryColor, bool isDark) {
    return Container(
      width: 120,
      height: 3,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withAlpha(100),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1500.ms, color: Colors.white.withAlpha(150))
            .moveX(begin: -120, end: 120, duration: 1500.ms, curve: Curves.easeInOutSine),
        ],
      ),
    ).animate().fadeIn(delay: 1200.ms);
  }
}

