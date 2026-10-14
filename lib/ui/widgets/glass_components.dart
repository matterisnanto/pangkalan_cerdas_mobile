import 'package:flutter/material.dart';
import 'glass_card.dart';

class MinimalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const MinimalAppBar({super.key, required this.title, this.actions});
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    actions: actions,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  );
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const GlassAppBar({super.key, required this.title, this.actions});
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    actions: actions,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  );
}

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  const GlassTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF34D399), width: 1.5),
      ),
    ),
  );
}

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = const Color(0xFF34D399),
  });
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    style: FilledButton.styleFrom(
      backgroundColor: color.withValues(alpha: .85),
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class GlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: BorderRadius.circular(32),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0xFF34D399).withOpacity(.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pelanggan',
          ),
          NavigationDestination(
            icon: Icon(Icons.language_outlined),
            selectedIcon: Icon(Icons.language),
            label: 'Portal',
          ),
        ],
      ),
    ),
  );
}
