/// Antwort-Vorlagen. Allgemeine Musterschreiben, keine Rechtsberatung.
library;

import '../data/models.dart';
import 'brief_analyse.dart';
import 'kommunikation.dart';
import 'format.dart';

class Vorlage {
  const Vorlage(this.key, this.titel, this.beschreibung);

  final String key;
  final String titel;
  final String beschreibung;
}

const briefVorlagen = [
  Vorlage('frist', 'Fristverlängerung', 'Mehr Zeit erbitten'),
  Vorlage('unterlagen', 'Unterlagen nachreichen', 'Angeforderte Unterlagen schicken'),
  Vorlage('rueckfrage', 'Rückfrage', 'Etwas ist unklar'),
  Vorlage('raten', 'Ratenzahlung', 'Betrag in Raten zahlen'),
  Vorlage('bezahlt', 'Schon bezahlt', 'Mahnung, obwohl bezahlt'),
  Vorlage('bestreiten', 'Forderung bestreiten', 'Betrag stimmt nicht'),
  Vorlage('erstattung', 'Erstattung beantragen', 'Geld zurück von Kasse, Versicherung oder Händler'),
];

String _heute() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _kopf(Profil p, String empfaenger, String betreff) {
  final name = p.name.isEmpty ? '[Dein Name]' : p.name;
  final adresse = p.adresse.isEmpty ? '[Deine Adresse]' : p.adresse;
  return '$name\n$adresse\n\n$empfaenger\n\n${_heute()}\n\n$betreff\n\nSehr geehrte Damen und Herren,\n\n';
}

String _fuss(Profil p) {
  final name = p.name.isEmpty ? '[Dein Name]' : p.name;
  return '\n\nMit freundlichen Grüßen\n\n$name';
}

