import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/familie.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/familie.dart';

void main() {
  test('Nächste U-Untersuchung', () {
    final k = Kind(id: 'k', name: 'Lea', geburt: DateTime(2026, 6, 1));
    final u = naechsteUntersuchung(k, heute: DateTime(2026, 8, 15));
    expect(u!.$1, 'U4'); // U2, U3 verpasst bzw. vorbei
    expect(u.$2, DateTime(2026, 8, 1));
    expect(u.$3, DateTime(2026, 10, 1));
    k.erledigt.add('U4');
    expect(naechsteUntersuchung(k, heute: DateTime(2026, 8, 15))!.$1, 'U5');
    expect(naechsteUntersuchung(Kind(id: 'x', name: 'X'), heute: DateTime(2026)), isNull);
  });

  test('Hinweise: Kindergeld ab 18 und fällige Untersuchung', () {
    final gross = Kind(id: 'g', name: 'Tom', geburt: DateTime(2008, 12, 1));
    expect(kindHinweise(gross, heute: DateTime(2026, 11, 2)).single, contains('Familienkasse'));
    expect(alterInJahren(DateTime(2008, 12, 1), DateTime(2026, 11, 30)), 17);
    final baby = Kind(id: 'b', name: 'Lea', geburt: DateTime(2026, 6, 1));
    expect(kindHinweise(baby, heute: DateTime(2026, 7, 20)).single, startsWith('U4 für Lea'));
  });

  test('Vorsorgemappe und Notfallblatt', () {
    final v = Vorsorge(
      kontakte: [Notfallkontakt(name: 'Anna', telefon: '0171 123', beziehung: 'Tochter')],
      hausarzt: 'Dr. Weber, 0123 456',
      ablage: {'Patientenverfügung': 'Ordner im Wohnzimmerschrank'},
    );
    expect(vorsorgeStand(v), 0.6);
    final t = notfallblattText(v, Profil(name: 'Erika Muster', adresse: 'Weg 1\n12345 Ort'));
    expect(t, startsWith('Notfallblatt Erika Muster\nWeg 1, 12345 Ort'));
    expect(t, contains('- Anna (Tochter): 0171 123'));
    expect(t, contains('- Patientenverfügung: Ordner im Wohnzimmerschrank'));
    final f = Familie.fromJson(jsonDecode(jsonEncode(Familie(kinder: [Kind(id: 'k', name: 'Lea', erledigt: ['U2'])], vorsorge: v).toJson()))
        as Map<String, dynamic>);
    expect(f.kinder.single.erledigt, ['U2']);
    expect(f.vorsorge.kontakte.single.beziehung, 'Tochter');
    expect(Familie.fromJson({}).kinder, isEmpty);
  });
}
