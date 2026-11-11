# Zugriff auf GitHub und SourceForge (für mich und für dich)

Stand: 2026-11-10 · Umgebung: WSL/Debian, Arbeitsverzeichnis
`/home/kirara/ElvonOS` · Ziel: klar dokumentieren, **was ich hier automatisch
kann**, **was du einmalig einrichten musst** und **mit welchen Befehlen**
Release-Dateien zu GitHub und SourceForge kommen.

---

## 1. Ist-Zustand dieser Umgebung (gemessen, 2026-11-10)

| Prüfung | Ergebnis |
|---|---|
| `git` | ✅ `/usr/bin/git` (2.47.3) |
| `gh` (GitHub CLI) | ✅ **installiert** (2.46.0) |
| `curl` / `wget` | ✅ vorhanden |
| `ssh` / `sftp` / `rsync` / `ssh-keygen` | ✅ vorhanden |
| GitHub erreichbar | ✅ `https://github.com` → 200 |
| GitHub-API erreichbar | ✅ `https://api.github.com` → 200 |
| GitHub-Anmeldung | ✅ Account **`ElvonOS`** (neuer Token, 5.000/h) |
| API-Rate-Limit | 5.000 Anfragen/Stunde |
| Repositories | `ElvonOS/elvonos-updates` **angelegt** (public, `main`), erste Inhalte lokal bereit |
| Push-Recht | ✅ SSH funktioniert; Feed-Layout ist auf GitHub gepusht |
| Codeberg | ✅ SSH als `ElvonOS` authentifiziert · ⏳ Repo `ElvonOS/elvonos-updates` fehlt noch |
| SourceForge | ✅ Projekt `elvonos` erreichbar, SFTP-Upload funktioniert – ISO-Upload läuft |
| SourceForge erreichbar | ✅ `https://sourceforge.net` → 200 |
| SSH-Keys vorhanden | ❌ `~/.ssh` enthält nur `known_hosts` |
| Git-Remote im ElvonOS-Repo | ❌ keins gesetzt (kein Git-Repo im Workspace) |

**Token-Ablage:** `~/.config/elvonos/github-token` (Datei `0600`, Ordner
`0700`). Der dort liegende Token ist **nicht mehr gültig** (HTTP 401 nach der
Rotation) — bitte entweder einen neuen Token in die Datei legen oder den
SSH-Weg nutzen (empfohlen, siehe 2.4 und 4.2).

```sh
export GH_TOKEN="$(cat ~/.config/elvonos/github-token)"
gh auth status
```

> **Sicherheit:** Der Token wurde im Chat übermittelt und gilt damit als
> potenziell exponiert. Nach dem Einrichten **rotieren**:
> GitHub → Settings → Developer settings → Fine-grained tokens →
> „Regenerate“ bzw. alten Token widerrufen.

**Fazit:**

- **Lesen** von GitHub/SourceForge funktioniert sofort anonym (git clone,
  raw-Dateien, Webseiten, REST-API).
- **Schreiben/Veröffentlichen** (Releases, Pushes, Uploads) ist für GitHub
  jetzt eingerichtet; SourceForge braucht noch deinen Account + SSH-Key.
- **Passwörter** werden nirgends gespeichert und sind für Skripte ohnehin
  nicht nutzbar (2FA).

---

## 2. GitHub-Zugriff

### 2.1 Anonym (jetzt schon möglich)

```sh
# Repository lesen
git clone https://github.com/wayvr-org/wayvr.git

# Einzelne Datei lesen
curl -fsSL https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json

# API (60 Anfragen/Stunde ohne Token)
curl -fsSL https://api.github.com/repos/wayvr-org/wayvr/releases/latest | jq .tag_name

# Release-Assets auflisten
curl -fsSL https://api.github.com/repos/wayvr-org/wayvr/releases/latest \
  | jq -r '.assets[].browser_download_url'
```

Grenzen: 60 API-Aufrufe/Stunde, kein Push, kein Release-Upload.

### 2.2 `gh` installieren (einmalig)

```sh
# Debian-Repo (empfohlen)
(type -p wget >/dev/null || sudo apt-get install -y wget) \
&& sudo mkdir -p -m 755 /etc/apt/keyrings \
&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
   | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
   | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
&& sudo apt-get update && sudo apt-get install -y gh
```

