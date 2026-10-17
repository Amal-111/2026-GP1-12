import 'package:flutter/material.dart';

/// Palm tree icon (Flutter has no palm icon, Icons.park looks like a
/// Christmas tree). Use it like an Icon:
///   PalmIcon(size: 30, color: AppColors.primary)
/// Without a color it uses the normal icon color of the place it is in
/// (for example the bottom navigation bar).
class PalmIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const PalmIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final s = size ?? iconTheme.size ?? 24;
    final c = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: _PalmPainter(c)),
    );
  }
}

/// Shows the palm icon for the tree icons, and a normal Icon otherwise.
/// Handy where the code passes an IconData around.
Widget appIcon(IconData icon, {double? size, Color? color}) {
  // Not const: IconData cannot be in a const set.
  final treeIcons = <IconData>{
    Icons.park,
    Icons.park_rounded,
    Icons.park_outlined,
    Icons.park_sharp,
    Icons.forest,
    Icons.forest_rounded,
    Icons.forest_outlined,
  };
  if (treeIcons.contains(icon)) return PalmIcon(size: size, color: color);
  return Icon(icon, size: size, color: color);
}

class _PalmPainter extends CustomPainter {
  final Color color;
  _PalmPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24 x 24 grid, then scaled to the wanted size.
    final k = size.width / 24;
    Offset p(double x, double y) => Offset(x * k, y * k);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Trunk: slightly curved.
    final trunk = Path()
      ..moveTo(p(10.2, 23).dx, p(10.2, 23).dy)
      ..quadraticBezierTo(
          p(10.0, 15).dx, p(10.0, 15).dy, p(11.3, 9.5).dx, p(11.3, 9.5).dy)
      ..lineTo(p(13.3, 9.7).dx, p(13.3, 9.7).dy)
      ..quadraticBezierTo(
          p(12.4, 15).dx, p(12.4, 15).dy, p(13.6, 23).dx, p(13.6, 23).dy)
      ..close();
    canvas.drawPath(trunk, paint);

    // Leaves: each one goes out from the top of the trunk and back.
    final crown = p(12.3, 9);
    void leaf(Offset ctrl1, Offset tip, Offset ctrl2) {
      final path = Path()
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(ctrl1.dx, ctrl1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrl2.dx, ctrl2.dy, crown.dx, crown.dy)
        ..close();
      canvas.drawPath(path, paint);
    }

    leaf(p(5.0, 3.8), p(0.8, 13.0), p(7.5, 9.8)); // left, hanging
    leaf(p(19.6, 3.8), p(23.8, 13.0), p(17.1, 9.8)); // right, hanging
    leaf(p(7.0, 0.8), p(2.4, 5.2), p(9.6, 7.0)); // left, up
    leaf(p(17.6, 0.8), p(22.2, 5.2), p(15.0, 7.0)); // right, up
    leaf(p(10.2, 1.6), p(12.8, 0.4), p(14.6, 4.6)); // top

    // Dates under the leaves.
    canvas.drawCircle(p(11.2, 10.6), 1.1 * k, paint);
    canvas.drawCircle(p(13.5, 10.8), 1.1 * k, paint);
  }

  @override
  bool shouldRepaint(covariant _PalmPainter oldDelegate) =>
      oldDelegate.color != color;
}
