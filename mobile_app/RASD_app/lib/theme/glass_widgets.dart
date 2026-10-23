import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared page layout; the light background is supplied by the theme.
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

/// Soft neutral background shared by all routes. Welcome draws its own photo.
class PalmBackground extends StatelessWidget {
  final Widget child;
  const PalmBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: child,
    );
  }
}

/// Preserve the existing navigation transition with the shared background.
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

/// Light button style with a clear border.
final ButtonStyle glassButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.white.withValues(alpha: 0.65);
    }
    final active = states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.focused);
    return Colors.white.withValues(alpha: active ? 1.0 : 0.97);
  }),
  foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
  iconColor: const WidgetStatePropertyAll(AppColors.primary),
  overlayColor: WidgetStatePropertyAll(
    AppColors.primary.withValues(alpha: 0.08),
  ),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  side: WidgetStatePropertyAll(
    BorderSide(color: AppColors.border),
  ),
);

/// Quiet light header; keep the existing title and navigation layout.
AppBar glassAppBar({
  required String title,
  Widget? leading,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    leading: leading,
    actions: actions,
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  );
}

/// Solid white card with a subtle border and shadow.
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.tint.withValues(alpha: _active ? 1.0 : 0.98),
              borderRadius: radius,
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Small readable label using the same card styling.
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

/// Shared card wrapper with the original padding and ink interactions.
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
