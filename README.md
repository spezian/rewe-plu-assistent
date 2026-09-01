# REWE PLU Assistent

Eine webbasierte Flutter-App für das schnelle Finden von PLUs, Kassenpreisen
und schwer scanbaren Produktbarcodes. Sie läuft als installierbare Progressive
Web App (PWA) und funktioniert offline-first: Änderungen landen sofort in einer
lokalen SQLite-Datenbank im Browser (IndexedDB) und werden bei einer Verbindung
über eine lokale Warteschlange mit Supabase abgeglichen.

## Funktionen

- kompakte Produktliste mit direkt sichtbarem aktuellem PLU, Preis, Barcode
  oder einer Bedienerkachel samt Kategoriepfad (z. B. `Obst > Exoten`)
- auffällige, kombinierbare Kennzeichnungen für Bio- und Aktionsprodukte
- Barcode-Vollansicht für Barcode oder PLU mit maximaler App-Helligkeit
- Wischen zum Anpinnen/Entpinnen, langes Drücken für Details
- fehlertolerante Suche nach Name, alternativen Namen, Kategorie, PLU und Barcode
- klar abgetrennter Bereich für veraltete Codes und vollständig veraltete Produkte
- mehrere Codes je Produkt; auch alle Codes dürfen gleichzeitig veraltet sein
- mehrere Produktfotos mit Vollbild- und Zoomansicht
- Fotos über Kamera, Dateiauswahl oder produktbezogene Vorschläge von
  Unsplash
- Barcode-Erfassung per Kamera
- Offline-Datenbank, Sync-Warteschlange und passwortgeschützte Synchronisation
- Screen-Wakelock, sofern der Browser ihn unterstützt

## Lokal starten

```bash
flutter pub get
flutter run -d chrome
```

Ohne Cloud-Konfiguration arbeitet die App vollständig lokal. Der Kamerazugriff
funktioniert in Browsern nur in einem sicheren Kontext, also unter `https://`
oder auf `localhost`.

Nach einem Update von `sqflite_common_ffi_web` lassen sich die eingecheckten
Browser-Binärdateien mit `dart run sqflite_common_ffi_web:setup --force`
erneuern.

## Supabase einrichten

1. Ein Supabase-Projekt erstellen.
2. Im SQL Editor [supabase/schema.sql](supabase/schema.sql) ausführen.
   Bei einem bereits eingerichteten Projekt das aktualisierte Skript erneut
   ausführen; es ergänzt Aliasse, Bedienerkacheln, Bilder und die für Bild-Upserts
   benötigte Storage-Lesepolicy idempotent.
3. Unter **Authentication → Users → Add user** ein gemeinsames Konto mit
   E-Mail und einem starken Zugangspasswort anlegen.

## Start mit Cloud-Konfiguration

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

## Web-Release bauen

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

Das veröffentlichungsfertige Ergebnis liegt anschließend in `build/web` und
kann auf jedem statischen HTTPS-Host bereitgestellt werden. Die Dateien
`web/sqlite3.wasm` und `web/sqflite_sw.js` gehören zum Projekt und ermöglichen
den lokalen Offline-Speicher.

# Lizenz
Das Projekt ist lizenziert unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.
Der Großteil ist sowieso gevibecoded.
