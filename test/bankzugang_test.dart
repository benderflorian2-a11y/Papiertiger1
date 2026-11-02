import 'package:fints/fints.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/bankzugang.dart';
import 'package:papiertiger/logic/kontoauszug.dart';

Transaction _t(DateTime d, int cent, String name, {String zweck = '', bool vorgemerkt = false}) => Transaction(
      bookingDate: d,
      valueDate: d,
      amount: Amount(cent, 2, 'EUR'),
      counterpartyName: name,
      purpose: zweck,
      status: vorgemerkt ? TransactionStatus.pending : TransactionStatus.booked,
    );

void main() {
  test('Bankleitzahl aus der IBAN', () {
    expect(blzAusIban('DE89 3704 0044 0532 0130 00'), '37040044');
    expect(blzAusIban('AT61 1904 3002 3457 3201'), isNull);
  });

  test('Bankumsätze werden zu Abos und Verträgen ausgewertet', () {
    final liste = <Transaction>[
      for (var m = 5; m <= 10; m++) ...[
        _t(DateTime(2026, m, 3), -3995, 'Telekom Deutschland GmbH', zweck: 'Kd-Nr 1234567890 Rechnung 01.$m.2026'),
        _t(DateTime(2026, m, 15), -1399, 'Netflix International B.V.', zweck: 'Abo'),
        _t(DateTime(2026, m, 28), 241387, 'Muster GmbH', zweck: 'Gehalt'),
      ],
      _t(DateTime(2026, 10, 30), -9574, 'Otto GmbH', zweck: 'Rechnung 4100223344', vorgemerkt: true),
    ];
    final umsaetze = umsaetzeAus(liste);
    expect(umsaetze, hasLength(18)); // Vorgemerktes fällt weg
    final text = umsaetzeAlsText(umsaetze);
    final ab = abbuchungenLesen(text, heute: DateTime(2026, 11, 2));
    expect(ab, hasLength(12));
    final wieder = wiederkehrendeAbbuchungen(ab);
    final namen = wieder.map((w) => w.empfaenger).join(' | ');
    expect(namen, contains('Telekom'));
    expect(namen, contains('Netflix'));
    expect(wieder.firstWhere((w) => w.empfaenger.contains('Netflix')).letzterBetrag, 13.99);
    expect(wieder.every((w) => w.rhythmusMonate == 1), isTrue);
    // Eingänge (Gehalt) sind keine Abbuchungen, aber als Gutschrift lesbar
    expect(gutschriftenLesen(text, heute: DateTime(2026, 11, 2)).where((g) => g.betrag == 2413.87), hasLength(6));
  });

  test('Fehlermeldungen sind verständlich', () {
    expect(bankFehlerText(StateError('x')), contains('x'));
  });
}
