# Papiertiger 1.0

## Was die App kann

- **Post verstehen:** Brief fotografieren (auch mehrseitig), aus der Galerie wählen oder Text einfügen.
  Die App erkennt Absender, Art des Briefs, Frist, Betrag und Aktenzeichen, erklärt den Brief
  in einfachen Worten und erstellt eine Aufgabenliste.
- **Antwort-Vorlagen:** Fristverlängerung, Unterlagen nachreichen, Rückfrage, Ratenzahlung –
  mit deinem Namen und deiner Adresse ausgefüllt.
- **Fristen:** alle offenen Fristen aus Briefen, Verträgen und Garantien an einem Ort.
- **Archiv:** alle Briefe durchsuchbar, nach Absender filterbar.
- **Verträge & Abos:** berechnet, bis wann du kündigen musst, und schreibt die Kündigung.
- **Belege & Garantien:** Kassenbon fotografieren, Garantieende im Blick.
- **Lebens-Ereignisse:** Checklisten für Umzug, Jobwechsel, Hochzeit und Baby.
- **Steuer:** markierte Belege und Briefe pro Jahr gesammelt, als Liste kopierbar.
- **Was steht mir zu?:** 10 Fragen, danach mögliche Leistungen mit zuständiger Stelle.
- **Anträge:** Helfer für Kindergeld und Wohngeld mit Unterlagen-Checkliste.

Alles läuft auf dem Handy. Es werden keine Daten ins Internet geschickt.

## APK bauen (vom Handy aus)

1. In deinem GitHub-Projekt `.github/workflows/` öffnen. Es darf dort nur **eine** Datei geben.
   Ihren Inhalt komplett durch den Inhalt von `.github/workflows/apk-bauen.yml` aus diesem Paket ersetzen
   und **Commit changes** drücken.
2. Auf der Startseite **Add file → Upload files** und die Datei **papiertiger.zip** hochladen
   (nicht entpacken), dann **Commit changes**.
3. Unter **Actions** den neuesten Lauf öffnen. Grün = fertig. Unten unter **Artifacts**
   `papiertiger-apk` herunterladen, entpacken, die APK aufs Handy schicken und installieren.
   Vorher die alte Test-App deinstallieren.

## Noch nicht enthalten

- KI-Erklärung mit echtem Sprachverständnis (braucht einen API-Schlüssel eines KI-Anbieters)
- Konto, Synchronisierung zwischen Geräten und Abo-Zahlung (brauchen Firebase und ein Google-Play-Konto)
- Push-Erinnerungen an Fristen
- iPhone-Version (braucht einen Mac und ein Apple-Entwicklerkonto)