String vorlageText(String key, Brief b, Profil p) {
  final empfaenger = kontaktVon(b, p).adresse ?? b.absenderName ?? kategorieFuer(b.kategorie).name;
  final az = b.aktenzeichen ?? 'Aktenzeichen: [bitte eintragen]';
  final vom = b.briefDatum != null ? ' vom ${_datum(b.briefDatum!)}' : '';
  final frist = b.frist != null ? ' bis zum ${_datum(b.frist!)}' : '';

  switch (key) {
    case 'frist':
      return '${_kopf(p, empfaenger, 'Betreff: $az – Bitte um Fristverlängerung')}'
          'vielen Dank für Ihr Schreiben$vom. Sie haben mir eine Frist$frist gesetzt. '
          'Leider kann ich diese Frist nicht einhalten, weil [Grund, z. B. mir noch Unterlagen fehlen].\n\n'
          'Ich bitte Sie daher, die Frist bis zum [neues Datum] zu verlängern. '
          'Bitte bestätigen Sie mir die Verlängerung kurz schriftlich.'
          '${_fuss(p)}';
    case 'unterlagen':
      return '${_kopf(p, empfaenger, 'Betreff: $az – Nachreichung von Unterlagen')}'
          'bezugnehmend auf Ihr Schreiben$vom übersende ich Ihnen die angeforderten Unterlagen:\n\n'
          '- [Unterlage 1]\n- [Unterlage 2]\n\n'
          'Sollten noch Unterlagen fehlen, geben Sie mir bitte kurz Bescheid.'
          '${_fuss(p)}';
    case 'rueckfrage':
      return '${_kopf(p, empfaenger, 'Betreff: $az – Rückfrage zu Ihrem Schreiben')}'
          'vielen Dank für Ihr Schreiben$vom. Mir ist folgender Punkt nicht klar:\n\n'
          '[Deine Frage]\n\n'
          'Ich bitte Sie um eine kurze Erläuterung. '
          'Bis zur Klärung bitte ich Sie, keine weiteren Schritte einzuleiten.'
          '${_fuss(p)}';
    case 'erstattung':
      final betrag = b.betrag != null ? '${euroBetrag(b.betrag!)}' : '[Betrag] €';
      return '${_kopf(p, empfaenger, 'Betreff: $az – Antrag auf Erstattung')}'
          'hiermit beantrage ich die Erstattung von $betrag für [Leistung oder Kauf, z. B. Brille, Behandlung, Rücksendung] '
          'vom [Datum].\n\n'
          'Begründung: [z. B. Leistung laut Tarif versichert / Ware zurückgeschickt / doppelt abgebucht].\n\n'
          'Als Nachweis lege ich bei:\n- [Rechnung oder Quittung]\n- [Zahlungsnachweis]\n\n'
          'Bitte überweisen Sie den Betrag auf mein Konto:\nIBAN: [deine IBAN]\nKontoinhaber: [Name]\n\n'
          'Sollten Sie die Erstattung ganz oder teilweise ablehnen, bitte ich um eine schriftliche Begründung.'
          '${_fuss(p)}';
    case 'nachfrage':
      final gesendet = b.antwortGesendet != null ? ' am ${_datum(b.antwortGesendet!)}' : '';
      return '${_kopf(p, empfaenger, 'Betreff: $az – Nachfrage zum Bearbeitungsstand')}'
          'bezugnehmend auf Ihr Schreiben$vom habe ich Ihnen$gesendet geantwortet. '
          'Leider habe ich bisher keine Rückmeldung erhalten.\n\n'
          'Ich bitte Sie, mir den aktuellen Stand kurz mitzuteilen. '
          'Sollten noch Unterlagen fehlen, geben Sie mir bitte Bescheid.'
          '${_fuss(p)}';
    case 'bezahlt':
      final betrag = b.betrag != null ? ' über ${euroBetrag(b.betrag!)}' : '';
      final am = b.bezahltAm != null ? 'am ${_datum(b.bezahltAm!)}' : 'am [Datum der Zahlung]';
      return '${_kopf(p, empfaenger, 'Betreff: $az – Ihre Mahnung$vom')}'
          'mit Ihrem Schreiben$vom mahnen Sie eine offene Forderung$betrag an. '
          'Diesen Betrag habe ich bereits $am per [Überweisung / Lastschrift] bezahlt.\n\n'
          'Einen Zahlungsnachweis füge ich bei. Bitte prüfen Sie Ihren Zahlungseingang, buchen Sie die Zahlung richtig zu '
          'und stellen Sie das Mahnverfahren ein. Mahngebühren erkenne ich nicht an.'
          '${_fuss(p)}\n\nAnlage: Zahlungsnachweis';
    case 'bestreiten':
      return '${_kopf(p, empfaenger, 'Betreff: $az – Widerspruch gegen Ihre Forderung$vom')}'
          'mit Ihrem Schreiben$vom fordern Sie von mir eine Zahlung. Diese Forderung bestreite ich, weil '
          '[Grund, z. B. ich keinen Vertrag mit Ihnen geschlossen habe / die Leistung nicht erbracht wurde / der Betrag falsch ist].\n\n'
          'Bitte legen Sie mir die Grundlage Ihrer Forderung schriftlich vor (Vertrag, Rechnung, Berechnung). '
          'Bis zur Klärung leiste ich keine Zahlung.'
          '${_fuss(p)}';
    case 'raten':
      final betrag = b.betrag != null
          ? 'den Betrag von ${euroBetrag(b.betrag!)}'
          : 'den geforderten Betrag';
      return '${_kopf(p, empfaenger, 'Betreff: $az – Antrag auf Ratenzahlung')}'
          'vielen Dank für Ihr Schreiben$vom. Ich kann $betrag derzeit leider nicht auf einmal bezahlen.\n\n'
          'Ich biete Ihnen an, den Betrag in monatlichen Raten von [Betrag] € zu bezahlen, '
          'beginnend am [Datum]. Bitte bestätigen Sie mir die Ratenzahlung schriftlich.'
          '${_fuss(p)}';
  }
  return '';
}

String _vertragNr(Vertrag v) => v.nummer == null || v.nummer!.isEmpty ? '[Kunden- oder Vertragsnummer]' : 'Nr. ${v.nummer}';

String _vertragArt(Vertrag v) => v.versicherungsArt != null ? '${v.versicherungsArt}-Versicherung' : v.art;

String kuendigungText(Vertrag v, Profil p, {DateTime? zum}) {
  final datum = zum != null ? 'zum ${_datum(zum)}' : 'zum nächstmöglichen Zeitpunkt';
  return '${_kopf(p, v.anbieter, 'Betreff: Kündigung meines Vertrags (${_vertragArt(v)})')}'
      'hiermit kündige ich meinen Vertrag ${_vertragNr(v)} fristgerecht $datum, '
      'hilfsweise zum nächstmöglichen Zeitpunkt.\n\n'
      'Bitte bestätigen Sie mir die Kündigung und das Vertragsende schriftlich. '
      'Einer Verlängerung oder Rückwerbung per Telefon oder E-Mail widerspreche ich.'
      '${_fuss(p)}';
}

