import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Plain see-through page. The palm background and the glass colors
/// come from the app theme (see app_theme.dart), so every page in the
/// app looks the same.
class PalmScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  const PalmScaffold({super.key, this.appBar, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: body,
    );
  }
}

/// Palm photo behind every page. Used by the page transitions in
/// app_theme.dart, so each screen gets it automatically.
class PalmBackground extends StatelessWidget {
  final Widget child;
  const PalmBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/palm_background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

/// Page transition that puts the palm background behind each page.
class PalmPageTransitionsBuilder extends PageTransitionsBuilder {
  const PalmPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const ZoomPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      PalmBackground(child: child),
    );
  }
}

/// White see-through button style; more solid on hover or press.
final ButtonStyle glassButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.white.withValues(alpha: 0.3);
    }
    final active = states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.focused);
    return Colors.white.withValues(alpha: active ? 0.92 : 0.6);
  }),
  foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
  iconColor: const WidgetStatePropertyAll(AppColors.primary),
  overlayColor: WidgetStatePropertyAll(
    AppColors.primary.withValues(alpha: 0.08),
  ),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  side: WidgetStatePropertyAll(
    BorderSide(color: Colors.white.withValues(alpha: 0.8)),
  ),
);

/// Transparent AppBar that matches the glass boxes.
AppBar glassAppBar({
  required String title,
  Widget? leading,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    leading: leading,
    actions: actions,
    backgroundColor: Colors.white.withValues(alpha: 0.6),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  );
}

/// A see-through box that becomes more solid when the mouse is over it,
/// when it is pressed, or when a field inside it is being typed in.
class GlassBox extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Color of the box (white by default).
  final Color tint;

  const GlassBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.tint = Colors.white,
  });

  @override
  State<GlassBox> createState() => _GlassBoxState();
}

class _GlassBoxState extends State<GlassBox> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _active => _hovered || _pressed || _focused;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.tint.withValues(alpha: _active ? 0.92 : 0.55),
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small glass box for a title or a line of text that sits on the
/// background photo, so it is easy to read.
class GlassLabel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassLabel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return GlassBox(padding: padding, radius: 12, child: child);
  }
}

/// Drop-in replacement for Flutter's Card with the glass look.
/// Change `Card(` to `GlassCard(` and keep the same child and margin.
class GlassCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final double radius;

  const GlassCard({
    super.key,
    this.child,
    this.margin,
    this.clipBehavior,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.all(4),
      child: GlassBox(
        padding: EdgeInsets.zero,
        radius: radius,
        // Material keeps the tap ripple of ListTile / InkWell working.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// Shows a message in the middle of the screen.
/// It closes by itself after 2 seconds, or when tapped.
Future<void> showCenterMessage(
  BuildContext context,
  String text, {
  bool success = true,
}) {
  final navigator = Navigator.of(context);
  var isOpen = true;

  Future.delayed(const Duration(seconds: 2), () {
    if (isOpen && navigator.mounted) navigator.pop();
  });

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (dialogContext) => GestureDetector(
      onTap: () => Navigator.pop(dialogContext),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 44,
                    color: success ? AppColors.primary : AppColors.monitoring,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ).then((_) {
    isOpen = false;
  });
}
