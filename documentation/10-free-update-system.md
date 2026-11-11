# ElvonOS: Update-System ohne laufende Kosten

Stand: 2026-11-10 · Ziel: Updates für ElvonOS (Debian-13-Basis, Live-ISO und
installierte Systeme) **kostenlos** hosten, signieren und ausliefern — ohne
Bezahl-CDN, ohne Abo und ohne Vendor-Lock-in.

„Kostenlos" heißt hier zweifach:

1. **Null Euro Betriebskosten** (Hosting, Bandbreite, CI).
2. **Freie Software** für alle beteiligten Werkzeuge (APT, GPG/minisign,
   zstd, Rust, GitHub Actions).

---

## 1. Was heute existiert

| Baustein | Aktueller Stand |
|---|---|
| Basis | Debian 13 Trixie, Kernel `6.12.116-elvonos` |
| Paket-Updates | Einstellungen → Updates ruft `apt-get update` / `apt-get upgrade` |
| Auslieferung | Live-ISO `ElvonOS-1.0.0-amd64.iso` (selbst gebaut) |
| Signatur | noch keine eigene Update-Signatur |
| Hosting | noch kein eigener Kanal |

Damit Updates kostenlos bleiben, brauchen wir nur zwei Dinge:

- **einen statischen, gratis erreichbaren Ort** für Metadaten + Artefakte,
- **einen Client**, der diese Metadaten prüft, verifiziert und anwendet.

---

## 2. Empfohlene Gratis-Architektur

```
                    ┌──────────────────────────────┐
   GitHub Actions   │  Build + Signatur + Release  │
   (kostenlos für   │  ISO, .deb-Pool, Deltas      │
    public repos)   └──────────────┬───────────────┘
                                   │ veröffentlicht
        ┌──────────────────────────▼───────────────────────────┐
        │  GitHub Releases (Artefakte, unbegrenzte Bandbreite) │
        │  GitHub Pages / raw.githubusercontent (Update-Feed)  │
        └──────────────────────────┬───────────────────────────┘
                                   │ HTTPS
                    ┌──────────────▼──────────────┐
                    │  elvonos-update (Rust)      │
                    │  check → verify → apply     │
                    └──────────────┬──────────────┘
                                   │
                 APT-Repo (installiert) / ISO-Wechsel (live)
```

**Kernentscheidung:** Der Update-Feed ist eine **statische JSON-Datei**, die
zusammen mit den Artefakten in einem öffentlichen GitHub-Repository liegt.
Kein Server, keine Datenbank, keine API-Kosten.

---

## 3. Kostenlose Hosting-Optionen im Vergleich

| Anbieter | Kosten | Grenzen | Bandbreite | Geeignet für |
|---|---|---|---|---|
| **GitHub Releases** | 0 € | 2 GB pro Datei, public repo | unbegrenzt (Fair Use) | ISO, Delta-Patches, `.deb`-Bundles |
| **GitHub Pages** | 0 € | 1 GB Site, 100 GB/Monat soft | CDN (Fastly) | Update-Feed `stable.json`, kleine Metadaten |
| **raw.githubusercontent.com** | 0 € | – | CDN | Feed ohne Pages-Setup |
| **Codeberg (Forgejo)** | 0 € | ~2 GB/Release | Fair Use | Zweitmirror, EU-Hosting |
| **SourceForge** | 0 € | unbegrenzt | Werbung/Spiegel | Drittmirror, Archiv |
| **Cloudflare R2** | 0 € bis 10 GB, **0 € Egress** | 10 GB Storage, 1 Mio. Class-A/Monat | über Cloudflare-CDN | APT-Pool, große Dateien |
| **Backblaze B2 + Cloudflare** | 0 € Egress (Bandwidth Alliance) | 10 GB Storage frei | über Cloudflare | APT-Pool |
| **IPFS + Pinning** | 0 € (Free-Tier) | je nach Pinner | P2P | Zensurresistenter Mirror |
| **BitTorrent** | 0 € | – | P2P | ISO-Verteilung, entlastet HTTP |

**Empfehlung für ElvonOS:**

1. **Primär:** GitHub Releases für alle Artefakte + `stable.json` im Repo
   (bzw. GitHub Pages).
2. **Sekundär:** Codeberg als EU-Mirror (gleiche Dateien, gleiche Signaturen).
3. **Optional:** Cloudflare R2 als APT-Pool, sobald der `.deb`-Bestand
   wächst (0 € Egress ist der entscheidende Punkt).
4. **Optional:** Torrent-Magnetlink für das ISO in der Release-Beschreibung.

---

## 4. Update-Feed: Format und Signatur

`stable.json` (statisch, versioniert im Repo):

