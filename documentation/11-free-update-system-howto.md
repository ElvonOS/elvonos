# ElvonOS Update-System: die komplette Schritt-für-Schritt-Anleitung

Diese Anleitung beschreibt **jeden einzelnen Schritt**, den du machen musst,
damit ElvonOS Updates kostenlos baut, signiert, veröffentlicht und installiert.
Alles läuft mit freien Werkzeugen und ohne Serverkosten.

> Begriffe: `elvonos` = dein GitHub-Benutzername, `elvonos-os` = Haupt-Repo
> (Code/ISO-Build), `elvonos-updates` = neues öffentliches Repo für Feed und
> Paket-Metadaten.

---

## 0. Entscheidungen vorab (5 Minuten)

| Frage | Empfehlung |
|---|---|
| Wohin mit den Release-Dateien? | **GitHub Releases** im Repo `elvonos-os` |
| Wohin mit dem Update-Feed? | **eigenes Repo `elvonos-updates`**, Datei `stable.json` |
| Signatur-Verfahren? | **minisign** (einfach) |
| Wer signiert? | **du lokal** (privater Schlüssel bleibt auf deinem PC) |
| APT-Repo nötig? | erst später, wenn du eigene `.deb`s ausliefern willst |
| Kanäle? | `stable` (Pflicht), `beta` (optional) |

**Wichtig:** Der private Signaturschlüssel darf **niemals** in ein Repository
oder in GitHub Secrets, solange du ihn lokal brauchst. Diese Anleitung hält
ihn auf deinem Rechner.

---

## 1. Voraussetzungen installieren

Auf deinem Build-Rechner (WSL/Debian, dort wo `/home/kirara/ElvonOS` liegt):

```sh
sudo apt-get update
sudo apt-get install -y minisign curl jq gh gnupg apt-utils xz-utils zstd
```

Prüfen:

```sh
minisign -v          # minisign 0.11
gh --version         # gh version 2.x
jq --version
```

GitHub-Konto anmelden (einmalig):

```sh
gh auth login
# → GitHub.com, HTTPS, "Login with a web browser", Code bestätigen
gh auth status
```

**Erwartete Ausgabe:** `Logged in to github.com as elvonos`.

---

## 2. Signaturschlüssel erzeugen und sicher aufbewahren

> Einmalig. Den privaten Schlüssel nie verlieren und nie veröffentlichen.

```sh
mkdir -p ~/.config/elvonos/keys
cd ~/.config/elvonos/keys

minisign -G -p elvonos.pub -s elvonos.key \
  -c "ElvonOS update signing key (2026)"
```

Du wirst nach einem Passwort gefragt — **nimm ein starkes** und speichere es
im Passwortmanager.

**Ergebnis:**

```
~/.config/elvonos/keys/elvonos.pub   # öffentlich, kommt ins ISO
~/.config/elvonos/keys/elvonos.key   # privat, NIE teilen
```

Backup anlegen (USB-Stick, verschlüsselt):

```sh
cp elvonos.key elvonos.pub /media/<usb>/elvonos-keys/
```

Rechte einschränken:

```sh
chmod 600 ~/.config/elvonos/keys/elvonos.key
```

Test-Signatur:

```sh
echo "test" > /tmp/test.txt
minisign -Sm /tmp/test.txt -s ~/.config/elvonos/keys/elvonos.key
minisign -Vm /tmp/test.txt -p ~/.config/elvonos/keys/elvonos.pub
```

**Erwartete Ausgabe:** `Signature and comment signature verified`.

> **Ist-Stand (2026-11-10):** Das Schlüsselpaar wurde beim Build automatisch
> mit `-W` (ohne Passwort) erzeugt, damit `build-iso.sh` und
> `publish-sourceforge.sh` unbeaufsichtigt signieren können.
> Public Key: `RWS/qURuN49P6KiggSTz8FJLVushtqbyI/32lPvZgJzPklLsEu7oEgPk`
> (Kommentar `E84F8F376E44A9BF`).
>
> Vor einer breiten Verteilung sollte ein passwortgeschütztes Paar erzeugt,
> der Public Key per ISO-Update verteilt und der alte Schlüssel rotiert
> werden (Abschnitt 13). Der private Schlüssel liegt ausschließlich in
> `~/.config/elvonos/keys/elvonos.key` (0600) – bitte verschlüsselt sichern.

---

