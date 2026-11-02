// Prüfstand: liest alle Testbriefe aus test/briefe, wertet sie wie die App aus und schreibt
// einen Bericht nach build/briefpruefung/. Mit KI_ANTWORTEN=<ordner> werden zusätzlich die
// Antworten der echten KI (Gemma, im Workflow „KI prüfen“ erzeugt) eingelesen und bewertet.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/brief_analyse.dart';
import 'package:papiertiger/logic/brief_inhalt.dart';
import 'package:papiertiger/logic/ki_auswertung.dart';
import 'package:papiertiger/logic/ordnung.dart';

final heute = DateTime(2026, 11, 2);

String _d(DateTime? d) => d == null ? '–' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Brief _briefAus(String name, String text) {
  final a = analysiereBrief(text, heute: heute);
  return Brief(
    id: name,
    erstellt: heute,
    kategorie: a.kategorie.key,
    typ: a.typ.key,
    absenderName: a.absenderName,
    text: text,
    erklaerung: a.erklaerung,
    bilder: const [],
    frist: a.frist,
    fristUnsicher: a.fristUnsicher,
    betrag: a.betrag,
    guthaben: a.istGuthaben,
    aktenzeichen: a.aktenzeichen,
    briefDatum: a.briefDatum,
    aufgaben: a.aufgaben.map(Aufgabe.new).toList(),
    fakten: a.fakten,
    bedeutung: a.bedeutung,
    unterlagen: unterlagenFinden(text).map(Aufgabe.new).toList(),
  );
}

/// Abweichungen von den Erwartungen in erwartet.json.
List<String> _abweichungen(Brief b, Map<String, dynamic> e) {
  final f = <String>[];
  if (e['kategorie'] != null && e['kategorie'] != b.kategorie) f.add('Absender ${b.kategorie} statt ${e['kategorie']}');
  if (e['typ'] != null && e['typ'] != b.typ) f.add('Art ${b.typ} statt ${e['typ']}');
  if (e['betrag'] != null && ((b.betrag ?? -1) - (e['betrag'] as num)).abs() > 0.005) {
    f.add('Betrag ${b.betrag} statt ${e['betrag']}');
  }
  if (e['guthaben'] == true && !b.guthaben) f.add('Guthaben nicht erkannt');
  if (e['frist'] != null && _d(b.frist) != e['frist']) f.add('Frist ${_d(b.frist)} statt ${e['frist']}');
  return f;
}

void main() {
  final ordner = Directory('test/briefe');
  final erwartet = (jsonDecode(File('test/briefe/erwartet.json').readAsStringSync()) as Map).cast<String, dynamic>();
  final dateien = ordner.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final aus = Directory('build/briefpruefung/prompts')..createSync(recursive: true);
  final kiOrdner = Platform.environment['KI_ANTWORTEN'];

  test('Prüfstand: alle Testbriefe auswerten', () {
    final regeln = StringBuffer('# Prüfstand ohne KI (Stichworte)\n\n');
    final ki = StringBuffer('# Prüfstand mit KI (Gemma 4 E2B)\n\n');
    var fehlerRegeln = 0, fehlerKi = 0, kiGelesen = 0;
    for (final datei in dateien) {
      final name = datei.uri.pathSegments.last.replaceAll('.txt', '');
      final text = datei.readAsStringSync();
      final e = (erwartet[name] as Map?)?.cast<String, dynamic>() ?? {};
      File('${aus.path}/$name.txt').writeAsStringSync(kiAnfrage(text));

      final b = _briefAus(name, text);
      final inhalt = inhaltLesen(text, briefDatum: b.briefDatum);
      final f = _abweichungen(b, e);
      fehlerRegeln += f.length;
      regeln
        ..writeln('## ${f.isEmpty ? '✅' : '❌'} $name')
        ..writeln('- Absender: ${b.kategorie} · ${b.absenderName ?? '–'} · Art: ${b.typ}')
        ..writeln('- Betrag: ${b.betrag ?? '–'}${b.guthaben ? ' (Guthaben)' : ''} · Frist: ${_d(b.frist)} · Briefdatum: ${_d(b.briefDatum)}')
        ..writeln('- Erklärung: ${b.erklaerung}')
        ..writeln('- Kurz gesagt: ${inhalt.kurz}')
        ..writeln('- Angaben: ${inhalt.punkte.map((p) => '${p.label}=${p.wert}').join(' · ')}');
      for (final x in f) {
        regeln.writeln('- **FEHLER: $x**');
      }
      regeln.writeln();

      if (kiOrdner != null) {
        final antwortDatei = File('$kiOrdner/$name.txt');
        if (!antwortDatei.existsSync()) {
          ki.writeln('## ⚠️ $name: keine KI-Antwort\n');
          continue;
        }
        final roh = antwortDatei.readAsStringSync();
        final k = kiAntwortLesen(roh);
        final bk = _briefAus(name, text);
        kiUebernehmen(bk, k);
        if (k.brauchbar) kiGelesen++;
        final fk = [if (!k.brauchbar) 'Antwort nicht verwertbar', ..._abweichungen(bk, e)];
        fehlerKi += fk.length;
        ki
          ..writeln('## ${fk.isEmpty ? '✅' : '❌'} $name')
          ..writeln('- KI: Absender „${k.absender ?? '–'}“ · Art „${k.art ?? '–'}“ · Geld ${k.geld.name} ${k.betrag ?? ''} · Frist ${_d(k.frist)}')
          ..writeln('- Danach in der App: ${bk.kategorie} · ${bk.typ} · Betrag ${bk.betrag ?? '–'}${bk.guthaben ? ' (Guthaben)' : ''} · Frist ${_d(bk.frist)}')
          ..writeln('- Kurzfassung: ${k.kurzfassung}')
          ..writeln('- Bedeutung: ${k.bedeutung.join(' / ')}')
          ..writeln('- Zu tun: ${k.zuTun.join(' / ')}')
          ..writeln('- Prüfen: ${k.pruefen.join(' / ')}');
        for (final x in fk) {
          ki.writeln('- **FEHLER: $x**');
        }
        ki
          ..writeln('<details><summary>Rohantwort</summary>\n\n```\n${roh.trim()}\n```\n</details>')
          ..writeln();
      }
    }
    final kopf = '${dateien.length} Briefe · $fehlerRegeln Abweichungen ohne KI'
        '${kiOrdner == null ? '' : ' · $fehlerKi Abweichungen mit KI · $kiGelesen verwertbare KI-Antworten'}';
    File('build/briefpruefung/regeln.md').writeAsStringSync('$kopf\n\n$regeln');
    if (kiOrdner != null) File('build/briefpruefung/ki.md').writeAsStringSync('$kopf\n\n$ki');
    // ignore: avoid_print
    print('PRÜFSTAND: $kopf');
  });
}
