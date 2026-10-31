/// Verschlüsselung der gespeicherten App-Daten (AES-256-GCM) und Prüfung der App-PIN.
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

class Tresor {
  Tresor(List<int> schluessel)
      : assert(schluessel.length == 32),
        _k = SecretKeyData(schluessel);

  /// Kennzeichnet verschlüsselte Werte. Alte, unverschlüsselte Werte werden weiter gelesen.
  static const praefix = 'PTV1:';

  final SecretKeyData _k;
  final _aes = DartAesGcm(secretKeyLength: 32);

  String verschluesseln(String klar) =>
      praefix + base64Encode(_aes.encryptSync(utf8.encode(klar), secretKeyData: _k).concatenation());

  /// Unverschlüsselte Werte kommen unverändert zurück. Wirft bei falschem Schlüssel oder Manipulation.
  String entschluesseln(String wert) {
    if (!wert.startsWith(praefix)) return wert;
    final box = SecretBox.fromConcatenation(base64Decode(wert.substring(praefix.length)), nonceLength: 12, macLength: 16);
    return utf8.decode(_aes.decryptSync(box, secretKeyData: _k));
  }
}

bool istVerschluesselt(String wert) => wert.startsWith(Tresor.praefix);

const _pinRunden = 30000;

/// Speicherform der PIN: Salz und abgeleiteter Wert, nie die PIN selbst.
Future<String> pinSpeicherform(String pin, {List<int>? salz}) async {
  final s = salz ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final k = await DartPbkdf2(macAlgorithm: const DartHmac(DartSha256()), iterations: _pinRunden, bits: 256)
      .deriveKeyFromPassword(password: pin, nonce: s);
  return '${base64Encode(s)}:${base64Encode(await k.extractBytes())}';
}

Future<bool> pinPruefen(String pin, String gespeichert) async {
  final teile = gespeichert.split(':');
  if (teile.length != 2) return false;
  final neu = await pinSpeicherform(pin, salz: base64Decode(teile[0]));
  // Vergleich ohne frühen Abbruch
  final a = utf8.encode(neu), b = utf8.encode(gespeichert);
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

/// Wartezeit nach falschen PIN-Eingaben: ab dem 5. Fehlversuch 30 s, dann jeweils doppelt (höchstens 1 Stunde).
Duration pinWartezeit(int fehlversuche) {
  if (fehlversuche < 5) return Duration.zero;
  final s = 30 * pow(2, fehlversuche - 5).toInt();
  return Duration(seconds: s > 3600 ? 3600 : s);
}

/// Einfache PINs ablehnen.
String? pinSchwach(String pin) {
  if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) return 'Die PIN braucht 6 bis 12 Ziffern.';
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return 'Bitte nicht nur dieselbe Ziffer.';
  const folgen = '01234567890987654321';
  if (folgen.contains(pin)) return 'Bitte keine Zahlenfolge wie 123456.';
  return null;
}
