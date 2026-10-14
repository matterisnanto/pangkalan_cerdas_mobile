import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared iOS 17 ambient glass surface. Keep children intrinsically sized.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final List<BoxShadow>? shadows;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.blurSigma = 0,
    this.shadows,
  });
  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    final surface = backgroundColor ?? Colors.white.withOpacity(.16);
    final outline = borderColor ?? Colors.white.withOpacity(.35);
    final shadow =
        shadows ??
        const [
          BoxShadow(
            color: Color(0x40030A2D),
            blurRadius: 24,
            spreadRadius: -6,
            offset: Offset(0, 10),
          ),
        ];
    Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma == 0 ? 20 : blurSigma,
          sigmaY: blurSigma == 0 ? 20 : blurSigma,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: radius,
            border: Border.all(
              color: outline,
              width: borderWidth == 1 ? 1.2 : borderWidth,
            ),
            boxShadow: shadow,
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null)
      card = InkWell(borderRadius: radius, onTap: onTap, child: card);
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

class MinimalCard extends GlassCard {
  const MinimalCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.onTap,
    super.width,
    super.height,
  });
}
