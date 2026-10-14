import 'package:flutter/material.dart';

/// iOS Mesh / Linear Gradient background
/// Blends deep indigo (#0F172A / #1E1B4B), violet (#4C1D95 / #6D28D9), and soft cyan (#0E7490).
class AppleBackground extends StatelessWidget {
  final Widget child;

  const AppleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-.85, -.9),
          radius: 1.25,
          colors: [Color(0xFF312E81), Color(0xFF111827)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.9, -.25),
                  radius: 1.05,
                  colors: [Color(0xFF6D28D9), Colors.transparent],
                  stops: [0, .75],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.35, 1.0),
                  radius: 1.1,
                  colors: [Color(0xFF0E7490), Colors.transparent],
                  stops: [0, .8],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
