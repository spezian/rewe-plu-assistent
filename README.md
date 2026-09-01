# REWE PLU Assistent

Eine Flutter-App für das schnelle Finden von PLUs, Kassenpreise und schwer
scanbare Produktbarcodes. Die App funktioniert offline-first: Änderungen landen
sofort in SQLite und werden bei einer Verbindung über eine lokale Warteschlange
mit Supabase abgeglichen.

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
- Fotos über Kamera, Galerie/Downloads oder produktbezogene Vorschläge von
  Unsplash
- Barcode-Erfassung per Kamera
- Offline-Datenbank, Sync-Warteschlange und passwortgeschützte Synchronisation
- dauerhaft aktivierter Bildschirm-Wakelock

## Lokal starten

```bash
flutter pub get
flutter run
```

Ohne Cloud-Konfiguration arbeitet die App vollständig lokal.

## Supabase einrichten

1. Ein Supabase-Projekt erstellen.
2. Im SQL Editor [supabase/schema.sql](supabase/schema.sql) ausführen.
   Bei einem bereits eingerichteten Projekt das aktualisierte Skript erneut
   ausführen; es ergänzt Aliasse, Bedienerkacheln, Bilder und die für Bild-Upserts
   benötigte Storage-Lesepolicy idempotent.
3. Unter **Authentication → Users → Add user** ein gemeinsames Konto mit
   E-Mail und einem starken Zugangspasswort anlegen.

## Run/Build

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

Für ein Release-APK/Debug-APK gilt dasselbe:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=DEIN_ANON_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

# Lizenz
Das Projekt ist lizenziert unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.
Der Großteil ist sowieso gevibecoded.