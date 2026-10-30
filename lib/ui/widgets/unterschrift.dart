import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';
import 'common.dart';

/// Unterschrift mit dem Finger. Liefert (Pfad zum PNG, Name) zurück.
class UnterschriftScreen extends StatefulWidget {
  const UnterschriftScreen({super.key, required this.titel, this.hinweis = ''});

  final String titel;
  final String hinweis;

  @override
  State<UnterschriftScreen> createState() => _UnterschriftScreenState();
}

class _UnterschriftScreenState extends State<UnterschriftScreen> {
  final _striche = <List<Offset>>[];
  final _name = TextEditingController();
  Size _groesse = Size.zero;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _fertig() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & _groesse, Paint()..color = Colors.white);
    _UnterschriftMaler(_striche).paint(c, _groesse);
    final bild = await rec.endRecording().toImage(_groesse.width.ceil(), _groesse.height.ceil());
    final bytes = await bild.toByteData(format: ui.ImageByteFormat.png);
    final ordner = await getApplicationDocumentsDirectory();
    final d = Directory('${ordner.path}/unterschriften')..createSync(recursive: true);
    final datei = File('${d.path}/${DateTime.now().microsecondsSinceEpoch}.png');
    await datei.writeAsBytes(bytes!.buffer.asUint8List());
    if (mounted) Navigator.of(context).pop((datei.path, _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final leer = _striche.every((s) => s.length < 2);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        actions: [
          TextButton(onPressed: () => setState(_striche.clear), child: const Text('Löschen')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.hinweis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.hinweis, style: const TextStyle(color: PT.grau)),
            ),
          TextField(controller: _name, decoration: feld(labelText: 'Name in Druckbuchstaben'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              _groesse = Size(c.maxWidth, c.maxHeight);
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: PT.sand, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => _striche.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() => _striche.last.add(d.localPosition)),
                    child: CustomPaint(painter: _UnterschriftMaler(_striche), size: Size.infinite),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          const Text('Hier mit dem Finger unterschreiben', textAlign: TextAlign.center, style: TextStyle(color: PT.grau)),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: leer || _name.text.trim().isEmpty ? null : _fertig,
            child: const Text('Unterschrift übernehmen'),
          ),
        ),
      ),
    );
  }
}

class _UnterschriftMaler extends CustomPainter {
  _UnterschriftMaler(this.striche);

  final List<List<Offset>> striche;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF14213D)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in striche) {
      if (s.length < 2) continue;
      final pfad = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        pfad.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(pfad, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
