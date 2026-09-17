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
- Fotos über Kamera, Galerie/Downloads oder die Bildsuche mit Tabs für
  REWE-Produktbilder und Unsplash
- Barcode-Erfassung per Kamera
- getrennte Produktbestände für mehrere Märkte
- Marktöffnung ohne Benutzerkonten: Marktnummer plus wahlweise Lesemodus ohne
  PIN oder Bearbeitungsmodus mit Markt-PIN
- vollständig schreibgeschützter Lesemodus für Kassenpersonal
- Offline-Datenbank und Sync-Warteschlange, jeweils strikt nach Markt getrennt
- Live-Aktualisierung geänderter Produkte auf allen geöffneten Geräten eines
  Marktes über Supabase Realtime
- dauerhaft aktivierter Bildschirm-Wakelock, auch im Web

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

## REWE-Bildsuche einrichten

Unter **Produkt bearbeiten → Bild hinzufügen → Bilder im Internet vorschlagen**
öffnet sich eine gemeinsame Suche mit den Tabs **REWE** (vorausgewählt) und
**Unsplash**. Der Produktname wird übernommen. Ein Klick auf ein Bild importiert
es wie bisher samt Quelle in die Produktbilder. REWE benötigt keinen
Unsplash-Schlüssel; nur der Unsplash-Tab verwendet `UNSPLASH_ACCESS_KEY`.

Die REWE-Suche liest die Produktkarten der öffentlichen
[REWE-Suchergebnisseite](https://www.rewe.de/suche/uebersicht?searchTerm=Pfirsich#produkte)
aus. Rezeptbilder und Platzhalter werden ausgeschlossen. Es werden die Treffer
der ersten Ergebnisseite gezeigt. Produktnamen, Bildquelle und ein Link zurück
zu REWE bleiben erhalten; es wird keine freie Bildlizenz behauptet.

Für konfigurierte Supabase-Projekte muss zusätzlich die mitgelieferte Funktion
[rewe-images](supabase/functions/rewe-images/index.ts) bereitgestellt werden:

```bash
supabase functions deploy rewe-images --project-ref DEINE_PROJEKT_REFERENZ --no-verify-jwt
```

Die App verwendet automatisch `SUPABASE_URL/functions/v1/rewe-images`. Die
Funktion ist absichtlich öffentlich und liefert ausschließlich öffentliche
REWE-Suchergebnisse und Produktbilder von `img.rewe-static.de`. Sie nimmt keine
Marktdaten, PINs oder Anmeldedaten entgegen. Bildadressen, Größen und
Weiterleitungen sind eingeschränkt; Abrufe haben Zeit- und Größenlimits.
Die Funktion wird vom bestehenden GitHub-Pages/APK-Workflow **nicht** automatisch
bereitgestellt. Änderungen daran müssen erneut mit dem obigen Befehl deployt
werden.

Der Serverabruf ist für die Web-App erforderlich: REWE erlaubt der App weder das
direkte Auslesen seiner Webseite noch den direkten Bilddownload per CORS. Die
Funktion liefert die nötigen
[CORS-Header](https://supabase.com/docs/guides/functions/cors)
für Suche, Vorschaubilder und Bildimport. Ohne Supabase-Konfiguration versucht
die native App den direkten REWE-Abruf; die Web-App zeigt einen Einrichtungshinweis.

**Grenze des Scrapings:** REWE kann automatisierte Abrufe durch seinen Bot-Schutz
blockieren (beim lokalen Live-Test: HTTP 403). Auch ein Proxy garantiert keinen
Zugriff. Die App meldet eine Sperre oder eine veränderte Seitenstruktur als Fehler
und bietet das Öffnen der REWE-Suche im Browser an. Das Öffnen allein importiert
kein Bild. Die Auswertung wurde mit Produktkarten der echten Seite getestet;
ein erfolgreicher Live-Abruf vom späteren Supabase-Server muss nach dem Deployment
geprüft werden.

Prüfungen für die Bildsuche:

```bash
flutter test test/image_suggestion_service_test.dart test/internet_image_search_screen_test.dart
node --test supabase/functions/rewe-images/handler.test.mjs
```

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

# Lizenz
Das Projekt ist lizenziert unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.
Der Großteil ist sowieso gevibecoded.
