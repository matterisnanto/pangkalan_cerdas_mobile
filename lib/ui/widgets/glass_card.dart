import 'package:flutter/material.dart';

/// Shared clean Super-App card. Legacy name retained for compatibility.
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
    final radius = borderRadius ?? BorderRadius.circular(16);
    Widget card = Card(
      margin: EdgeInsets.zero,
      elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
          width: borderWidth,
        ),
      ),
      color: backgroundColor ?? Theme.of(context).cardColor,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (onTap != null) {
      card = InkWell(borderRadius: radius, onTap: onTap, child: card);
    }
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
