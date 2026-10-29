import 'package:flutter/material.dart';

import '../theme.dart';

/// Das Papiertiger-Maskottchen, gezeichnet ohne Bilddatei.
class Tiger extends StatelessWidget {
  const Tiger({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TigerPainter()),
    );
  }
}

class _TigerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset p(double x, double y) => Offset(x * w, y * w);
    Paint fill(Color c) => Paint()..color = c;

    void circ(double x, double y, double r, Color c) =>
        canvas.drawCircle(p(x, y), r * w, fill(c));

    void poly(List<List<double>> pts, Color c) {
      final path = Path()..moveTo(pts[0][0] * w, pts[0][1] * w);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt[0] * w, pt[1] * w);
      }
      path.close();
      canvas.drawPath(path, fill(c));
    }

    const innen = Color(0xFFFFD9B0);

    // Ohren
    circ(0.24, 0.26, 0.14, PT.orange);
    circ(0.76, 0.26, 0.14, PT.orange);
    circ(0.24, 0.27, 0.07, innen);
    circ(0.76, 0.27, 0.07, innen);

    // Kopf
    canvas.drawOval(
        Rect.fromLTRB(0.12 * w, 0.20 * w, 0.88 * w, 0.92 * w), fill(PT.orange));

    // Streifen
    poly([[0.46, 0.20], [0.54, 0.20], [0.50, 0.36]], PT.tinte);
    poly([[0.33, 0.25], [0.40, 0.22], [0.41, 0.33]], PT.tinte);
    poly([[0.67, 0.25], [0.60, 0.22], [0.59, 0.33]], PT.tinte);
    poly([[0.12, 0.52], [0.27, 0.56], [0.13, 0.59]], PT.tinte);
    poly([[0.14, 0.64], [0.27, 0.66], [0.16, 0.71]], PT.tinte);
    poly([[0.88, 0.52], [0.73, 0.56], [0.87, 0.59]], PT.tinte);
    poly([[0.86, 0.64], [0.73, 0.66], [0.84, 0.71]], PT.tinte);

    // Schnauze
    canvas.drawOval(
        Rect.fromLTRB(0.30 * w, 0.58 * w, 0.70 * w, 0.88 * w), fill(Colors.white));

    // Augen
    circ(0.37, 0.50, 0.047, PT.tinte);
    circ(0.63, 0.50, 0.047, PT.tinte);
    circ(0.385, 0.485, 0.016, Colors.white);
    circ(0.645, 0.485, 0.016, Colors.white);

    // Nase
    poly([[0.44, 0.64], [0.56, 0.64], [0.50, 0.71]], PT.tinte);

    // Mund
    final mund = Paint()
      ..color = PT.tinte
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * w
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0.50 * w, 0.70 * w)
      ..lineTo(0.50 * w, 0.755 * w)
      ..moveTo(0.44 * w, 0.755 * w)
      ..quadraticBezierTo(0.47 * w, 0.80 * w, 0.50 * w, 0.755 * w)
      ..quadraticBezierTo(0.53 * w, 0.80 * w, 0.56 * w, 0.755 * w);
    canvas.drawPath(path, mund);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
