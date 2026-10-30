import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/sicherung.dart';

void main() {
  test('Sicherung packen, verschlüsseln, entschlüsseln, entpacken', () async {
    final basis = await Directory.systemTemp.createTemp('pt_sicherung');
    File('${basis.path}/bilder/a.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3, 4]);
    File('${basis.path}/modell.task').writeAsBytesSync([9, 9]);
    final werte = <String, Object?>{
      'briefe': '[{"bilder":["${basis.path}/bilder/a.jpg"]}]',
      'onboardingFertig': true,
      'zahl': 3,
      'kommazahl': 1.5,
      'mitarbeiter': ['Anna', 'Ben'],
    };
    final dateien = await dateienSammeln(basis);
    expect(dateien.map((d) => d.$1), ['bilder/a.jpg']); // KI-Modell bleibt draußen
    final geheim = await verschluesseln(sicherungPacken(werte, basis.path, dateien), 'geheim123');
    expect(String.fromCharCodes(geheim.sublist(0, 7)), 'PTSICH1');
    expect(geheim.length, greaterThan(50));

    await expectLater(entschluesseln(geheim, 'falsch123'), throwsA(isA<SicherungsFehler>()));
    await expectLater(entschluesseln(Uint8List.fromList([1, 2, 3]), 'x'), throwsA(isA<SicherungsFehler>()));

    final inhalt = sicherungEntpacken(await entschluesseln(geheim, 'geheim123'));
    expect(inhalt.basis, basis.path);
    expect(inhalt.dateien.single.$2, [1, 2, 3, 4]);
    expect(inhalt.prefs['onboardingFertig'], true);
    expect(inhalt.prefs['zahl'], 3);
    expect(inhalt.prefs['kommazahl'], 1.5);
    expect(inhalt.prefs['mitarbeiter'], ['Anna', 'Ben']);

    final neu = pfadeAnpassen(inhalt.prefs, inhalt.basis, '/neu/app');
    expect(neu['briefe'], '[{"bilder":["/neu/app/bilder/a.jpg"]}]');
    expect(neu['mitarbeiter'], ['Anna', 'Ben']);
    await basis.delete(recursive: true);
  });
}
