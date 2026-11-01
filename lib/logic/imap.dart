/// Kleiner IMAP-Leser: anmelden, Posteingang schreibgeschützt öffnen (EXAMINE), neue Nachrichten laden.
/// Lädt mit BODY.PEEK, markiert also nichts als gelesen. Löscht, verschiebt und verschickt nie etwas.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ImapFehler implements Exception {
  ImapFehler(this.text, {this.anmeldung = false});

  final String text;

  /// Benutzername oder Passwort wurden abgelehnt.
  final bool anmeldung;

  @override
  String toString() => text;
}

class ImapAntwort {
  ImapAntwort(this.status, this.text, this.zeilen, this.literale);

  /// OK, NO oder BAD
  final String status;

  /// Rest der Abschlusszeile
  final String text;

  /// Zeilen mit „*“; Literale stehen darin als {#0}, {#1} …
  final List<String> zeilen;
  final List<Uint8List> literale;
}

class ImapVerbindung {
  ImapVerbindung._(this._socket) {
    _socket.listen(
      (d) {
        _puf.addAll(d);
        _wecken();
      },
      onError: (Object e) {
        _fehler = e;
        _wecken();
      },
      onDone: () {
        _zu = true;
        _wecken();
      },
    );
  }

  final Socket _socket;
  final List<int> _puf = [];
  int _pos = 0;
  Completer<void>? _warten;
  bool _zu = false;
  Object? _fehler;
  int _nr = 0;

  static const zeitlimit = Duration(seconds: 30);

  /// Verbindet und liest die Begrüßung. [tls] = false nur für Tests.
  static Future<ImapVerbindung> verbinden(String server, int port, {bool tls = true}) async {
    final Socket s;
    try {
      s = tls
          ? await SecureSocket.connect(server, port, timeout: const Duration(seconds: 20))
          : await Socket.connect(server, port, timeout: const Duration(seconds: 20));
    } on HandshakeException {
      throw ImapFehler('Die sichere Verbindung zu $server ist fehlgeschlagen.');
    } on SocketException {
      throw ImapFehler('$server ist nicht erreichbar. Bist du online, und stimmt der Server?');
    }
    final v = ImapVerbindung._(s);
    final gruss = await v._zeile();
    if (!gruss.startsWith('* OK') && !gruss.startsWith('* PREAUTH')) {
      v.schliessen();
      throw ImapFehler('Der Server meldet sich nicht wie ein E-Mail-Server.');
    }
    return v;
  }

  void _wecken() {
    final w = _warten;
    _warten = null;
    w?.complete();
  }

  Future<void> _mehr() async {
    if (_fehler != null) throw ImapFehler('Die Verbindung wurde unterbrochen.');
    if (_zu) throw ImapFehler('Der Server hat die Verbindung beendet.');
    final w = _warten = Completer<void>();
    await w.future.timeout(zeitlimit, onTimeout: () => throw ImapFehler('Der Server antwortet nicht.'));
  }

  void _aufraeumen() {
    if (_pos > 65536) {
      _puf.removeRange(0, _pos);
      _pos = 0;
    }
  }

  Future<String> _zeile() async {
    var i = _pos;
    while (true) {
      for (; i + 1 < _puf.length; i++) {
        if (_puf[i] == 13 && _puf[i + 1] == 10) {
          final z = latin1.decode(_puf.sublist(_pos, i));
          _pos = i + 2;
          _aufraeumen();
          return z;
        }
      }
      await _mehr();
    }
  }

  Future<Uint8List> _bytes(int n) async {
    while (_puf.length - _pos < n) {
      await _mehr();
    }
    final b = Uint8List.fromList(_puf.sublist(_pos, _pos + n));
    _pos += n;
    _aufraeumen();
    return b;
  }

  static final _literal = RegExp(r'\{(\d+)\}$');

  /// Schickt einen Befehl und sammelt die Antwort bis zur Abschlusszeile.
  Future<ImapAntwort> befehl(String text) async {
    final tag = 'p${++_nr}';
    _socket.add(utf8.encode('$tag $text\r\n'));
    final zeilen = <String>[];
    final literale = <Uint8List>[];
    while (true) {
      var z = await _zeile();
      for (var m = _literal.firstMatch(z); m != null; m = _literal.firstMatch(z)) {
        literale.add(await _bytes(int.parse(m[1]!)));
        z = '${z.substring(0, m.start)}{#${literale.length - 1}}${await _zeile()}';
      }
      if (z.startsWith('$tag ')) {
        final rest = z.substring(tag.length + 1);
        final i = rest.indexOf(' ');
        return ImapAntwort((i < 0 ? rest : rest.substring(0, i)).toUpperCase(), i < 0 ? '' : rest.substring(i + 1), zeilen, literale);
      }
      zeilen.add(z);
    }
  }

  static String _q(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  Future<void> anmelden(String benutzer, String passwort) async {
    final a = await befehl('LOGIN ${_q(benutzer)} ${_q(passwort)}');
    if (a.status != 'OK') {
      throw ImapFehler('Anmeldung abgelehnt${a.text.isEmpty ? '' : ': ${a.text}'}', anmeldung: true);
    }
  }

  /// Öffnet den Posteingang schreibgeschützt. Liefert UIDVALIDITY.
  Future<int> posteingang() async {
    final a = await befehl('EXAMINE INBOX');
    if (a.status != 'OK') throw ImapFehler('Der Posteingang ließ sich nicht öffnen.');
    for (final z in a.zeilen) {
      final m = RegExp(r'UIDVALIDITY (\d+)', caseSensitive: false).firstMatch(z);
      if (m != null) return int.parse(m[1]!);
    }
    return 0;
  }

  static const _monate = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Future<List<int>> _suchen(String kriterium) async {
    final a = await befehl('UID SEARCH $kriterium');
    if (a.status != 'OK') throw ImapFehler('Suche im Posteingang fehlgeschlagen.');
    return [
      for (final z in a.zeilen)
        if (z.toUpperCase().startsWith('* SEARCH'))
          for (final t in z.substring(8).trim().split(' '))
            if (int.tryParse(t) != null) int.parse(t),
    ]..sort();
  }

  /// Nachrichten seit diesem Tag.
  Future<List<int>> seit(DateTime tag) =>
      _suchen('SINCE ${tag.day}-${_monate[tag.month - 1]}-${tag.year}');

  /// Nachrichten nach dieser UID.
  Future<List<int>> nach(int uid) async => [for (final u in await _suchen('UID ${uid + 1}:*')) if (u > uid) u];

  /// Größe einer Nachricht in Bytes.
  Future<int?> groesse(int uid) async {
    final a = await befehl('UID FETCH $uid (RFC822.SIZE)');
    for (final z in a.zeilen) {
      final m = RegExp(r'RFC822\.SIZE (\d+)', caseSensitive: false).firstMatch(z);
      if (m != null) return int.parse(m[1]!);
    }
    return null;
  }

  /// Die ganze Nachricht (oder nur den Kopf), ohne sie als gelesen zu markieren.
  Future<Uint8List?> laden(int uid, {bool nurKopf = false}) async {
    final a = await befehl('UID FETCH $uid (BODY.PEEK[${nurKopf ? 'HEADER' : ''}])');
    if (a.status != 'OK' || a.literale.isEmpty) return null;
    return a.literale.first;
  }

  Future<void> abmelden() async {
    try {
      await befehl('LOGOUT').timeout(const Duration(seconds: 5));
    } catch (_) {}
    schliessen();
  }

  void schliessen() {
    try {
      _socket.destroy();
    } catch (_) {}
  }
}
