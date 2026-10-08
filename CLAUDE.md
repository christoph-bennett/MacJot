# Jot (mac-notes)

Before doing anything else, read `~/services/SERVICES.md`. It holds the shared context for all of Christoph's locally running services, including this one: key paths, decisions already made, and the registry contract for the monitoring dashboard at http://localhost:8642.

When you change something that affects how this app runs (autostart, data locations, process name), update both:
- this app's section in `~/services/SERVICES.md`
- its manifest in `~/services/registry/`

If this app is not yet registered on the dashboard and it grows into something that runs in the background, invoke the `new-service` skill.

Global working-style instructions live in `~/Claude Cowork/CLAUDE.md` (About Me files, writing rules).

## Project

- Vocabulary: `GLOSSARY.md`. Decisions: `docs/adr/`. Spec: `docs/specs/0001-mvp.md`. Tickets: `.scratch/jot-mvp/issues/`.
- Built with SwiftPM (no Xcode installed): `swift build`; tests via `scripts/test.sh` (works around Swift Testing with Command Line Tools only); `scripts/bundle.sh` produces an ad-hoc-signed `build/Jot.app`.
- In Claude Code, build/test commands need the sandbox disabled: the sandbox blocks the Swift macro plugin server.
