import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/sprachbefehl.dart';

void main() {
  test('Sprachbefehle verstehen', () {
    final e = befehlVerstehen('Milch und Eier auf die Einkaufsliste');
    expect(e.art, BefehlArt.einkauf);
    expect(e.rest, 'milch, eier');
    expect(befehlVerstehen('schreib Brot auf meine Einkaufsliste').rest, 'brot');
    expect(befehlVerstehen('Was muss ich diese Woche bezahlen?').art, BefehlArt.zahlungen);
    expect(befehlVerstehen('Was ist diese Woche fällig').art, BefehlArt.fristen);
    expect(befehlVerstehen('Wann ist mein nächster Termin').art, BefehlArt.termine);
    final s = befehlVerstehen('Zeig mir den Mietvertrag');
    expect(s.art, BefehlArt.suche);
    expect(s.rest, 'mietvertrag');
    expect(befehlVerstehen('Neuer Brief').art, BefehlArt.scannen);
    expect(befehlVerstehen('Wie wird das Wetter').art, BefehlArt.unbekannt);
  });
}