## 3. Öffentlichen Schlüssel ins ISO einbauen

Der Client muss dem Feed vertrauen können, also liegt der Public Key im
System.

```sh
sudo install -Dm644 ~/.config/elvonos/keys/elvonos.pub \
  /home/kirara/ElvonOS/build/out/rootfs/usr/share/elvonos/update/elvonos.pub
```

Damit das bei jedem Build automatisch passiert, lege ein kleines Skript an:

**Datei:** `build/update/install-update-key.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOTFS="${1:-$(cd "$(dirname "$0")/../.." && pwd)/build/out/rootfs}"
KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}"
[ -f "$KEY" ] || { echo "Public key not found: $KEY" >&2; exit 1; }
sudo install -Dm644 "$KEY" "$ROOTFS/usr/share/elvonos/update/elvonos.pub"
echo "installed update key into $ROOTFS"
```

Ausführbar machen und in den ISO-Build einhängen:

```sh
chmod +x build/update/install-update-key.sh
```

In `build/phase7/build-iso.sh` **vor** dem SquashFS-Schritt ergänzen:

```bash
# Update-Trust-Anchor
if [ -x "$REPO_ROOT/build/update/install-update-key.sh" ]; then
    ELVONOS_UPDATE_KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}" \
        bash "$REPO_ROOT/build/update/install-update-key.sh" "$ROOTFS" || true
fi
```

Ebenso die Version ins System schreiben (für den Vergleich):

```bash
printf 'VERSION=%s\n' "${ELVONOS_VERSION:-1.0.0}" | \
    sudo tee "$ROOTFS/etc/elvonos-release" >/dev/null
```

Prüfen nach dem Build:

```sh
ls -l build/out/rootfs/usr/share/elvonos/update/elvonos.pub
cat build/out/rootfs/etc/elvonos-release
```

---

## 4. Update-Repository auf GitHub anlegen

```sh
gh repo create elvonos-updates --public \
  --description "ElvonOS update feed and metadata" \
  --add-readme
cd /tmp
git clone https://github.com/ElvonOS/elvonos-updates.git
cd elvonos-updates
mkdir -p feeds
```

Struktur, die am Ende so aussieht:

```
elvonos-updates/
├── feeds/
│   ├── stable.json
│   └── stable.json.minisig
└── README.md
```

Die Feed-URL, die der Client später nutzt:

```
https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json
https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json.minisig
```

---

## 5. Veröffentlichungs-Skript schreiben

Dieses Skript baust du **einmal** und nutzt es bei jedem Release.

**Datei:** `build/update/publish-feed.sh`

```bash
#!/usr/bin/env bash
# Erzeugt feeds/stable.json (+ Signatur) aus einem Release.
# Aufruf: publish-feed.sh <version> <iso> <size> <sha256> <iso-url> [delta-url delta-sha]
set -euo pipefail

VERSION="$1"
ISO="$2"
SIZE="$3"
SHA256="$4"
ISO_URL="$5"
DELTA_URL="${6:-}"
DELTA_SHA="${7:-}"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"
KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.key}"
FEED="$FEED_REPO/feeds/stable.json"

python3 - "$FEED" "$VERSION" "$SIZE" "$SHA256" "$ISO_URL" "$DELTA_URL" "$DELTA_SHA" <<'PY'
import json, sys, datetime
feed, version, size, sha, url, durl, dsha = sys.argv[1:8]
data = {
    "channel": "stable",
    "version": version,
    "released": datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "min_supported": "1.0.0",
    "iso": {
        "url": url,
        "size": int(size),
        "sha256": sha,
        "signature": url + ".minisig",
    },
}
if durl:
    data["delta"] = {
        "from": open("/tmp/elvonos-last-version").read().strip()
                if __import__("os").path.exists("/tmp/elvonos-last-version") else "1.0.0",
        "url": durl,
        "sha256": dsha,
        "signature": durl + ".minisig",
    }
open(feed, "w").write(json.dumps(data, indent=2) + "\n")
print(feed)
PY

minisign -Sm "$FEED" -s "$KEY" -t "ElvonOS feed $VERSION"

cd "$FEED_REPO"
git add feeds
git commit -m "feed: ElvonOS $VERSION"
git push origin main
```

Ausführbar machen:

```sh
chmod +x build/update/publish-feed.sh
```

---

## 6. Release-Skript schreiben (build → sign → publish)

