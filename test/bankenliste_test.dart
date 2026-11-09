import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/bankenliste.dart';

void main() {
  final alle = bankenLesen(File('assets/daten/banken.json').readAsStringSync());

  test('Bankenliste ist gefüllt und enthält die Sparkasse Siegen', () {
    expect(alle.length, greaterThan(1000));
    final s = alle.firstWhere((b) => b.blz == '46050001');
    expect(s.name, 'Sparkasse Siegen');
    expect(s.url, 'https://banking-wl3.s-fints-pt-wl.de/fints30');
    expect(alle.every((b) => b.url.startsWith('https://')), isTrue);
  });

  test('Suche nach Name, mehreren Wörtern und Bankleitzahl', () {
    expect(bankenSuchen(alle, 'sparkasse siegen').map((b) => b.blz), contains('46050001'));
    expect(bankenSuchen(alle, 'SIEGEN').map((b) => b.name), contains('Sparkasse Siegen'));
    expect(bankenSuchen(alle, '46050001').map((b) => b.name), contains('Sparkasse Siegen'));
    expect(bankenSuchen(alle, ''), isEmpty);
    expect(bankenSuchen(alle, 'qqqxyz'), isEmpty);
  });

  test('Lesen aus JSON', () {
    final l = bankenLesen(jsonEncode([['Testbank', '12345678', 'https://x.de/fints']]));
    expect(l.single.name, 'Testbank');
    expect(l.single.url, 'https://x.de/fints');
  });
}
