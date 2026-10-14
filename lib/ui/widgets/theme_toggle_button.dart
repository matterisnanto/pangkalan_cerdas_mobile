import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = context.watch<ThemeProvider>().isDarkMode;
    return IconButton(
      tooltip: dark ? 'Gunakan Light Mode' : 'Gunakan Dark Mode',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => context.read<ThemeProvider>().toggle(),
    );
  }
}