**Datei:** `build/update/release.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:?Usage: release.sh VERSION}"
ISO="$REPO_ROOT/build/out/ElvonOS-$VERSION-amd64.iso"
OLD_ISO="$REPO_ROOT/build/out/ElvonOS-$(cat /tmp/elvonos-last-version 2>/dev/null || echo 1.0.0)-amd64.iso"
KEY="$HOME/.config/elvonos/keys/elvonos.key"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"

echo "==> Baue ISO $VERSION"
ELVONOS_VERSION="$VERSION" REBUILD_SQUASHFS=1 \
    bash "$REPO_ROOT/build/phase7/build-iso.sh"

echo "==> Prüfsumme und Signatur"
SHA256=$(sha256sum "$ISO" | cut -d' ' -f1)
SIZE=$(stat -c %s "$ISO")
minisign -Sm "$ISO" -s "$KEY" -t "ElvonOS $VERSION"

echo "==> Delta-Patch (optional)"
DELTA="" DELTA_SHA=""
if [ -f "$OLD_ISO" ]; then
    DELTA="$REPO_ROOT/build/out/ElvonOS-$(basename "$OLD_ISO" | sed 's/ElvonOS-//;s/-amd64.iso//')_to_$VERSION.iso.zstpatch"
    zstd --patch-from="$OLD_ISO" "$ISO" -o "$DELTA"
    DELTA_SHA=$(sha256sum "$DELTA" | cut -d' ' -f1)
    minisign -Sm "$DELTA" -s "$KEY" -t "ElvonOS $VERSION delta"
fi

echo "==> GitHub Release"
FILES=("$ISO" "$ISO.minisig")
if [ -n "$DELTA" ]; then
    FILES+=("$DELTA" "$DELTA.minisig")
fi
gh release create "v$VERSION" "${FILES[@]}" \
    --repo ElvonOS/elvonos-os \
    --title "ElvonOS $VERSION" \
    --notes "ElvonOS $VERSION – Kernel, Desktop, Waydroid."

ISO_URL="https://github.com/ElvonOS/elvonos-os/releases/download/v$VERSION/$(basename "$ISO")"
DELTA_URL=""
[ -n "$DELTA" ] && DELTA_URL="https://github.com/ElvonOS/elvonos-os/releases/download/v$VERSION/$(basename "$DELTA")"

echo "==> Feed veröffentlichen"
"$REPO_ROOT/build/update/publish-feed.sh" \
    "$VERSION" "$ISO" "$SIZE" "$SHA256" "$ISO_URL" \
    "$DELTA_URL" "$DELTA_SHA"

echo "$VERSION" > /tmp/elvonos-last-version

echo "==> Fertig"
echo "ISO:    $ISO"
echo "SHA256: $SHA256"
```

```sh
chmod +x build/update/release.sh
```

> `gh` muss im Haupt-Repo als Remote `origin` haben bzw. `--repo
> ElvonOS/elvonos-os` erlaubt Releases auch ohne lokalen Remote.

---

## 7. Minimalen Client installieren (sofort nutzbar, ohne Rust)

**Datei:** `base/configuration/scripts/elvonos-update` (Bash-Referenzclient)

