import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/widget_text.dart';
import 'package:papiertiger/logic/zeitplan.dart';

void main() {
  test('Text fürs Startbildschirm-Widget', () {
    final heute = DateTime(2026, 11, 2, 9);
    final f = [
      Faelligkeit(FaelligArt.brief, DateTime(2026, 11, 1), 'Mahnung Stadtwerke', '', 'a'),
      Faelligkeit(FaelligArt.vertrag, DateTime(2026, 11, 3), 'Handyvertrag kündigen', '', 'b'),
      Faelligkeit(FaelligArt.termin, DateTime(2026, 11, 20), 'TÜV', '', 'c'),
      Faelligkeit(FaelligArt.termin, DateTime(2026, 12, 20), 'Zahnarzt', '', 'd'),
    ];
    final (titel, text) = widgetTexte(f, offeneZahlungen: 2, summe: '120,00 €', heute: heute);
    expect(titel, 'Als Nächstes: überfällig');
    expect(text, '• überfällig: Mahnung Stadtwerke\n• morgen: Handyvertrag kündigen\n• 20.11.: TÜV\n€ 2 offen: 120,00 €');
    expect(widgetTexte([], offeneZahlungen: 0, summe: '', heute: heute), ('Papiertiger', 'Nichts offen. Der Tiger schläft entspannt.'));
  });
}