```json
{
  "channel": "stable",
  "version": "1.0.1",
  "released": "2026-11-20T12:00:00Z",
  "min_supported": "1.0.0",
  "iso": {
    "url": "https://github.com/elvonos/elvonos/releases/download/v1.0.1/ElvonOS-1.0.1-amd64.iso",
    "size": 6215200768,
    "sha256": "…",
    "signature": "…/ElvonOS-1.0.1-amd64.iso.minisig"
  },
  "delta": {
    "from": "1.0.0",
    "url": "…/ElvonOS-1.0.0_to_1.0.1.iso.zstpatch",
    "sha256": "…",
    "signature": "…/ElvonOS-1.0.0_to_1.0.1.iso.zstpatch.minisig"
  },
  "packages": {
    "base_url": "https://github.com/elvonos/elvonos-repo/releases/download/v1.0.1",
    "inrelease": "InRelease",
    "inrelease_signature": "InRelease.minisig"
  }
}
```

Regeln:

- **Jede** Datei wird mit **minisign** signiert (oder OpenPGP, siehe unten).
- Der Client lädt `stable.json` + `stable.json.minisig`, verifiziert mit dem
  im ISO eingebetteten Public Key und **erst danach** die Artefakte.
- `version` muss monoton steigen (Rollback-Schutz).
- `min_supported` verhindert Updates von zu alten Systemen.
- Alle URLs ausschließlich HTTPS; optional zusätzlich SHA-256 prüfen.

### Signatur mit minisign (kostenlos, einfach)

```sh
# Einmalig (offline aufbewahren!)
minisign -G -p elvonos.pub -s elvonos.key -c "ElvonOS update signing key"

# Artefakt signieren
minisign -Sm ElvonOS-1.0.1-amd64.iso \
  -s elvonos.key -t "ElvonOS 1.0.1"

# Prüfen
minisign -Vm ElvonOS-1.0.1-amd64.iso -p elvonos.pub
```

Public Key im ISO ablegen: `/usr/share/elvonos/update/elvonos.pub`.
Alternativ/ergänzend OpenPGP für das APT-Repo (`InRelease` clearsigned) —
GPG ist kostenlos und ohnehin Debian-Standard.

---

## 5. APT-Repository kostenlos betreiben

Für **installierte** Systeme bleibt APT der richtige Weg. Ein eigenes,
signiertes Repo lässt sich ohne Server bauen:

```sh
# 1. Pakete sammeln
mkdir -p repo/pool/main
cp elvonos-*.deb repo/pool/main/

# 2. Metadaten erzeugen
cd repo
apt-ftparchive packages pool > Packages
gzip -kf Packages
apt-ftparchive release . > Release

# 3. Release signieren (GPG-Schlüssel kostenlos)
gpg --default-key "$KEYID" --clearsign -o InRelease Release
gpg --default-key "$KEYID" -abs -o Release.gpg Release
```

Hosting-Varianten ohne Kosten:

- **GitHub Releases**: `repo/` als `repo.tar.zst` hochladen; der Client
  entpackt nach `/var/lib/elvonos/repo` und nutzt
  `deb [signed-by=/usr/share/keyrings/elvonos.gpg] file:/var/lib/elvonos/repo stable main`.
  Nachteil: kein inkrementelles `apt update` über HTTP, dafür nur ein
  Download pro Release.
- **Cloudflare R2** (10 GB frei, 0 € Egress): `repo/` als statische Dateien,
  `deb [signed-by=…] https://repo.elvonos.org stable main` mit CNAME auf R2.
- **GitHub Pages**: nur für kleine Repos (< 1 GB) sinnvoll.

**Empfehlung:** Kleine Phase → Release-Bundle; ab ~1 GB Pool → R2.

---

## 6. Delta-Updates: nur Änderungen übertragen

Ein vollständiges ISO sind ~6 GB. Für Patches genügt ein Bruchteil:

```sh
# Patch erzeugen (zstd ≥ 1.5)
zstd --patch-from=ElvonOS-1.0.0-amd64.iso \
     ElvonOS-1.0.1-amd64.iso -o ElvonOS-1.0.0_to_1.0.1.iso.zstpatch

# Patch anwenden
zstd -d --patch-from=ElvonOS-1.0.0-amd64.iso \
     ElvonOS-1.0.0_to_1.0.1.iso.zstpatch -o ElvonOS-1.0.1-amd64.iso
```

- Funktioniert gut, wenn sich wenige Dateien ändern (Kernel, Apps, Settings).
- Für viele kleine Änderungen ist **casync/desync** (freie Software) besser:
  chunk-basierte Synchronisation, nur geänderte Blöcke.
- Der Patch selbst wird wieder mit minisign signiert.

---

## 7. Client: `elvonos-update` (Rust)

Neues Binary im Stil von `elvonos-waydroid`, ohne externe Abhängigkeiten:

```
elvonos-update check            # Feed laden, Signatur prüfen, Version vergleichen
elvonos-update download [--delta]  # Artefakt laden, prüfen, nach /var/cache/elvonos/update legen
elvonos-update apply            # APT-Upgrade bzw. ISO-Staging vorbereiten
elvonos-update status [--json]  # für Einstellungen → Updates
```

Eigenschaften:

