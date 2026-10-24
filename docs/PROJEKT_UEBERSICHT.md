# Infinity Grid – Projektübersicht

Stand: 24.10.2026. Diese Datei fasst alles Wichtige zum Projekt zusammen:
Spiel, Technik, Online-Dienste, Konten, Shop, Bezahlung, Abläufe und offene Punkte.
Sie enthält **keine** geheimen Schlüssel oder Passwörter.

## 1. Das Spiel

- **Infinity Grid**: rundenbasiertes Karten-Strategiespiel (Onitama-artig), Godot 4.7.2, GDScript.
- Brett 5×5, links/rechts **endlos** (Ränder gehen ineinander über), oben/unten geschlossen.
- Pro Seite ein **KERN** (früher „Meister“) und vier **Schüler**. Wer den gegnerischen KERN schlägt, gewinnt.
- 19 Bewegungskarten, pro Partie 5: je 2 pro Spieler + 1 Wechselkarte. Gespielte Karte tauscht mit der Wechselkarte.
- Regeln extra: Passen, wenn kein Zug möglich; **Remis** bei dreimal gleicher Stellung.
- Bot mit drei Stufen (leicht, mittel, schwer).
- Modi: gegen den Bot, ein Gerät zu zweit, **WLAN** (PC als Host), **online mit Raumcode**, **schnelles Online-Spiel** (Zufallsgegner) mit Wiederverbinden.
- Hochformat fürs Handy, Pausenmenü (Weiter, Regeln, Neue Partie, Hauptmenü / online „Aufgeben & Menü“).

## 2. Look & Design

- Menü im **Retro-Terminal-Stil** (grün, Schrift VT323, Scanlines).
- Umgebung: **Cyberpunk/Matrix** (Neon-Boden, Türme, Code-Regen).
- Spielfeld: **blaue Retro-Platine** (Leiterbahnen, Chips, Lötpunkte).
- Seiten-Skins mit echten Mustern: PLATINE, CODE (Matrix-Regen), LAVA, SYNTHWAVE, GOLD, LEERE (Sternenfeld).
- Figuren: echte animierte 3D-Menschen (Quaternius, CC0), als **Pixel-Art-Sprites** gerendert (Outline, wenige Farben, Scanlines, Randlicht in Teamfarbe).
- Kampfstile mit Animationen: **Magier** (Zauberkreis + Teleport), **Schläger** (rennt hin, haut drauf), **Schütze** (schießt, dann geht er hin), **Blitzwirker** (Blitze + Gleiten).
- Verdeckte Figuren hinter einer größeren werden als leuchtender Umriss angezeigt.

## 3. Charaktere, Skins, Sammlung

12 Charaktere (KERN-Figur):
DER SCHATTEN, DER VERKABELTE, NOVA, DAS MONSTER, BABY NULL, DIE AGENTIN, MIRA,
OPA HEINZ, RIK, DOC VOSS, BRUDER ODO, JUNO.

- Ausrüstung u. a.: langer Mantel (schwingt mit den Beinen), Sonnenbrille, runde Brille,
  Schläuche im Kopf, Implantate, Hörner, Stacheln, Hightech-Kinderwagen, leuchtendes Visier.
- Pro Charakter **2 kaufbare Skins** (24 insgesamt), z. B. Schatten „Weißer Hase“ / „Rote Pille“.
- **Echos** (Aussehen der Schüler): Hologramme, Agenten, Cyborgs, Rumpfe.
- **Sammlung**: Charakter-Galerie zum Wischen (Intro-Animation, Skin-Leiste),
  Echos, Spielfeld, **Profilbild**, Karten.
- **Profilbilder**: 4 Symbole (CODE, AUGE, GRID, GLITCH) + Porträt jedes Charakters, den man besitzt.

## 4. Konten, Anmeldung, Shop

- Jeder startet als **Gast** (Konto auf dem Server, das Gerät merkt es sich).
- **Anmelden**: mit **E-Mail + Passwort** (fertig) oder **Google** (fertig programmiert,
  muss noch eingerichtet werden, siehe offene Punkte). **Apple** folgt später
  (braucht Apple-Developer-Konto, 99 $/Jahr).
- Beim Registrieren wird der Gast-Fortschritt (Credits, Käufe) zum Konto.
  Auf anderen Geräten einfach anmelden.
- Passwörter werden nur als PBKDF2-Hash gespeichert; nach 8 Fehlversuchen 15 Minuten Sperre.
- **Credits**: 300 zum Start, +25 täglich, Bot-Siege +10/+20/+40 (max. 15 Siege pro Tag).
- **Shop**: Charaktere (300–600), Skins (250–350), Echos (250), Spielfelder (250–500).
  Preise stehen doppelt in `scripts/characters/character_roster.gd` und
  `server/online/accounts.js` – ein Test prüft, dass sie gleich sind.
