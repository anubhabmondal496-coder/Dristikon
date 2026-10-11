import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium, fluid Liquid Glass container with customizable frosted blur,
/// specular edge highlights, and refractive glass gradients.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final double blurSigma;
  final double opacity;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final List<BoxShadow>? extraShadows;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.margin,
    this.tintColor,
    this.blurSigma = 16.0,
    this.opacity = 0.68,
    this.borderColor,
    this.borderWidth = 1.8,
    this.onTap,
    this.extraShadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? Colors.white.withValues(alpha: 0.85);
    final effectiveTint = tintColor ?? Colors.white;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // Multi-stop liquid specular refraction gradient
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                effectiveTint.withValues(alpha: opacity),
                effectiveTint.withValues(alpha: (opacity * 0.55).clamp(0.0, 1.0)),
              ],
              stops: const [0.1, 0.95],
            ),
            border: Border.all(
              color: effectiveBorderColor,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );

    // Apply soft ambient liquid elevation and rim glow
    content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: extraShadows ??
            [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: -2,
                offset: const Offset(0, -2),
              ),
            ],
      ),
      child: content,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppTheme.accentAmber.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.3),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A liquid glass circular button
class LiquidGlassCircleButton extends StatelessWidget {
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final Color? tintColor;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;

  const LiquidGlassCircleButton({
    super.key,
    required this.child,
    this.size = 54,
    this.onTap,
    this.tintColor,
    this.borderColor,
    this.borderWidth = 1.8,
    this.blurSigma = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tintColor ?? Colors.white;
    final effectiveBorder = borderColor ?? Colors.white.withValues(alpha: 0.85);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      effectiveTint.withValues(alpha: 0.75),
                      effectiveTint.withValues(alpha: 0.40),
                    ],
                  ),
                  border: Border.all(
                    color: effectiveBorder,
                    width: borderWidth,
                  ),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An ambient fluid background featuring subtle chromatic liquid glow orbs
/// that make translucent liquid glass filters refract color and light.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;
  final Color? baseColor;

  const LiquidGlassBackground({
    super.key,
    required this.child,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: baseColor ?? const Color(0xFFF1F5F9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Fluid Light Orb 1 (Top Left Amber Warmth)
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentAmber.withValues(alpha: 0.28),
                    AppTheme.accentAmberLight.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Ambient Fluid Light Orb 2 (Center Right Ocean Blue)
          Positioned(
            top: 220,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withValues(alpha: 0.20),
                    AppTheme.accentBlueLight.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Ambient Fluid Light Orb 3 (Bottom Left Emerald/Safe Glow)
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.alertSafe.withValues(alpha: 0.18),
                    const Color(0xFFDCFCE7).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Main child content layer
          child,
        ],
      ),
    );
  }
}