```bash
#!/usr/bin/env bash
# ElvonOS Update-Client (Referenzimplementierung, Bash)
set -euo pipefail

CONF=${ELVONOS_UPDATE_CONF:-/etc/elvonos/update.conf}
[ -f "$CONF" ] && . "$CONF"

FEED_URL="${FEED_URL:-https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json}"
PUBKEY="${PUBKEY:-/usr/share/elvonos/update/elvonos.pub}"
CURRENT="${CURRENT:-$(sed -n 's/^VERSION=//p' /etc/elvonos-release 2>/dev/null || echo 0)}"
CACHE="${CACHE:-/var/cache/elvonos/update}"

need() { command -v "$1" >/dev/null || { echo "missing: $1" >&2; exit 1; }; }
need curl; need minisign; need jq

fetch_feed() {
    mkdir -p "$CACHE"
    curl -fsSL "$FEED_URL" -o "$CACHE/stable.json"
    curl -fsSL "$FEED_URL.minisig" -o "$CACHE/stable.json.minisig"
    minisign -Vm "$CACHE/stable.json" -p "$PUBKEY" >/dev/null || {
        echo "Feed-Signatur ungültig" >&2; exit 1; }
}

cmd_check() {
    fetch_feed
    local version; version=$(jq -r .version "$CACHE/stable.json")
    if [ "$version" = "$CURRENT" ]; then
        echo "{\"current\":\"$CURRENT\",\"latest\":\"$version\",\"update\":false}"
    else
        echo "{\"current\":\"$CURRENT\",\"latest\":\"$version\",\"update\":true}"
    fi
}

cmd_download() {
    fetch_feed
    local url sha out
    url=$(jq -r .iso.url "$CACHE/stable.json")
    sha=$(jq -r .iso.sha256 "$CACHE/stable.json")
    out="$CACHE/$(basename "$url")"
    curl -fL --continue-at - "$url" -o "$out.part"
    echo "$sha  $out.part" | sha256sum -c - >/dev/null
    curl -fL "$url.minisig" -o "$out.minisig"
    minisign -Vm "$out.part" -p "$PUBKEY" >/dev/null
    mv "$out.part" "$out"
    echo "$out"
}

cmd_apply() {
    # Installiertes System: Paket-Update
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get -y upgrade
        return
    fi
    echo "Live-System: ISO mit 'elvonos-update download' holen und auf USB schreiben."
}

case "${1:-check}" in
    check)    cmd_check ;;
    download) cmd_download ;;
    apply)    cmd_apply ;;
    *) echo "Usage: elvonos-update check|download|apply" >&2; exit 2 ;;
esac
```

Installieren:

```sh
chmod +x base/configuration/scripts/elvonos-update
sudo install -Dm755 base/configuration/scripts/elvonos-update \
  build/out/rootfs/usr/bin/elvonos-update
```

Konfiguration anlegen:

**Datei:** `base/configuration/update/update.conf`

```ini
FEED_URL=https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json
PUBKEY=/usr/share/elvonos/update/elvonos.pub
CACHE=/var/cache/elvonos/update
```

```sh
sudo install -Dm644 base/configuration/update/update.conf \
  build/out/rootfs/etc/elvonos/update.conf
```

---

## 8. GitHub-Actions-Workflow (optional, für Automatik)

Wenn du auf jedem Tag automatisch bauen willst, lege an:

**Datei:** `.github/workflows/release.yml`

```yaml
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential cmake ninja-build \
            qt6-base-dev qt6-declarative-dev qt6-quickcontrols2-dev \
            minisign xorriso squashfs-tools
      - name: Build ISO
        run: sudo -E bash build/phase7/build-iso.sh
      - name: Sign
        env:
          MINISIGN_KEY: ${{ secrets.MINISIGN_KEY }}
        run: |
          printf '%s\n' "$MINISIGN_KEY" > /tmp/elvonos.key
          minisign -Sm build/out/ElvonOS-*-amd64.iso -s /tmp/elvonos.key
          sha256sum build/out/ElvonOS-*-amd64.iso > SHA256SUMS
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            build/out/ElvonOS-*.iso
            build/out/ElvonOS-*.iso.minisig
            SHA256SUMS
```

> Der komplette Kernel-Build dauert in CI sehr lange. Für den Anfang ist
> **Release lokal** (Schritt 6) schneller. CI lohnt sich erst, wenn du die
> ISO ohne Kernel-Neubau veröffentlichst.

Secret setzen (nur wenn du CI-Signatur willst):

```sh
gh secret set MINISIGN_KEY --repo ElvonOS/elvonos-os < ~/.config/elvonos/keys/elvonos.key
```

**Sicherheitshinweis:** Damit liegt der private Schlüssel bei GitHub. Wenn dir
das zu riskant ist, signiere weiter lokal (empfohlen).

---

## 9. GitHub-Einstellungen (Klickanleitung)

1. **Repo `elvonos-os` → Settings → General**
   - „Features“: **Releases** ist automatisch aktiv.
2. **Repo `elvonos-updates` → Settings → General**
   - Sichtbarkeit: **Public**.
3. **Optional: GitHub Pages für den Feed** (statt `raw.githubusercontent`)
   - `elvonos-updates` → Settings → Pages
   - Source: **Deploy from a branch**
   - Branch: **main**, Folder: **/ (root)**
   - Nach dem ersten Push ist der Feed unter
     `https://elvonos.github.io/elvonos-updates/feeds/stable.json`
