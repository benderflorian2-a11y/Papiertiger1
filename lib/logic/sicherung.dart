/// Verschlüsselte Datensicherung: alle Daten und Fotos in einer Datei, geschützt mit einem
/// Passwort, das nur du kennst (AES-256-GCM, Schlüssel per PBKDF2). Ohne Passwort ist die Datei wertlos.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _kennung = 'PTSICH1';
const _iterationen = 120000;

/// Dateien, die nicht in die Sicherung gehören (KI-Modell, sehr große Dateien).
bool _ueberspringen(File f, int groesse) {
  final n = f.path.toLowerCase();
  return groesse > 40 * 1024 * 1024 ||
      n.endsWith('.task') ||
      n.endsWith('.litertlm') ||
      n.endsWith('.bin') ||
      n.endsWith('.tflite') ||
      n.contains('/flutter_assets/');
}

/// Einstellungen aus SharedPreferences als JSON-taugliche Werte (mit Typ).
Map<String, Object?> _kodieren(Map<String, Object?> prefs) => {
      for (final e in prefs.entries)
        e.key: switch (e.value) {
          final List l => {'t': 'l', 'v': [for (final x in l) '$x']},
          final bool b => {'t': 'b', 'v': b},
          final int i => {'t': 'i', 'v': i},
          final double d => {'t': 'd', 'v': d},
          final Object? o => {'t': 's', 'v': o?.toString()},
        },
    };

Map<String, Object?> _dekodieren(Map<String, dynamic> j) => {
      for (final e in j.entries)
        e.key: switch ((e.value as Map)['t']) {
          'l' => [for (final x in (e.value as Map)['v'] as List) '$x'],
          'b' => (e.value as Map)['v'] as bool,
          'i' => ((e.value as Map)['v'] as num).toInt(),
          'd' => ((e.value as Map)['v'] as num).toDouble(),
          _ => (e.value as Map)['v'] as String?,
        },
    };

/// Inhalt der Sicherung (noch unverschlüsselt): Kopf-JSON mit Einstellungen und Dateiliste,
/// danach die Dateien hintereinander.
Uint8List sicherungPacken(Map<String, Object?> prefs, String basis, List<(String, Uint8List)> dateien) {
  final kopf = utf8.encode(jsonEncode({
    'version': 1,
    'erstellt': DateTime.now().toIso8601String(),
    'basis': basis,
    'prefs': _kodieren(prefs),
    'dateien': [for (final (pfad, b) in dateien) {'pfad': pfad, 'laenge': b.length}],
  }));
  final out = BytesBuilder(copy: false);
  final laenge = ByteData(4)..setUint32(0, kopf.length);
  out.add(laenge.buffer.asUint8List());
  out.add(kopf);
  for (final (_, b) in dateien) {
    out.add(b);
  }
  return out.takeBytes();
}

class SicherungsInhalt {
  SicherungsInhalt({required this.prefs, required this.basis, required this.dateien, required this.erstellt});

  final Map<String, Object?> prefs;

  /// Ordner der App auf dem alten Gerät (Pfade werden beim Zurückspielen angepasst).
  final String basis;

  /// Relativer Pfad → Inhalt.
  final List<(String, Uint8List)> dateien;
  final DateTime? erstellt;
}

SicherungsInhalt sicherungEntpacken(Uint8List daten) {
  final bd = ByteData.sublistView(daten);
  final kopfLaenge = bd.getUint32(0);
  final kopf = jsonDecode(utf8.decode(daten.sublist(4, 4 + kopfLaenge))) as Map<String, dynamic>;
  var pos = 4 + kopfLaenge;
  final dateien = <(String, Uint8List)>[];
  for (final d in (kopf['dateien'] as List).cast<Map<String, dynamic>>()) {
    final n = (d['laenge'] as num).toInt();
    dateien.add((d['pfad'] as String, Uint8List.sublistView(daten, pos, pos + n)));
    pos += n;
  }
  return SicherungsInhalt(
    prefs: _dekodieren(kopf['prefs'] as Map<String, dynamic>),
    basis: kopf['basis'] as String? ?? '',
    dateien: dateien,
    erstellt: DateTime.tryParse(kopf['erstellt'] as String? ?? ''),
  );
}

Future<SecretKey> _schluessel(String passwort, List<int> salz) => Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterationen,
      bits: 256,
    ).deriveKeyFromPassword(password: passwort, nonce: salz);

/// Verschlüsselt den Inhalt: Kennung, Salz (16), Nonce (12), Chiffretext, MAC (16).
Future<Uint8List> verschluesseln(Uint8List klartext, String passwort) async {
  final aes = AesGcm.with256bits();
  final salz = aes.newNonce().followedBy(aes.newNonce()).take(16).toList();
  final schluessel = await _schluessel(passwort, salz);
  final nonce = aes.newNonce();
  final box = await aes.encrypt(klartext, secretKey: schluessel, nonce: nonce);
  final out = BytesBuilder(copy: false)
    ..add(utf8.encode(_kennung))
    ..add(salz)
    ..add(nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return out.takeBytes();
}

/// Entschlüsselt; wirft [SicherungsFehler] bei falschem Passwort oder beschädigter Datei.
Future<Uint8List> entschluesseln(Uint8List daten, String passwort) async {
  final k = utf8.encode(_kennung);
  if (daten.length < k.length + 16 + 12 + 16 || utf8.decode(daten.sublist(0, k.length), allowMalformed: true) != _kennung) {
    throw SicherungsFehler('Das ist keine Papiertiger-Sicherung.');
  }
  var p = k.length;
  final salz = daten.sublist(p, p + 16);
  p += 16;
  final nonce = daten.sublist(p, p + 12);
  p += 12;
  final text = daten.sublist(p, daten.length - 16);
  final mac = Mac(daten.sublist(daten.length - 16));
  try {
    final klar = await AesGcm.with256bits()
        .decrypt(SecretBox(text, nonce: nonce, mac: mac), secretKey: await _schluessel(passwort, salz));
    return Uint8List.fromList(klar);
  } on SecretBoxAuthenticationError {
    throw SicherungsFehler('Falsches Passwort – oder die Datei ist beschädigt.');
  }
}

class SicherungsFehler implements Exception {
  SicherungsFehler(this.text);
  final String text;
  @override
  String toString() => text;
}

/// Sammelt alle Dateien der App (Fotos, PDFs, Unterschriften) unterhalb von [basis].
Future<List<(String, Uint8List)>> dateienSammeln(Directory basis) async {
  final out = <(String, Uint8List)>[];
  if (!basis.existsSync()) return out;
  await for (final e in basis.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final groesse = await e.length();
    if (_ueberspringen(e, groesse)) continue;
    final rel = e.path.substring(basis.path.length).replaceFirst(RegExp(r'^/+'), '');
    out.add((rel, await e.readAsBytes()));
  }
  return out;
}

/// Pfade aus dem alten Gerät auf den neuen App-Ordner umschreiben.
Map<String, Object?> pfadeAnpassen(Map<String, Object?> prefs, String alt, String neu) {
  if (alt.isEmpty || alt == neu) return prefs;
  return {
    for (final e in prefs.entries)
      e.key: switch (e.value) {
        final String s => s.replaceAll(alt, neu),
        final List l => [for (final x in l) '$x'.replaceAll(alt, neu)],
        final Object? o => o,
      },
  };
}
