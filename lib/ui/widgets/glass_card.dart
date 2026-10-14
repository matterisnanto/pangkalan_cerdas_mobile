import 'package:flutter/material.dart';

/// Modern clean card. GlassCard name retained for existing widgets.
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
    final radius = borderRadius ?? BorderRadius.circular(18);
    Widget card = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: borderWidth,
        ),
        boxShadow:
            shadows ??
            const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
      ),
      child: child,
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