4. **Actions** (nur bei CI-Nutzung)
   - Settings → Actions → General → „Allow all actions and reusable workflows“.
5. **Releases**
   - Nach `gh release create` erscheinen sie unter
     `https://github.com/ElvonOS/elvonos-os/releases`.

---

## 10. Erster Release – kompletter Durchlauf

### 10.1 Version setzen

```sh
cd /home/kirara/ElvonOS
echo 1.0.0 > /tmp/elvonos-last-version
```

### 10.2 Feed-Repo klonen

```sh
[ -d /tmp/elvonos-updates ] || \
  git clone https://github.com/ElvonOS/elvonos-updates.git /tmp/elvonos-updates
```

### 10.3 Release bauen und veröffentlichen

```sh
REPO_ROOT=/home/kirara/ElvonOS bash build/update/release.sh 1.0.1
```

**Was passiert:**

1. ISO wird gebaut → `build/out/ElvonOS-1.0.1-amd64.iso`
2. `sha256sum` + `minisign`
3. Delta von 1.0.0 → 1.0.1 (falls alte ISO vorhanden)
4. `gh release create v1.0.1 …`
5. `feeds/stable.json` + Signatur, Commit und Push

**Erwartete Ausgabe (Auszug):**

```
==> Baue ISO 1.0.1
 ElvonOS V1 ISO built successfully!
 Checksum: <sha256>  ElvonOS-1.0.1-amd64.iso
==> Prüfsumme und Signatur
==> GitHub Release
https://github.com/ElvonOS/elvonos-os/releases/tag/v1.0.1
==> Feed veröffentlichen
[main 1234abc] feed: ElvonOS 1.0.1
==> Fertig
```

### 10.4 Alles prüfen

```sh
# Feed erreichbar?
curl -fsSL https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json | jq .

# Signatur gültig?
curl -fsSL .../stable.json -o /tmp/stable.json
curl -fsSL .../stable.json.minisig -o /tmp/stable.json.minisig
minisign -Vm /tmp/stable.json -p ~/.config/elvonos/keys/elvonos.pub

# Release-Assets vorhanden?
gh release view v1.0.1 --repo ElvonOS/elvonos-os
```

**Erwartete Ausgabe:** JSON mit `"version": "1.0.1"`, Signatur „verified“,
Release listet ISO + `.minisig` + ggf. Delta.

---

## 11. Test im Live-ISO

ISO booten (z. B. mit `build/phase1/run-desktop-qemu-whpx.ps1`), dann:

```sh
elvonos-update check
```

**Erwartet (Beispiel):**

```json
{"current":"1.0.0","latest":"1.0.1","update":true}
```

Download testen:

```sh
sudo elvonos-update download
```

**Erwartet:** Datei unter `/var/cache/elvonos/update/ElvonOS-1.0.1-amd64.iso`,
`sha256sum -c` und `minisign -V` erfolgreich.

Auf einem installierten System:

```sh
sudo elvonos-update apply     # apt-get update && apt-get upgrade
```

---

## 12. Ablauf bei jedem weiteren Release (Kurzcheckliste)

- [ ] `echo <alte Version> > /tmp/elvonos-last-version`
- [ ] `bash build/update/release.sh <neue Version>`
- [ ] `elvonos-update check` im ISO testen
- [ ] `gh release view v<neu>` prüfen
- [ ] Feed-Signatur mit `minisign -V` prüfen

Mehr ist nicht nötig — kein Server, keine Kosten.

---

## 13. Schlüsselrotation (falls nötig)

1. Neues Schlüsselpaar erzeugen (`minisign -G -p neu.pub -s neu.key`).
2. Neuen Public Key zusätzlich ins ISO (`usr/share/elvonos/update/`).
3. `stable.json`-Feld `next_key` mit dem neuen Key ergänzen.
4. Ein Release mit beiden Keys signieren bzw. Client übergangsweise beide
   akzeptieren lassen.
5. Nach einem Übergangsrelease den alten Key entfernen.

Den alten privaten Schlüssel erst löschen, wenn kein unterstütztes System
mehr darauf angewiesen ist.

---

## 14. Fehlerbehebung

