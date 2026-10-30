# Changelog

All notable changes to the Connector Scout skill. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/): a change to the report format is a major version.

## [Unreleased]

## [1.0.0] - 2026-10-30

First release.

### Added

- Research a target API for a HelloID provisioning target connector and write a feasibility report to `reports/<target>-feasibility.md`.
- Reference connectors read from GitHub with WebFetch: Caseware (REST account lifecycle), Iprotect (REST access system) and Generic-Scim (SCIM).
- A static report viewer in the ConnectorX look: glass cards, glowing buttons, scanlines, and a start screen with a lit logo and lightning. An Effects button turns the scanlines and lightning off. Load a report with Open file…, drag-and-drop or Paste; nothing is uploaded.
- `prepare-run.ps1` copies the viewer to `reports/report-viewer.html` at the start of every run.
- Logo and a README install section for cloning from GitHub.

### Changed

- The report no longer has an `existingConnectors` frontmatter field. This changes the report format: reports that still carry it are flagged as having an unknown key.
- Report section 7 is now "Reference connectors": patterns and workarounds from the reference connectors read in Step 3c.
- The README lists the four required permission rules, and the rest as optional.

### Removed

- The local `examples/` folder of reference connectors, replaced by the GitHub fetch.
- The "Already exists locally?" check and its warning (old Step 1.4).
- `build-viewer.ps1`: the viewer is static and no longer has reports built in.
- `check-report.ps1`: nothing validates the frontmatter against `references/report.schema.json` automatically any more.
