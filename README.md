# REWE PLU Assistent

Eine schnelle, Android-exklusive Flutter-App für PLUs, Kassenpreise und schwer
scanbare Produktbarcodes. Die App funktioniert offline-first: Änderungen landen
sofort in SQLite und werden bei einer Verbindung über eine lokale Warteschlange
mit Supabase abgeglichen.

## Funktionen

- kompakte Produktliste mit direkt sichtbarem aktuellem PLU/Preis
- auffällige, kombinierbare Kennzeichnungen für Bio- und Aktionsprodukte
- Barcode-Vollansicht für Barcode oder PLU mit maximaler App-Helligkeit
- Wischen zum Anpinnen/Entpinnen, langes Drücken für Details
- fehlertolerante Suche nach Name, alternativen Namen, Kategorie, PLU und Barcode
- klar abgetrennter Bereich für veraltete Codes und vollständig veraltete Produkte
- mehrere Codes je Produkt; auch alle Codes dürfen gleichzeitig veraltet sein
- mehrere Produktfotos mit Vollbild- und Zoomansicht
- Fotos über Kamera, Galerie/Downloads oder produktbezogene Vorschläge von
  Wikimedia Commons; Quelle und Lizenz werden am Vollbild gespeichert
- Barcode-Erfassung per Kamera
- Offline-Datenbank, Sync-Warteschlange und passwortgeschützte Synchronisation
- dauerhaft aktivierter Bildschirm-Wakelock

Die Android Application-ID lautet `eu.dacjan.rewe_plu_assistent`.

## Lokal starten

```bash
flutter pub get
flutter run
```

Ohne Cloud-Konfiguration arbeitet die App vollständig lokal. Das Wolken-Symbol
zeigt dann „Nur lokal“.

## Supabase einrichten

1. Ein Supabase-Projekt erstellen.
2. Im SQL Editor [supabase/schema.sql](supabase/schema.sql) ausführen.
   Bei einem bereits eingerichteten Projekt das aktualisierte Skript erneut
   ausführen; es ergänzt Aliasse und die neue Bildertabelle idempotent.
3. Unter **Authentication → Users → Add user** ein gemeinsames Konto mit
   E-Mail und einem starken Zugangspasswort anlegen. Öffentliche Registrierungen
   und anonyme Anmeldungen werden nicht benötigt.
4. App mit Projekt-URL und öffentlichem Anon-Key starten. Die optionale
   `SUPABASE_LOGIN_EMAIL` füllt die E-Mail vor, das Passwort wird niemals in die
   App kompiliert:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=SUPABASE_LOGIN_EMAIL=kasse@example.de \
  --dart-define='WIKIMEDIA_USER_AGENT=RewePLUAssistent/1.2 (kontakt@example.de)'
```

Für ein Release-APK gelten dieselben Defines:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=SUPABASE_LOGIN_EMAIL=kasse@example.de \
  --dart-define='WIKIMEDIA_USER_AGENT=RewePLUAssistent/1.2 (kontakt@example.de)'
```

Die Supabase-Sitzung bleibt nach erfolgreicher Anmeldung sicher auf dem Gerät
gespeichert. Mehrere Geräte sehen denselben Datenbestand, wenn sie dasselbe
Konto verwenden. Row-Level-Security verhindert Zugriffe anderer Konten.

Die Bildsuche verwendet die öffentliche Wikimedia-Commons-API. Für den
veröffentlichten Einsatz sollte `WIKIMEDIA_USER_AGENT` eine erreichbare
Kontaktadresse enthalten. Die App speichert Urheber/Lizenz und verlinkt die
Commons-Quellseite in der Vollbildansicht.

## Offline- und Konfliktverhalten

Speichern, Pinnen, Reaktivieren und Löschen wirken sofort lokal. Pro Produkt wird
der jeweils jüngste ausstehende Sync-Auftrag behalten. Beim nächsten erreichbaren
Netz wird zuerst hoch- und danach heruntergeladen. Lokale, noch nicht übertragene
Änderungen werden beim Download nie überschrieben; ansonsten gewinnt der neuere
`updated_at`-Stand.

## Prüfen

```bash
flutter analyze
flutter test
flutter build apk --debug
```