| Problem | Ursache | Lösung |
|---|---|---|
| `minisign: command not found` | Paket fehlt | `sudo apt-get install minisign` |
| `Feed-Signatur ungültig` | falscher/alter Pubkey | `elvonos.pub` im ISO und lokal vergleichen |
| `403` bei raw.githubusercontent | Repo privat | Repo auf public stellen |
| `gh release create` scheitert | nicht eingeloggt | `gh auth login`, `gh auth status` |
| `zstd: unknown option --patch-from` | zstd zu alt | `zstd` ≥ 1.5 installieren |
| Delta zu groß | viele Änderungen | volles ISO veröffentlichen, Delta weglassen |
| `apt-get upgrade` ohne Wirkung | keine eigenen Pakete im Repo | APT-Repo (Abschnitt 15) einrichten |
| GitHub-Pages-Feed 404 | Pages nicht aktiviert | Settings → Pages → main/root |

---

## 15. Optional: eigenes APT-Repo (wenn du `.deb`s ausliefern willst)

```sh
cd /home/kirara/ElvonOS

# Einmalig: GPG-Schlüssel für das APT-Repo erzeugen (falls noch nicht vorhanden)
gpg --full-generate-key          # RSA 4096, ohne Ablauf, Name/E-Mail eintragen
GPGKEY=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/{print $5; exit}')
echo "GPGKEY=$GPGKEY"            # notieren, z. B. in ~/.config/elvonos/keys/apt.env

sudo mkdir -p /home/kirara/ElvonOS/build/out/rootfs/usr/share/keyrings
gpg --export "$GPGKEY" | sudo tee \
  /home/kirara/ElvonOS/build/out/rootfs/usr/share/keyrings/elvonos.gpg >/dev/null

mkdir -p update-repo/pool/main
cp build/out/debs/*.deb update-repo/pool/main/ 2>/dev/null || true

cd update-repo
apt-ftparchive packages pool > Packages
gzip -kf Packages
apt-ftparchive release . > Release
gpg --default-key "$GPGKEY" --clearsign -o InRelease Release
gpg --default-key "$GPGKEY" -abs -o Release.gpg Release
```

Als Release-Asset bündeln:

```sh
tar --zstd -cf /tmp/elvonos-repo.tar.zst .
gh release upload "v<version>" /tmp/elvonos-repo.tar.zst --repo ElvonOS/elvonos-os
```

Auf dem Zielsystem:

```sh
sudo mkdir -p /var/lib/elvonos/repo
sudo tar --zstd -xf /tmp/elvonos-repo.tar.zst -C /var/lib/elvonos/repo
echo 'deb [signed-by=/usr/share/keyrings/elvonos.gpg] file:/var/lib/elvonos/repo stable main' \
  | sudo tee /etc/apt/sources.list.d/elvonos.list
sudo apt-get update
```

Public Key für APT (bereits oben exportiert; hier nur zur Kontrolle):

```sh
gpg --export "$GPGKEY" | sudo tee /usr/share/keyrings/elvonos.gpg >/dev/null
```

---

## 16. Was noch programmiert werden muss

Der Bash-Client aus Abschnitt 7 reicht zum Start. Für die volle Integration:

- [ ] `elvonos-update` als Rust-Binary (wie `elvonos-waydroid`) mit
      `check`, `download`, `apply`, `status --json`
- [ ] Einstellungen → Updates: „Nach Updates suchen“ ruft
      `elvonos-update check --json` auf, zeigt Version + Fortschritt
- [ ] `apply` für Live-Systeme: ISO herunterladen, prüfen, auf USB schreiben
      (oder `kexec`-Neustart in die neue Version)
- [ ] Delta-Patch automatisch wählen, wenn `from` zur laufenden Version passt
- [ ] Kanal `beta` (zweite Feed-Datei)

---

## 17. Zusammenfassung: was du konkret tun musst

1. `minisign`, `gh`, `jq` installieren und bei GitHub anmelden.
2. Schlüsselpaar erzeugen und **privat** sichern.
3. Public Key ins ISO einbauen (`build/update/install-update-key.sh`).
4. Repo `elvonos-updates` anlegen.
5. `build/update/publish-feed.sh` und `build/update/release.sh` anlegen.
6. `elvonos-update` + `/etc/elvonos/update.conf` ins ISO legen.
7. Erstes Release mit `release.sh 1.0.1` veröffentlichen.
8. Mit `elvonos-update check` und `minisign -V` prüfen.
9. Bei jedem weiteren Release nur noch Schritt 7 wiederholen.

**Kosten:** 0 €/Monat (GitHub Releases/Pages, freie Werkzeuge).
