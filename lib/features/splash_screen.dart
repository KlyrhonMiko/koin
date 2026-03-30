import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'dart:ui' as ui;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _blobController;
  late final AnimationController _revealController;
  late final AnimationController _pulseController;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // Slow, soothing background movement
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Subtle pulse for the logo
    _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
        lowerBound: 0.98,
        upperBound: 1.02,
    )..repeat(reverse: true);

    _scheduleNavigation();
    
    // Initial haptic to signal app start
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticService.light();
    });
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && !_navigating) {
        _navigating = true;
        
        // Final haptic before transition
        HapticService.selection();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainLayout(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation, 
                      curve: Curves.easeOutCubic
                    ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 1200),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _blobController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final primaryColor = settings.themeColor;

    final bgColor = isDark 
        ? const Color(0xFF0A0A0A) // Very deep gray/black
        : const Color(0xFFFAFAFA); // Off-white

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
          children: [
            // 1. Ambient Background Glows
            _buildAmbientBackground(primaryColor, isDark),

            // 2. Grain Overlay for texture (Premium feel)
            _buildNoiseOverlay(isDark),

            // 3. Main Content Content Center
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  _buildPremiumLogo(primaryColor, isDark),
                  
                  const SizedBox(height: 56),

                  // App Name
                  _buildMinimalistText(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientBackground(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        final t = _blobController.value * 2 * math.pi;
        return Stack(
          children: [
            // Top Right Glow
            Positioned(
              top: -150 + math.sin(t) * 50,
              right: -100 + math.cos(t) * 30,
              child: _GlowOrb(
                color: primaryColor.withAlpha(isDark ? 40 : 25),
                size: 400,
                blur: 120,
              ),
            ),
            // Bottom Left Glow
            Positioned(
              bottom: -200 + math.cos(t) * 40,
              left: -150 + math.sin(t) * 60,
              child: _GlowOrb(
                color: primaryColor.withAlpha(isDark ? 30 : 20),
                size: 500,
                blur: 150,
              ),
            ),
             // Center Subtle Glow
            Positioned.fill(
              child: Center(
                child: _GlowOrb(
                  color: primaryColor.withAlpha(isDark ? 15 : 10),
                  size: 300,
                  blur: 100,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoiseOverlay(bool isDark) {
    return IgnorePointer(
      child: Opacity(
        opacity: isDark ? 0.03 : 0.05,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/noise.png'), // Need a subtle noise texture
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLogo(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseController.value,
          child: child,
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF141414) : Colors.white,
          boxShadow: [
             BoxShadow(
              color: primaryColor.withAlpha(isDark ? 40 : 20),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
            width: 1,
          ),
        ),
        child: Center(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.8),
                primaryColor,
              ],
            ).createShader(bounds),
            child: const Icon(
              Icons.blur_on_rounded, // Very abstract, fluid icon
              size: 48,
              color: Colors.white, // Color doesn't matter due to ShaderMask
            ),
          ),
        ),
      ),
    ).animate()
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.0, 1.0),
        duration: 1200.ms,
        curve: Curves.easeOutBack,
      )
      .fadeIn(duration: 800.ms)
      .shimmer(
        delay: 800.ms,
        duration: 1500.ms,
        color: isDark ? Colors.white.withAlpha(50) : primaryColor.withAlpha(50),
      );
  }

  Widget _buildMinimalistText(bool isDark) {
    return Column(
      children: [
        Text(
          "KOIN",
          style: GoogleFonts.inter( // Switching to Inter for a cleaner, universal app feel
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate()
          .fadeIn(delay: 400.ms, duration: 800.ms)
          .moveY(begin: 10, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
        
        const SizedBox(height: 12),
        
        // Animated loading indicator
        SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withAlpha(100) : Colors.black.withAlpha(60),
                ),
              ).animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(1, 1), 
                  end: const Offset(1.5, 1.5), 
                  duration: 600.ms, 
                  curve: Curves.easeInOut,
                  delay: (index * 200).ms
                )
                .then(delay: 600.ms)
                .scale(begin: const Offset(1.5, 1.5), end: const Offset(1, 1));
            }),
          ),
        ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blur,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}