- **Credit-Pakete für Echtgeld** (Stripe): +500 für 1,99 €, +1400 für 4,99 €, +3200 für 9,99 €.
  Die Kasse öffnet in einem eigenen Fenster, das Spiel bleibt offen und holt die Credits ab.
  Credits gibt es **nur** über die signierte Stripe-Meldung (Webhook) an den Server.

## 5. Online-Dienste & Adressen

| Was | Wo |
|---|---|
| Spiel (Haupt-Link) | https://infinity-grid.infinitygrid.workers.dev |
| GitHub-Pages-Kopie | https://karl3yyyy.github.io/infinity-grid/ |
| Code (öffentlich) | https://github.com/karl3yyyy/infinity-grid |
| Server | Cloudflare Worker „infinity-grid“ (Account-Subdomain „infinitygrid“) |
| Stripe (Testmodus) | Sandbox-Konto `acct_1UT6ixChrUtwv0Dv`, Webhook „infinity-grid-credits“ |

Server-Teile (`server/online/`):
- `worker.js` – Spielräume, Schnellspiel-Lobby, liefert das Web-Spiel aus.
- `accounts.js` – Konten, Credits, Besitz, Shop-Käufe.
- `auth.js` – Anmeldung (E-Mail/Passwort, Google).
- `payments.js` – Stripe-Kasse und Webhook, Danke-Seite.
- `wrangler.toml` – Einstellungen, Preis-IDs (nicht geheim).

Geheime Schlüssel liegen **nur** bei Cloudflare (`wrangler secret`), nie im Code:
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, später `GOOGLE_CLIENT_SECRET`.
Eintragen in PowerShell im Ordner `server/online` mit
`npx.cmd wrangler secret put <NAME>` (wegen der PowerShell-Sperre `npx.cmd` statt `npx`).

## 6. Abläufe

**Prüfen** (nach jeder Änderung):
`tools/check_project.ps1 -Godot "C:\Users\karld\Desktop\Godot_v4.7.2-stable_win64_console.exe"`

**Veröffentlichen** („veröffentliche alles (Cloudflare und GitHub)“):
1. `tools/prepare_github_pages.ps1 -Godot <Godot-Pfad>` baut das Web-Spiel nach `site/`.
2. `tools/publish_online.ps1` lädt Spiel + Server zu Cloudflare (Node.js im PATH).
3. `site/` committen und `git push origin main`.

Nie committen: `.import`-Dateien, `project.godot`, `scenes/main.tscn`, `.wrangler/`, `.dev.vars`.

Testkauf: im Spiel Shop → Paket → im neuen Fenster mit Testkarte
`4242 4242 4242 4242`, Datum in der Zukunft, beliebige Prüfnummer.

## 7. Offene Punkte

**Neu:** Freunde, Ranked (Ränge Bit-Runner → Data-Net Rogue → System Cipher →
Core Master → Root Sovereign, Rangliste), fester Benutzername, neues Menü mit
Animationen, Siegregel „Figur auf dem Startfeld des gegnerischen KERNs“.
Nächster Schritt: das Design-Konzept (v4) gemeinsam durchgehen.


1. **Google-Anmeldung einrichten**: Google-Cloud-Projekt + OAuth-Client anlegen,
   Client-ID in `wrangler.toml` (`GOOGLE_CLIENT_ID`), Secret mit
   `npx.cmd wrangler secret put GOOGLE_CLIENT_SECRET`. Weiterleitungs-Adresse:
   `https://infinity-grid.infinitygrid.workers.dev/auth/google/callback`.
2. **Apple-Anmeldung**: sobald ein Apple-Developer-Konto (99 $/Jahr) da ist.
3. **Stripe Live (echtes Geld)**: vorher Gewerbe anmelden, Impressum, Datenschutz,
   AGB (Widerrufsrecht digitale Inhalte), Mehrwertsteuer klären (Steuerberater);
   dann Live-Konto verifizieren, Produkte + Webhook im Live-Modus anlegen,
   Live-Schlüssel eintragen.
4. **„Passwort vergessen“** und E-Mail-Bestätigung: brauchen einen Mail-Dienst
   (eigene Domain, ca. 10 €/Jahr).

## 8. Projektregeln (Kurzfassung, Details in `AGENTS.md`)

- Godot 4 + typisiertes GDScript, kein C#, keine Plugins ohne Erlaubnis.
- Spielregeln getrennt von Grafik; Positionen als Gitter-Koordinaten.
- Kleine Skripte mit einer Aufgabe, englische Namen im Code.
- Nach Änderungen immer Validierung laufen lassen.
- Server bleibt beim Spielen nur Vermittler; Credits und Besitz entscheidet allein der Server.