- Feed- und Artefakt-Signatur mit minisign (Public Key im ISO).
- SHA-256 zusätzlich zur Signatur.
- Atomarer Download (`.part` → `rename`), Wiederaufnahme per HTTP-Range.
- Rollback-Schutz über monotone `version` + gespeicherte letzte Version.
- Kein Root für `check`; Root nur für `apply`.
- Fortschritt/JSON für die Settings-UI.

Integration in **Einstellungen → Updates**:

- „Nach Updates suchen“ → `elvonos-update check --json`
- Kanalwahl (stable/beta) → `~/.config/elvonos/update-channel`
- „Herunterladen“ / „Installieren“ mit Fortschrittsbalken im vorhandenen Log.

---

## 8. CI: alles automatisch und gratis

GitHub Actions ist für öffentliche Repos kostenlos. Beispiel-Workflow:

```yaml
name: release
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Build ISO
        run: sudo bash build/phase7/build-iso.sh
      - name: Sign
        env:
          MINISIGN_KEY: ${{ secrets.MINISIGN_KEY }}
        run: |
          echo "$MINISIGN_KEY" > key
          minisign -Sm build/out/ElvonOS-*-amd64.iso -s key
          sha256sum build/out/ElvonOS-*-amd64.iso > SHA256SUMS
      - name: Publish release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/out/ElvonOS-*.iso
            build/out/ElvonOS-*.iso.minisig
            SHA256SUMS
      - name: Update feed
        run: bash build/update/publish-feed.sh
```

`publish-feed.sh` schreibt `stable.json` + Signatur und committet sie
(z. B. nach `gh-pages`). Kein Server nötig.

---

## 9. Sicherheit

| Risiko | Maßnahme |
|---|---|
| Manipulierter Feed | minisign/GPG-Signatur, Public Key im ISO |
| Manipuliertes Artefakt | Signatur **und** SHA-256 |
| Downgrade-Angriff | monotone Version, gespeicherte letzte Version |
| Schlüsselverlust | Offline-Backup, zweiter Key im ISO, Rotation via Feed-Feld `next_key` |
| Kompromittierter CI-Runner | Secrets nur im Release-Job, Build reproduzierbar, manuelle Freigabe für Tags |
| GitHub-Ausfall | Codeberg-Mirror + Torrent; Client versucht Mirror-Liste |

---

## 10. Rechtliches / Fair Use

- GitHub erlaubt Release-Binaries für öffentliche Projekte; exzessives
  CDN-Missbrauch (z. B. als generischer File-Host) ist nicht erlaubt.
  Ein OS-Release pro Version ist unproblematisch.
- GitHub Pages: max. 1 GB Site, 100 GB/Monat Soft-Limit — nur für Feeds
  und kleine Repos nutzen.
- Codeberg/SourceForge haben eigene Fair-Use-Regeln; als Mirror okay.
- Lizenzen: alle genannten Werkzeuge (APT, GPG, minisign, zstd, casync,
  Rust, GitHub Actions) sind freie Software; die Sounds sind
  `sound-theme-freedesktop` aus Debian main (DFSG-frei).

---

## 11. Rollout-Plan

- [ ] `elvonos.pub`/`elvonos.key` erzeugen, Pubkey ins ISO
- [ ] `stable.json`-Schema + `publish-feed.sh` implementieren
- [ ] `elvonos-update` (Rust) mit check/download/apply
- [ ] Einstellungen → Updates an den Client anbinden (JSON + Log)
- [ ] GitHub-Actions-Workflow für Build + Signatur + Release
- [ ] Delta-Patch (`zstd --patch-from`) im Release erzeugen
- [ ] Codeberg-Mirror automatisieren
- [ ] Cloudflare R2 optional für den APT-Pool
- [ ] Torrent-Magnetlink ins Release
- [ ] Dokumentation der Schlüssel-Rotation

---

## 12. Kostenübersicht (realistisch)

| Posten | Kosten |
|---|---|
| GitHub Releases + Actions (public) | 0 € |
| Update-Feed (GitHub Pages/raw) | 0 € |
| Domain (optional) | ~10 €/Jahr (nicht nötig) |
| Cloudflare R2 (optional, 10 GB) | 0 € |
| Codeberg-Mirror | 0 € |
| Signatur (minisign/GPG) | 0 € |
| **Summe** | **0 €/Monat** |

Der einzige „Preis" ist die eigene Arbeit: Feed-Skript, Client, CI und die
sorgfältige Schlüsselverwaltung.

---

## 13. Quellen

- GitHub Releases: <https://docs.github.com/repositories/releasing-projects-on-github>
- GitHub Actions (public, kostenlos): <https://docs.github.com/billing>
- Cloudflare R2 Preise: <https://developers.cloudflare.com/r2/pricing/>
- minisign: <https://jedisct1.github.io/minisign/>
- zstd `--patch-from`: <https://github.com/facebook/zstd>
- casync/desync: <https://github.com/systemd/casync>, <https://github.com/folbricht/desync>
- Debian-Repository-Format: <https://wiki.debian.org/DebianRepository/Format>
