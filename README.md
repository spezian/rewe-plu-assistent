# REWE PLU Assistent

Eine Flutter-App für das schnelle Finden von PLUs, Kassenpreise und schwer
scanbare Produktbarcodes. Die App funktioniert offline-first: Änderungen landen
sofort in SQLite und werden bei einer Verbindung über eine lokale Warteschlange
mit Supabase abgeglichen.

## Funktionen

- kompakte Produktliste mit direkt sichtbarem aktuellem PLU, Preis, Barcode,
  freiem Infotext oder einer Kachel samt Kategoriepfad
  (z. B. `Obst > Exoten`)
- eigene Bereiche für Aktionen der Woche und angepinnte Produkte
- auffällige, kombinierbare Kennzeichnungen für Bio- und Aktionsprodukte
- Barcode-Vollansicht für Barcode oder PLU mit maximaler App-Helligkeit auf
  unterstützten Geräten
- Wischen zum Anpinnen/Entpinnen, langes Drücken für Details
- fehlertolerante Suche nach Name, alternativen Namen, Kategorie, PLU und Barcode
- klar abgetrennter Bereich für veraltete Codes und vollständig veraltete Produkte
- mehrere Codes je Produkt; auch alle Codes dürfen gleichzeitig veraltet sein
- mehrere Produktfotos mit Vollbild- und Zoomansicht
- komprimierte Produktfotos und separat gespeicherte Miniaturbilder für kurze
  Ladezeiten
- Cloud-Miniaturbilder werden beim Synchronisieren dauerhaft lokal gespeichert;
  Cloud-Vollbilder nach dem ersten Öffnen in der Galerie
- Fotos über Kamera, Galerie/Downloads oder produktbezogene Vorschläge von
  Unsplash
- Barcode-Erfassung per Kamera
- getrennte Produktbestände für mehrere Märkte
- Marktöffnung ohne Benutzerkonten: Marktnummer plus wahlweise Lesemodus ohne
  PIN oder Bearbeitungsmodus mit Markt-PIN
- vollständig schreibgeschützter Lesemodus für Kassenpersonal
- Offline-Datenbank und Sync-Warteschlange, jeweils strikt nach Markt getrennt
- Live-Aktualisierung geänderter Produkte auf allen geöffneten Geräten eines
  Marktes über Supabase Realtime
- dauerhaft aktivierter Bildschirm-Wakelock, auch im Web
- Kassenplan mit Tages-Zeitleisten, aktueller Planbesetzung und nächstem
  Schichtwechsel; Import aus MyPlano-HTML und dauerhafte Rollen pro Markt
- Fotoimport von Wochenplänen über Azure Layout, mit Korrekturvorschau für
  Personen und Schichten

## Lokal starten

```bash
flutter pub get
flutter run
```

Für die Browser-Version:

```bash
flutter run -d chrome
flutter build web
```

Ohne Cloud-Konfiguration arbeitet die App vollständig lokal.

## Supabase einrichten

1. Ein Supabase-Projekt erstellen.
2. Unter **Authentication → Sign In / Providers** anonyme Anmeldungen
   aktivieren. Sie dienen nur als unsichtbare Gerätesitzungen; in der App gibt
   es keine Benutzerkonten.
3. Im SQL Editor [supabase/schema.sql](supabase/schema.sql) ausführen.
   Bei einem bereits eingerichteten Projekt das aktualisierte Skript erneut
   ausführen; es aktiviert unter anderem Realtime für Produkte, ergänzt die
   Thumbnail-URLs und ersetzt die alten Benutzerkonto-Policies idempotent.
4. Den ersten Markt ausschließlich im SQL Editor anlegen. Bei der Migration aus
   der bisherigen Einzelmarkt-Version ordnet `true` alle noch nicht zugeordneten
   Cloud-Produkte diesem Markt zu:

   ```sql
   select public.create_market(
     '<MARKTNUMMER>',
     '<4-BIS-8-STELLIGE-PIN>',
     true
   );
   ```

   Weitere Märkte werden ohne den dritten Parameter angelegt:

   ```sql
   select public.create_market(
     '<MARKTNUMMER>',
     '<4-BIS-8-STELLIGE-PIN>'
   );
   ```

   Die Marktnummer wird gehasht gespeichert. Weder die App noch normale
   Datenbankabfragen können Marktlisten, Marktnummern oder PIN-Hashes auslesen.
5. Unter **Project Settings → API Keys** den **Publishable Key** kopieren. Niemals
   einen `sb_secret_...`- oder `service_role`-Key in die App einbauen. Falls ein
   Secret-Key bereits für einen Web-Build verwendet wurde, diesen in Supabase
   widerrufen/rotieren.

## Run/Build

```bash
flutter run --web \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=DEIN_PUBLISHABLE_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

Für ein Release-APK/Debug-APK gilt:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://DEIN-PROJEKT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=DEIN_PUBLISHABLE_KEY \
  --dart-define=UNSPLASH_ACCESS_KEY=DEIN_ACCESS_KEY \
```

## Fotoimport mit Azure Layout einrichten
1. Im [Azure-Portal](https://portal.azure.com/) eine **Document Intelligence**-
   Ressource anlegen, zum Ausprobieren mit Tarif **Free F0**. Der Tarif umfasst
   500 Seiten pro Monat. Unter **Schlüssel und Endpunkt** einen Schlüssel und
   die Endpunkt-Adresse dieser Ressource kopieren.
2. Im vorhandenen Supabase-Projekt unter **Edge Functions → Secrets** diese
   beiden Werte speichern:

   | Secret | Wert |
   | --- | --- |
   | `AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT` | Endpunkt aus Azure, z. B. `https://DEINE-RESSOURCE.cognitiveservices.azure.com` |
   | `AZURE_DOCUMENT_INTELLIGENCE_KEY` | Einer der Azure-Ressourcenschlüssel |
3. Mit der angemeldeten Supabase CLI die Funktion aus diesem Projekt
   bereitstellen (die Projekt-ID steht im Supabase-Dashboard):

   ```bash
   supabase functions deploy parse-plan-photo --project-ref DEINE_PROJEKT_ID
   ```

# Lizenz
Das Projekt ist lizenziert unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.
Der Großteil ist sowieso gevibecoded.
