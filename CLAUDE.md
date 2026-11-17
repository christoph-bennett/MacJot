# MacJot (mac-notes)

## Project

- Vocabulary: `GLOSSARY.md`. Decisions: `docs/adr/`. Specs: `docs/specs/` (0001 is the MVP, complete, git tag `mvp`; later ones follow it). Tickets: MVP tickets 1 to 42 in `.scratch/jot-mvp/issues/`, later ones (43 on, numbering continues) in `.scratch/macjot/issues/`; each folder's `README.md` is an index with statuses, keep it in sync when a ticket's status changes. Backlog (Inbox / Planned / Later / Not planned): `BACKLOG.md`; "add to backlog: …" goes to its Inbox.
- Built with SwiftPM (Xcode is installed, but the project builds without it): `swift build`; tests via `scripts/test.sh` (works around Swift Testing with Command Line Tools only); `scripts/bundle.sh` produces an ad-hoc-signed `build/MacJot.app`. `scripts/install.sh` copies it to `~/Applications/` and restarts MacJot.
- In Claude Code, build/test commands need the sandbox disabled: the sandbox blocks the Swift macro plugin server.
