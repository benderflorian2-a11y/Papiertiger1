import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../logic/kostenplan.dart';
import '../theme.dart';
import 'common.dart';

/// Feste Farbe je Kostengruppe (Reihenfolge wie [kostenGruppen]); geprüft auf Farbsehschwäche
/// für benachbarte Ringstücke in dieser Reihenfolge.
const kostenFarben = <Color>[
  Color(0xFF2A78D6), // Wohnen & Energie
  Color(0xFFEB6834), // Rechnungen & Bescheide
  Color(0xFF1BAF7A), // Versicherungen
  Color(0xFFEDA100), // Einkauf & Haushalt
  Color(0xFFE87BA4), // Freizeit & Abos
  Color(0xFF008300), // Weitere
];

/// Ring mit den Kostengruppen eines Monats, Summe in der Mitte, Legende darunter.
/// Antippen einer Gruppe zeigt ihre Einzelposten.
class KostenKreis extends StatefulWidget {
  const KostenKreis({super.key, required this.plan, required this.monatName});

  final Kostenplan plan;
  final String monatName;

  @override
  State<KostenKreis> createState() => _KostenKreisState();
}

class _KostenKreisState extends State<KostenKreis> {
  int? _gewaehlt;

  void _waehlen(int? i) => setState(() => _gewaehlt = _gewaehlt == i ? null : i);

  int? _treffer(Offset p, Size s) {
    final mitte = s.center(Offset.zero);
    final d = p - mitte;
    final r = d.distance;
    final aussen = s.shortestSide / 2;
    if (r < aussen * 0.55 || r > aussen + 8) return null;
    var winkel = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (winkel < 0) winkel += 2 * math.pi;
    final gesamt = widget.plan.gesamt;
    var start = 0.0;
    for (final g in widget.plan.gruppen) {
      final w = g.betrag / gesamt * 2 * math.pi;
      if (winkel >= start && winkel < start + w) return g.index;
      start += w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final gesamt = plan.gesamt;
    final auswahl = plan.gruppen.where((g) => g.index == _gewaehlt).firstOrNull;
    if (plan.gruppen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(Icons.donut_large, size: 56, color: PT.grau.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('Für ${widget.monatName} steht noch nichts an.', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Verträge, Belege und Briefe mit Beträgen erscheinen hier automatisch.',
              textAlign: TextAlign.center, style: TextStyle(color: PT.grau, fontSize: 13)),
        ]),
      );
    }
    return Column(children: [
      LayoutBuilder(builder: (context, box) {
        final groesse = math.min(box.maxWidth, 230.0);
        return Center(
          child: GestureDetector(
            onTapUp: (d) => _waehlen(_treffer(d.localPosition, Size.square(groesse))),
            child: SizedBox.square(
              dimension: groesse,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                  size: Size.square(groesse),
                  painter: _RingMaler(plan.gruppen, gesamt, _gewaehlt),
                ),
                Padding(
                  padding: EdgeInsets.all(groesse * 0.2),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(auswahl?.name ?? 'Steht an im ${widget.monatName}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(color: PT.grau, fontSize: 12.5, height: 1.2)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(euro(auswahl?.betrag ?? gesamt),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: PT.tinte)),
                    ),
                    if (auswahl != null)
                      Text('${(auswahl.betrag / gesamt * 100).round()} %',
                          style: const TextStyle(color: PT.grau, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 14),
      for (final g in plan.gruppen) ...[
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _waehlen(g.index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: kostenFarben[g.index], borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(g.name,
                    style: TextStyle(fontWeight: _gewaehlt == g.index ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text('${(g.betrag / gesamt * 100).round()} %', style: const TextStyle(color: PT.grau, fontSize: 13)),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(euro(g.betrag),
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Icon(_gewaehlt == g.index ? Icons.expand_less : Icons.expand_more, size: 18, color: PT.grau),
            ]),
          ),
        ),
        if (_gewaehlt == g.index)
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 22, 8),
            child: Column(children: [
              for (final (text, betrag) in g.teile.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                        child: Text(text,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PT.grau, fontSize: 13))),
                    Text(euro(betrag), style: const TextStyle(color: PT.grau, fontSize: 13)),
                  ]),
                ),
              if (g.teile.length > 8)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('und ${g.teile.length - 8} weitere', style: const TextStyle(color: PT.grau, fontSize: 12)),
                ),
            ]),
          ),
      ],
    ]);
  }
}

class _RingMaler extends CustomPainter {
  _RingMaler(this.gruppen, this.gesamt, this.gewaehlt);

  final List<KostenGruppe> gruppen;
  final double gesamt;
  final int? gewaehlt;

  @override
  void paint(Canvas canvas, Size size) {
    final dicke = size.shortestSide * 0.13;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - dicke / 2 - 4);
    // Spalt zwischen den Stücken: 2 px am Ring
    final spalt = gruppen.length > 1 ? 2.5 / rect.width * 2 : 0.0;
    var start = -math.pi / 2;
    for (final g in gruppen) {
      final w = g.betrag / gesamt * 2 * math.pi;
      final aktiv = gewaehlt == null || gewaehlt == g.index;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gewaehlt == g.index ? dicke + 8 : dicke
        ..color = kostenFarben[g.index].withValues(alpha: aktiv ? 1 : 0.35);
      final bogen = math.max(w - spalt, 0.01);
      canvas.drawArc(rect, start + spalt / 2, bogen, false, p);
      start += w;
    }
  }

  @override
  bool shouldRepaint(_RingMaler alt) => alt.gruppen != gruppen || alt.gesamt != gesamt || alt.gewaehlt != gewaehlt;
}