Prüfen:

```sh
gh --version    # gh version 2.x
```

### 2.3 Anmelden (einmalig, interaktiv)

```sh
gh auth login
# → GitHub.com
# → HTTPS
# → "Login with a web browser"
# → Code auf github.com/login/device eingeben
```

Status:

```sh
gh auth status
# ✓ Logged in to github.com as <user> (oauth_token)
# ✓ Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

**Für Skripte/Agenten** (ohne Browser) geht es mit einem **Personal Access
Token (PAT)**:

1. GitHub → Settings → Developer settings → Personal access tokens →
   **Fine-grained tokens** → „Generate new token“.
2. Repository access: nur die nötigen Repos.
3. Permissions: **Contents: Read and write** (Releases/Dateien),
   **Metadata: Read**, ggf. **Workflows: Write**.
4. Token kopieren und **nur lokal** setzen:

```sh
export GH_TOKEN=github_pat_...
gh auth status
```

> Ich kann `GH_TOKEN` aus der Umgebung nutzen, wenn du ihn setzt. Der Token
> darf **nicht** in Dateien, Commits oder Logs landen.

### 2.4 SSH statt HTTPS (für Pushes)

```sh
ssh-keygen -t ed25519 -C "elvonos@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
gh ssh-key add ~/.ssh/id_ed25519.pub --title "ElvonOS build machine"
ssh -T git@github.com     # → "Hi <user>! You've successfully authenticated"
```

Dann Remote umstellen:

```sh
git remote set-url origin git@github.com:ElvonOS/elvonos-os.git
```

### 2.5 Veröffentlichen

```sh
# Release anlegen (Assets werden angehängt)
gh release create v1.0.1 \
  build/out/ElvonOS-1.0.1-amd64.iso \
  build/out/ElvonOS-1.0.1-amd64.iso.minisig \
  --repo ElvonOS/elvonos-os \
  --title "ElvonOS 1.0.1" --notes "Release notes"