/// Sonderkündigung, z. B. nach einer Preis- oder Beitragserhöhung.
String sonderkuendigungText(Vertrag v, Profil p, {DateTime? ab, DateTime? schreibenVom}) {
  final vom = schreibenVom != null ? ' vom ${_datum(schreibenVom)}' : '';
  final zum = ab != null ? 'zum ${_datum(ab.subtract(const Duration(days: 1)))}, also vor Inkrafttreten der Erhöhung' : 'zum Zeitpunkt des Inkrafttretens der Erhöhung';
  return '${_kopf(p, v.anbieter, 'Betreff: Sonderkündigung meines Vertrags ${_vertragNr(v)}')}'
      'mit Ihrem Schreiben$vom haben Sie mir eine Preis- bzw. Beitragserhöhung mitgeteilt. '
      'Ich mache von meinem Sonderkündigungsrecht Gebrauch und kündige den Vertrag $zum, '
      'hilfsweise zum nächstmöglichen Zeitpunkt.\n\n'
      'Bitte bestätigen Sie mir die Kündigung und das Vertragsende schriftlich.'
      '${_fuss(p)}';
}

/// Widerruf innerhalb der Widerrufsfrist (online, telefonisch oder an der Haustür geschlossen).
String widerrufText(Vertrag v, Profil p) =>
    '${_kopf(p, v.anbieter, 'Betreff: Widerruf meines Vertrags ${_vertragNr(v)}')}'
    'hiermit widerrufe ich den von mir abgeschlossenen Vertrag (${_vertragArt(v)}, abgeschlossen am [Datum]).\n\n'
    'Bitte bestätigen Sie mir den Widerruf schriftlich und erstatten Sie bereits gezahlte Beträge.'
    '${_fuss(p)}';

/// Fristwahrender Widerspruch oder Einspruch; die Begründung kann nachgereicht werden.
String rechtsbehelfText(Brief b, Profil p, String art) {
  final empfaenger = kontaktVon(b, p).adresse ?? b.absenderName ?? kategorieFuer(b.kategorie).name;
  final az = b.aktenzeichen ?? 'Aktenzeichen: [bitte eintragen]';
  final vom = b.briefDatum != null ? ' vom ${_datum(b.briefDatum!)}' : ' vom [Datum des Bescheids]';
  return '${_kopf(p, empfaenger, 'Betreff: $az – $art gegen Ihren Bescheid$vom')}'
      'hiermit lege ich gegen Ihren Bescheid$vom fristgerecht $art ein.\n\n'
      'Die Begründung reiche ich nach. [Oder hier kurz begründen, z. B. was aus deiner Sicht falsch ist.]\n\n'
      'Bitte bestätigen Sie mir den Eingang dieses Schreibens.'
      '${_fuss(p)}';
}

/// Schadensmeldung an die Versicherung.
String schadenText(Vertrag v, Profil p,
    {required String was, DateTime? wann, String wo = '', double? hoehe, String aktenzeichen = ''}) {
  final datum = wann == null ? '[Datum]' : _datum(wann);
  return '${_kopf(p, v.anbieter, 'Betreff: Schadensmeldung – ${_vertragArt(v)} ${_vertragNr(v)}')}'
      'hiermit melde ich folgenden Schaden:\n\n'
      'Datum: $datum\n'
      '${wo.isEmpty ? '' : 'Ort: $wo\n'}'
      'Was ist passiert: ${was.trim().isEmpty ? '[Beschreibung]' : was.trim()}\n'
      '${hoehe == null ? '' : 'Geschätzte Schadenshöhe: ${euroBetrag(hoehe)}\n'}'
      '${aktenzeichen.isEmpty ? '' : 'Polizeiliches Aktenzeichen: $aktenzeichen\n'}'
      '\nFotos und Belege füge ich bei. Bitte teilen Sie mir mit, welche Unterlagen Sie noch benötigen, '
      'und bestätigen Sie mir den Eingang der Schadensmeldung.'
      '${_fuss(p)}\n\nAnlagen: Fotos, Belege';
}
