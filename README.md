# Connector Scout skill

![Scout](assets/scout.png)

Researches a target application's API for a HelloID provisioning target connector and writes a feasibility report. Research only: it never writes connector code, and it doesn't check published connectors on GitHub (it only reads the three reference connectors). `SKILL.md` has the full instructions.

```
/connector-scout [<spec file or public docs URL>] [--target <name>] [--answers <file>]
```

With no arguments it uses the single spec in the current folder. The target name comes from the spec (OpenAPI `info.title`), unless you pass `--target`.

## Requirements

| What | Why | Install |
|---|---|---|
| PowerShell 7 (`pwsh`) | Runs every script in `scripts/` | `winget install Microsoft.PowerShell` |
| `powershell-yaml` module | YAML specs (`spec-digest.ps1`) | `pwsh -Command "Install-Module powershell-yaml -Scope CurrentUser"` |

Without `powershell-yaml`, YAML specs can't be digested.

A run also needs network access to `github.com` and `raw.githubusercontent.com`: it reads the three reference connectors (Caseware, Iprotect, Generic-Scim) from GitHub with WebFetch.

## Install

1. Get the skill from [GitHub](https://github.com/JeroenBL/connector-scout) into `~/.claude/skills/connector-scout/`:

   ```
   git clone https://github.com/JeroenBL/connector-scout "$HOME/.claude/skills/connector-scout"
   ```

   No git? Download the repo as a ZIP from GitHub and unzip it so that `SKILL.md` ends up directly in `~/.claude/skills/connector-scout/`, not in a subfolder.

   To update later, run `git pull` in that folder. See [CHANGELOG.md](CHANGELOG.md) for what changed.
2. Install the requirements above.
3. Add the permission rules below to `~/.claude/settings.json`, so a run needs no approvals, including a headless run (`claude -p "/connector-scout ..."`), where nobody can approve anything. Replace `<you>` with your user name, and keep the forward slashes in the rules.

   ```json
   "permissions": {
     "allow": [
       "PowerShell(pwsh -NoProfile -File C:/Users/<you>/.claude/skills/connector-scout/scripts/*)",
       "Edit(./reports/**)",
       "WebFetch(domain:github.com)",
       "WebFetch(domain:raw.githubusercontent.com)"
     ]
   }
   ```

   Merge these into what's already in the file; don't replace it.
   - The `PowerShell` rule covers every shell call scout makes: it runs shell commands only through its own scripts.
   - `Edit(./reports/**)` lets it write the report under `reports/` in the folder you start it from.
   - The two `WebFetch` rules let it read the reference connectors on GitHub. Add a `WebFetch(domain:...)` rule for the docs domain too, if you pass a docs URL in a headless run.

   **Optional rules**, only when they apply:

   | Rule | Add it when |
   |---|---|
   | `"Bash(pwsh -NoProfile -File C:/Users/<you>/.claude/skills/connector-scout/scripts/*)"` | Your session uses the Bash tool (Git Bash) instead of PowerShell |
   | `"PowerShell(& 'C:/Users/<you>/.claude/skills/connector-scout/scripts/*)"` | Your path contains spaces, so the call is quoted |
   | `"Skill(connector-scout)"` | You want Claude to start the skill itself when you ask in your own words, instead of typing `/connector-scout` |
   | `"additionalDirectories": ["C:\\Users\\<you>\\.claude\\skills\\connector-scout"]` | `blockReadsOutsideWorkingDirectories` is on, so it can read its own `references/` |

   `SKILL.md` also lists these as `allowed-tools`, plus `WebFetch` for public docs URLs. Whether those reach the forked subagent the skill runs in isn't documented, so the settings above are the reliable part. Start a new session after you change the settings.

Start a headless run from PowerShell or cmd, not from Git Bash: Git Bash rewrites `/connector-scout` into a Windows path before Claude sees it.

Some things always ask, whatever the rules say: questions scout asks you (which spec file, for example), and in a headless run those are skipped. Writes into `.claude/` folders also always ask.

## What a run writes (in the folder you start it from)

| File | What |
|---|---|
| `reports/<target>-feasibility.md` | The report |
| `reports/report-viewer.html` | The viewer, copied at the start of each run (see below) |
| `reports/history/<target>-feasibility-<date>.md` | The previous report, kept when a run replaces it |
| `reports/.scout/` | Long digest output, read during the run |

The report starts with YAML frontmatter that follows `references/report.schema.json`. Nothing checks it automatically, so read it back before you rely on it.

## The report viewer

`reports/report-viewer.html` is a single static page in the ConnectorX look: glass cards, glowing buttons, faint scanlines, and a start screen with a lit logo and lightning. It holds no report and needs no server. Double-click it to open it in your browser.

- **Load a report** with Open file…, by dropping `reports/<target>-feasibility.md` on the page, or with Paste. The file is read in your browser; nothing is uploaded.
- **Tabs:** Overview, Endpoints, Open questions, Full report and Header (the frontmatter).
- **Effects button:** turns the scanlines and the lightning on or off, and remembers your choice. The default follows the system's "reduce motion" setting.

The viewer is copied over on every run, so edit `report-viewer.html` in the skill folder, not the copy in `reports/`.

## Scripts

| Script | What |
|---|---|
| `scripts/prepare-run.ps1` | Creates the report folders, copies the viewer, hashes the spec, archives an earlier report; prints JSON |
| `scripts/spec-digest.ps1` | OpenAPI/Swagger digest per endpoint, or one route in detail; `-OutFile` for long output |