# Weitere Dateien ergänzen
gh release upload v1.0.1 build/out/*.zstpatch --repo ElvonOS/elvonos-os

# Releases anzeigen
gh release list --repo ElvonOS/elvonos-os
gh release view v1.0.1 --repo ElvonOS/elvonos-os
```

API-Rate-Limit mit Token: **5.000 Anfragen/Stunde** statt 60.

### 2.6 Was ich (der Agent) kann

| Aufgabe | ohne Token | mit `GH_TOKEN` (aktuell eingerichtet) |
|---|---|---|
| Repos/Releases lesen | ✅ | ✅ |
| Dateien herunterladen | ✅ | ✅ |
| Repo klonen | ✅ | ✅ |
| Push | ❌ | ✅ (wenn Inhalt: Schreiben erlaubt) |
| Release erstellen/Upload | ❌ | ✅ (Contents: Read and write) |
| Actions anstoßen | ❌ | ✅ (Workflows: Write) |
| Repo anlegen | ❌ | nur mit passender Fine-grained-Berechtigung |

Der Token liegt in `~/.config/elvonos/github-token`; `gh` nutzt ihn über
`GH_TOKEN`. In dieser Sitzung ist `gh` bereits angemeldet (Account
`ElvonOS`).

---

## 3. SourceForge-Zugriff

SourceForge hat **keine** `gh`-ähnliche CLI. Dateien kommen per
**SFTP/rsync** auf den File-Release-Server `frs.sourceforge.net`.

### 3.1 Voraussetzungen (einmalig)

1. Account auf <https://sourceforge.net/account/registration/>.
2. Projekt anlegen: <https://sourceforge.net/create/> (Name z. B. `elvonos`).
3. **SSH-Key hinterlegen**: Account → „SSH Settings“ → Public Key aus
   `~/.ssh/id_ed25519.pub` einfügen (oder neuen Key erzeugen).
4. Warten, bis der Key aktiv ist (meist sofort, manchmal Minuten).

Test:

```sh
ssh -T <user>@shell.sourceforge.net create
# oder direkt:
sftp <user>@frs.sourceforge.net
```

### 3.2 Dateien hochladen (SFTP)

```sh
sftp <user>@frs.sourceforge.net <<'EOF'
cd /home/frs/project/elvonos/releases/1.0.1
put build/out/ElvonOS-1.0.1-amd64.iso
put build/out/ElvonOS-1.0.1-amd64.iso.minisig
put build/out/SHA256SUMS
bye
EOF
```

Verzeichnisse vorher anlegen (im SFTP):

```sh
sftp <user>@frs.sourceforge.net <<'EOF'
mkdir /home/frs/project/elvonos/releases
mkdir /home/frs/project/elvonos/releases/1.0.1
bye
EOF
```

### 3.3 Alternativ: rsync (schneller, wiederaufnehmbar)

```sh
rsync -avP --progress \
  build/out/ElvonOS-1.0.1-amd64.iso \
  build/out/ElvonOS-1.0.1-amd64.iso.minisig \
  build/out/SHA256SUMS \
  <user>@frs.sourceforge.net:/home/frs/project/elvonos/releases/1.0.1/
```

> `rsync` ist auf `frs.sourceforge.net` verfügbar; bei großen Dateien
> unbedingt `-P` (Fortschritt + Resume) nutzen.

### 3.4 Prüfen

```sh
# Webseite der Dateien
curl -sI https://sourceforge.net/projects/elvonos/files/releases/1.0.1/

# Projekt-Metadaten (REST, öffentlich)
curl -fsSL https://sourceforge.net/rest/p/elvonos | jq .name
```

Download-URL für Nutzer:

```
https://sourceforge.net/projects/elvonos/files/releases/1.0.1/ElvonOS-1.0.1-amd64.iso/download
```

**Aktueller Stand (2026-11-10):**

- Projektname (UNIX): **`elvonos`**, Anzeigename „ElvonOS“
- SFTP-Login als `elvonos` ✅
- `/home/frs/project/elvonos/releases/1.0.0/` mit ISO, `SHA256SUMS`,
  `SHA256SUMS.minisig`, `ElvonOS-1.0.0-amd64.iso.minisig` ✅
- Direkt-Download:
  `https://downloads.sourceforge.net/project/elvonos/releases/1.0.0/ElvonOS-1.0.0-amd64.iso`

**Automatisierter Upload (neu):**

```sh
# signiert ISO + SHA256SUMS, lädt alles hoch und aktualisiert den Feed
bash build/update/publish-sourceforge.sh 1.0.0
```

Das Skript nutzt `rsync -P` (wiederaufnehmbar), legt das Release-Verzeichnis
an, signiert mit `~/.config/elvonos/keys/elvonos.key` und schreibt
`feeds/stable.json` mit der SourceForge-Download-URL (danach Commit/Push ins
Feed-Repo).

### 3.5 Shell-/Web-Hosting (optional)

SourceForge bietet klassisches Webhosting und eine SSH-Shell:

```sh
ssh -t <user>@shell.sourceforge.net create
```

Damit ließen sich z. B. der Update-Feed (`stable.json`) oder Spiegel
hosten. Für ElvonOS reicht aber GitHub; SourceForge dient als Mirror.

### 3.6 Was ich kann

| Aufgabe | möglich |
|---|---|
| Projektseite/Dateien lesen | ✅ anonym |
| REST-Metadaten lesen | ✅ anonym |
| Upload per SFTP/rsync | ❌ ohne deinen Account + SSH-Key |
| Shell-Zugang | ❌ ohne deinen Account |

---

## 4. Codeberg-Zugriff

Codeberg ist eine gemeinnützige Forgejo-Instanz (EU, DSGVO) und für ElvonOS
der **kostenlose EU-Mirror** (Feed, optional Quellcode, Releases).

### 4.1 Was ich von Codeberg brauche

| Angabe | Wofür | Pflicht? |
|---|---|---|
| **Codeberg-Benutzername** | Remote-URL, API, Mirror-Ziel | ✅ |
| **Repo-Name(n)** | z. B. `elvonos-updates` (Feed), optional `elvonos-os` | ✅ |
| **SSH-Key im Konto** | Push über `git@codeberg.org` | ✅ (oder Token) |
| **Access-Token** (`write:repository`) | Releases/Assets per API | nur für Release-Mirror |
| Entscheidung | nur Feed oder auch Quellcode spiegeln | ✅ |

### 4.2 SSH-Key (empfohlen, schon erzeugt)

Auf dem Build-Rechner liegt jetzt:

```
~/.ssh/id_ed25519_elvonos       (privat, 0600)
~/.ssh/id_ed25519_elvonos.pub   (öffentlich)
```

Öffentlicher Key — **bei GitHub und Codeberg eintragen**:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYydudW4mNdL/fhJdiP8sH8KyPJqij0Hv8U1g2L3AQg elvonos@build
```

- GitHub: <https://github.com/settings/ssh/new>
- Codeberg: <https://codeberg.org/user/settings/keys> → „Add Key“
  (Key-Type: SSH, Inhalt einfügen)

Test nach dem Eintragen:

```sh
ssh -T git@codeberg.org
# → "Hi <user>! You've successfully authenticated..."
ssh -T git@github.com
# → "Hi <user>! You've successfully authenticated..."
```

### 4.3 Codeberg-Repo anlegen

Per Web-UI: „New Repository“, Name `elvonos-updates`, **public**, ohne
Initialisierung.

Oder per API (Token mit `write:repository`):

```sh
CB_USER=<name>
CB_TOKEN=<token>
curl -fsS -X POST \
  -H "Authorization: token $CB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"elvonos-updates","private":false,"auto_init":false}' \
  https://codeberg.org/api/v1/user/repos
```

### 4.4 Repository spiegeln

```sh
CB_USER=<name> bash build/update/mirror-codeberg.sh /tmp/elvonos-updates
# push --mirror nach git@codeberg.org:<name>/elvonos-updates.git
```

Für den Quellcode (optional):

```sh
CB_USER=<name> CB_REPO=elvonos-os \
  bash build/update/mirror-codeberg.sh /pfad/zum/elvonos-repo
```

### 4.5 Releases/Assets auf Codeberg (optional)

```sh
CB_USER=<name> CB_TOKEN=<token> \
  bash build/update/publish-codeberg-release.sh 1.0.1 \
    build/out/ElvonOS-1.0.1-amd64.iso \
    build/out/ElvonOS-1.0.1-amd64.iso.minisig
```

Token-Scope: **write:repository**. Token nur als Umgebungsvariable
übergeben (`CB_TOKEN=…`), nie in Dateien oder Commits.

### 4.6 Aktueller Stand

- ✅ SSH-Key bei Codeberg hinterlegt (`ssh -T git@codeberg.org` → `Hi there, ElvonOS!`)
- ⏳ Repo `ElvonOS/elvonos-updates` existiert noch nicht (Forgejo: „Cannot find repository“)
- Danach: `CB_USER=ElvonOS bash build/update/mirror-codeberg.sh /tmp/elvonos-updates`
- Prüfen: `https://codeberg.org/ElvonOS/elvonos-updates`

---

## 5. Konkrete Veröffentlichungs-Rezepte für ElvonOS

### 4.1 GitHub (primär)

```sh
# 1. Signieren
minisign -Sm build/out/ElvonOS-1.0.1-amd64.iso \
  -s ~/.config/elvonos/keys/elvonos.key -t "ElvonOS 1.0.1"
sha256sum build/out/ElvonOS-1.0.1-amd64.iso > build/out/SHA256SUMS

# 2. Release
gh release create v1.0.1 \
  build/out/ElvonOS-1.0.1-amd64.iso \
  build/out/ElvonOS-1.0.1-amd64.iso.minisig \
  build/out/SHA256SUMS \
  --repo ElvonOS/elvonos-os \
  --title "ElvonOS 1.0.1" --notes "Kernel 6.12.116-elvonos, Waydroid, Metro, Terminal"
```

### 4.2 SourceForge (Mirror)

```sh
rsync -avP build/out/ElvonOS-1.0.1-amd64.iso \
           build/out/ElvonOS-1.0.1-amd64.iso.minisig \
           build/out/SHA256SUMS \
  <user>@frs.sourceforge.net:/home/frs/project/elvonos/releases/1.0.1/
```

### 4.3 Ein Skript für beide (Vorschlag)

**Datei:** `build/update/publish-both.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
VERSION="${1:?Usage: publish-both.sh VERSION}"
GH_REPO="${GH_REPO:-ElvonOS/elvonos-os}"
SF_USER="${SF_USER:?SF_USER fehlt}"
SF_PROJECT="${SF_PROJECT:-elvonos}"
ISO="build/out/ElvonOS-${VERSION}-amd64.iso"

gh release create "v$VERSION" \
    "$ISO" "$ISO.minisig" build/out/SHA256SUMS \
    --repo "$GH_REPO" \
    --title "ElvonOS $VERSION" --notes "ElvonOS $VERSION"

ssh "${SF_USER}@frs.sourceforge.net" \
    "mkdir -p /home/frs/project/${SF_PROJECT}/releases/${VERSION}" || true
rsync -avP "$ISO" "$ISO.minisig" build/out/SHA256SUMS \
    "${SF_USER}@frs.sourceforge.net:/home/frs/project/${SF_PROJECT}/releases/${VERSION}/"
```

---

## 6. Sicherheit

| Regel | Warum |
|---|---|
| Token nie committen | `GH_TOKEN` nur als Umgebungsvariable |
| Fine-grained PAT | nur `Contents: write`, nur die nötigen Repos |
| SSH-Key mit Passphrase | Schutz bei Laptop-Verlust |
| `~/.ssh` Rechte 700, Keys 600 | sonst verweigert ssh die Nutzung |
| SourceForge-Key nur für SFTP | kein Shell-Zugang nötig |
| Tokens widerrufen | GitHub → Settings → Tokens; SF → SSH Settings |
| Signaturen prüfen | `minisign -V` + `sha256sum -c` vor Veröffentlichung |

---

## 7. Fehlerbehebung

| Meldung | Ursache | Lösung |
|---|---|---|
| `gh: command not found` | CLI fehlt | Abschnitt 2.2 |
| `gh: To get started with GitHub CLI, please run: gh auth login` | nicht angemeldet | `gh auth login` oder `GH_TOKEN` |
| `HTTP 403: rate limit exceeded` | anonymes Limit (60/h) | Token setzen (5.000/h) |
| `Permission to … denied` (git push) | Fine-grained Token gilt nur für ausgewählte Repos | Token → Repository access → „All repositories“ oder neues Repo hinzufügen, Contents: Read and write |
| `403` beim Push auf ein **neu angelegtes** Repo | Repo war bei Token-Erstellung noch nicht ausgewählt | Token bearbeiten (s. o.), dann erneut pushen |
| `Permission denied (publickey)` (SFTP) | Key nicht hinterlegt/aktiv | SF → Account → SSH Settings |
| `Host key verification failed` | neuer Host | `ssh-keyscan frs.sourceforge.net >> ~/.ssh/known_hosts` |
| `rsync: command not found` auf SF | Server ohne rsync | `sftp` verwenden |
| Upload bricht ab | große Datei/Timeout | `rsync -P` oder `sftp -o ServerAliveInterval=30` |
| `fatal: not a git repository` | ElvonOS-Ordner ist kein Repo | `git init` + Remote setzen |

---

## 8. Checkliste „einmalig einrichten“

- [x] GitHub-Konto + Token (`ElvonOS`, in `~/.config/elvonos/github-token`)
- [x] `gh` installiert und über `GH_TOKEN` angemeldet
- [x] Repo `ElvonOS/elvonos-updates` angelegt
- [ ] Token-Berechtigung: Repository access = „All repositories“ oder `elvonos-updates` hinzufügen, **Contents: Read and write**
- [ ] Ersten Feed-Commit pushen (liegt vorbereitet in `/tmp/elvonos-updates`)
- [ ] Token nach dem Einrichten rotieren
- [ ] SourceForge-Konto + Projekt `elvonos`
- [ ] SSH-Key bei GitHub **und** SourceForge hinterlegen
- [ ] Test: `ssh -T git@github.com` und `sftp <user>@frs.sourceforge.net`
- [ ] Test-Release mit `gh release create` und `rsync` auf SF
- [ ] Tokens/Keys im Passwortmanager sichern

Danach gilt: **GitHub = primärer Kanal**, **SourceForge = kostenloser
Mirror**, beide ohne laufende Kosten.
