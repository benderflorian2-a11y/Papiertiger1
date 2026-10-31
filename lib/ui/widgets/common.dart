import 'package:flutter/material.dart';

import '../theme.dart';

/// Weiße Karte mit weichem Rand – der Grundbaustein aller Seiten.
class PTKarte extends StatelessWidget {
  const PTKarte({
    super.key,
    required this.child,
    this.onTap,
    this.farbe = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color farbe;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: farbe,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PT.sand),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Runde Icon-Kachel in Tiger-Orange.
class IconKachel extends StatelessWidget {
  const IconKachel(this.icon,
      {super.key, this.farbe = PT.orangeHell, this.iconFarbe = PT.orangeDunkel});

  final IconData icon;
  final Color farbe;
  final Color iconFarbe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: farbe,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconFarbe, size: 24),
    );
  }
}

/// Kleines farbiges Etikett, z. B. „Dringend“ oder „in 5 Tagen“.
class Etikett extends StatelessWidget {
  const Etikett(this.text, {super.key, required this.farbe, required this.hintergrund});

  final String text;
  final Color farbe;
  final Color hintergrund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hintergrund,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: farbe, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Etikett für eine Frist, eingefärbt nach Dringlichkeit.
class FristEtikett extends StatelessWidget {
  const FristEtikett(this.datum, {super.key, this.erledigt = false});

  final DateTime datum;
  final bool erledigt;

  @override
  Widget build(BuildContext context) {
    if (erledigt) {
      return const Etikett('Erledigt', farbe: PT.gruen, hintergrund: PT.gruenHell);
    }
    final tage = tageBis(datum);
    if (tage < 0) {
      return Etikett('${-tage} ${-tage == 1 ? 'Tag' : 'Tage'} überfällig',
          farbe: PT.rot, hintergrund: PT.rotHell);
    }
    if (tage == 0) {
      return const Etikett('Heute', farbe: PT.rot, hintergrund: PT.rotHell);
    }
    final text = tage == 1 ? 'Morgen' : 'in $tage Tagen';
    if (tage <= 7) return Etikett(text, farbe: PT.rot, hintergrund: PT.rotHell);
    if (tage <= 21) return Etikett(text, farbe: PT.gelb, hintergrund: PT.gelbHell);
    return Etikett(text, farbe: PT.gruen, hintergrund: PT.gruenHell);
  }
}

/// Überschrift eines Abschnitts.
class Abschnitt extends StatelessWidget {
  const Abschnitt(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        titel,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: PT.tinte),
      ),
    );
  }
}

/// Leerer Zustand mit Tiger-Hinweis.
class LeerHinweis extends StatelessWidget {
  const LeerHinweis({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: PT.sand),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PT.grau, fontSize: 15)),
        ],
      ),
    );
  }
}

/// Ganze Tage von heute bis zum Datum (negativ = vorbei).
int tageBis(DateTime datum) {
  final heute = DateTime.now();
  final a = DateTime(heute.year, heute.month, heute.day);
  final b = DateTime(datum.year, datum.month, datum.day);
  return b.difference(a).inDays;
}

const _monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
];

String datumKurz(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String datumLang(DateTime d) => '${d.day}. ${_monate[d.month - 1]} ${d.year}';

/// „1 Brief“ / „3 Briefe“
String anzahl(int n, String eins, String viele) => '$n ${n == 1 ? eins : viele}';

String euro(double betrag) {
  final cent = (betrag * 100).round();
  final euroTeil = cent ~/ 100;
  final rest = (cent % 100).toString().padLeft(2, '0');
  final ziffern = euroTeil.toString();
  final gruppen = StringBuffer();
  for (var i = 0; i < ziffern.length; i++) {
    if (i > 0 && (ziffern.length - i) % 3 == 0) gruppen.write('.');
    gruppen.write(ziffern[i]);
  }
  return '$gruppen,$rest €';
}

void zeigeHinweis(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Datum über den Kalender-Dialog wählen.
Future<DateTime?> datumWaehlen(BuildContext context, {DateTime? start}) {
  final jetzt = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: start ?? jetzt,
    firstDate: DateTime(jetzt.year - 30),
    lastDate: DateTime(jetzt.year + 30),
    helpText: 'Datum wählen',
    cancelText: 'Abbrechen',
    confirmText: 'OK',
  );
}

/// Einheitliches Aussehen für Eingabefelder.
InputDecoration feld({String? labelText, String? hintText, String? suffixText, Widget? prefixIcon}) {
  final rand = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: PT.sand),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white,
    border: rand,
    enabledBorder: rand,
    focusedBorder: rand.copyWith(
        borderSide: const BorderSide(color: PT.orangeDunkel, width: 2)),
  );
}
