# 45: Pasteboard and ⌘C inspector

**What to build:** A small developer tool that shows what is on the system pasteboard and what a ⌘C in the apps used daily really does, so that the capture (ticket 49) and the image decisions that follow rest on facts (decided 2026-11-15, spec 0002; widened after a sparring session). It is a separate Swift package kept outside the MacJot repository (`~/Developer/pasteboard-inspector`): an internal evaluation tool that is never published to GitHub, while its findings below are. It avoids Swift macros (no `@Observable`, `#Preview` or SwiftData), because the Command Line Tools can't run their plugins.

It lists every pasteboard item with its types (UTIs), the byte size of each, and a preview: text, RTF, HTML (as source), and images. It refreshes when the clipboard changes. A button presses ⌘C in the frontmost app after a countdown and shows what arrived, how long the pasteboard took to change, and whether it changed more than once. An option holds ⌃⌥ down while it sends the ⌘C, to show what the target app does with leaked modifiers. A line shows the frontmost app's name and its front window's title as the Accessibility API reports them.

It logs everything it sees to a JSON Lines file, `~/Library/Logs/PasteboardInspector/inspector.jsonl` (outside the repository, because a pasteboard can hold private text): one line per pasteboard change, with the frontmost app and its window title at that moment, and one line per ⌘C run with its measurements. Text previews are cut to 200 characters and left out for items marked concealed. Nobody copies findings by hand: the tool is run against Safari, Chrome, Pages and Terminal (a paragraph, a list and a terminal prompt line each, with and without ⌃⌥), and the findings below are written from the log afterwards. Ticket 49 is written against them.

**Blocked by:** None (can start immediately). It blocks 49.

**Status:** done

- [x] The tool builds as its own package with `swift build` (sandbox off, no macros), and nothing of it is in the MacJot repository, its `Package.swift` or its scripts.
- [x] Copying text in any app shows its item with every type and size within a second, without clicking; copying an image shows the image types, sizes and a preview.
- [x] The ⌘C button reports the app, the window title, the latency until the first change, the number of changes, and the text read.
- [x] The held-modifiers option shows whether each of the four apps still copies when ⌃⌥ are held during the ⌘C.
- [x] It records whether macOS 27 asks before a program reads the pasteboard, and what each app puts there for text.
- [x] Every pasteboard change and every ⌘C run is appended to the log file without any action; nothing in the log holds a preview of a concealed item.
- [x] Findings, written into this ticket under "Findings" from the log: latency per app, window titles per app (Chrome with its profile, Safari, Pages, Terminal), the modifier result, the pasteboard prompt result, and anything that changes ticket 49 or 46.

## Findings

From `inspector.jsonl`, 2026-11-15 (first session: nine plain copies, no ⌘C button runs yet). The frontmost app and its window title in each line were sampled up to 250 ms after the change, so a change made by another process can carry the wrong app: Raycast's restore was logged under the inspector itself.

**What each app puts on the pasteboard for a text selection** (sizes from one copy each):

| App | Types | Window title (Accessibility) |
|---|---|---|
| Safari | `public.utf8-plain-text`, `public.html`, `public.rtf`, `com.apple.webarchive` (7 to 89 KB), `com.apple.flat-rtfd`, `com.apple.WebKit.custom-pasteboard-data` | `Personal — <page title>`: a Safari profile name and an em dash in front of the title |
| Chrome | `public.utf8-plain-text`, `public.html`, `org.chromium.source-url`, `org.chromium.internal.source-rfh-token` | `<page title> - Google Chrome` |
| Edge | the same as Chrome | `<page title> - Microsoft Edge` |
| Pages | `public.utf8-plain-text`, `public.rtf`, `public.utf16-external-plain-text`, `com.apple.flat-rtfd`, and ten `com.apple.iWork.*` types (seven of zero bytes) | `CV.pages`: the document's name |
| Terminal | `public.utf8-plain-text`, `public.rtf`, `public.utf16-external-plain-text` | `mac-notes — PasteboardInspector — 162×48`: folder, process and window size |

**Other things copied:**
- Finder, a file copied: `public.file-url` (a `/.file/id=` reference, not a path), `public.utf8-plain-text` holding only the file's name, and `com.apple.icns` (321 KB). A Clip from this would have the file's name as its text.
- Preview, an image (Select All, Copy): `public.png` (206 KB) and one `dyn.*` type, with no text at all.
- Raycast clipboard history pasted three files: three items with `public.file-url` and a `dyn.*` type; the first also carries `org.nspasteboard.source` and `com.raycast.RestoredType`.

**What this changes:**
- Plain text is on the pasteboard in every case where there is text, so reading `public.utf8-plain-text` is enough for the first Clips. Chrome and Edge give no RTF; Safari and Terminal give RTF too (rich text stays a Later item).
- The window title cannot be used as `page` as it is. Safari prefixes the profile name (`Personal — `; this is also why the other Jot app's notes show "Personal — Finis — …"); Chrome and Edge suffix the app name (`- Google Chrome`); Terminal's is a folder, a process and a size; Pages' is the file name; Finder's is a path. Ticket 49's cleaning needs a Safari rule as well (drop a leading `<word> — ` segment when the app is Safari) and the cleaner is tested against these titles.
- Chrome and Edge put the page's URL on the pasteboard as `org.chromium.source-url`, which makes a Clip's URL possible there without Accessibility (Later item "A Clip's URL"). Safari has no such type; its web archive probably holds the URL inside (not checked).
- Apps mark where a copy came from with `org.nspasteboard.source` (Raycast does); a Clip's `source` could use it when present. MacJot's own restore should set `org.nspasteboard.TransientType` and `org.nspasteboard.source`, as the convention expects.
- Image selections arrive as `public.png` or `public.tiff` with no text: the first Clips treat them as "no text" (alert); images are for the image grilling.
- Pages' data is available as plain text too, so a selection in Pages needs no special handling.
- The tool, started from Terminal, read every type of every item in all of the copies above. The log can't show whether macOS put up a prompt along the way, and it doesn't settle whether macOS asks a bundled app like MacJot; the pasteboard access behavior is now logged on every line to answer that.

**Synthesized ⌘C, from the 15 runs of the button (same day, 09:18 to 09:23):**

| App | ⌘C only | ⌘C with ⌃⌥ held |
|---|---|---|
| Safari | copied, one change after 55 ms | nothing copied |
| Chrome | copied, one change after 41 ms | nothing copied |
| Pages | copied, one change after 24 ms | nothing copied |
| Finder (a file) | copied, one change after 19 ms | nothing copied |
| Preview (an image) | copied, one change after 64 ms, a PNG and no text | nothing copied (twice) |
| Terminal | copied on the retest, one change after 25 ms (the first run copied nothing, see below) | nothing copied |

- A posted ⌘C reaches every app tried and the pasteboard changes exactly once, within 65 ms. The wait of about 0.5 s in ticket 49 is generous, and no app wrote the pasteboard twice, so the 50 ms settle only guards against apps not tried.
- ⌃⌥ held with the ⌘C stops the copy in every app (six of six). The tool sent the flags ⌃⌥⌘ explicitly, so this shows that the apps obey the flags; it does not show what a physical ⌃⌥ held down does to an event posted with ⌘ only. Ticket 49 still waits for the modifiers to be released and sends ⌘ only, and checks it with the real hotkey.
- **Terminal copied on the retest.** A line range was selected by dragging in a plain `-zsh` window (Secure Keyboard Entry off), and the posted ⌘C put 537 characters on the pasteboard after 25 ms (`public.utf8-plain-text`, `public.rtf`, `public.utf16-external-plain-text`). The first run had copied nothing, with Claude Code's window in front; the most likely reason is that nothing was selected there, and it was not repeated. A selection made by dragging can start in the middle of a line (this one began with `oph  staff  1184 …`), so the first line of a terminal Clip is often a fragment: the Title rules in tickets 47 and 49 have to live with that.
- The window titles read at the moment of each run match the table above: Chrome `GitHub · Change is constant. GitHub keeps you ahead. · GitHub · GitHub - Google Chrome` (the page's own title already contains ` · GitHub`, so only the trailing ` - Google Chrome` can be stripped safely), Safari `Personal — Peer/SKILL.md at main · andykear/Peer`, Finder `/Users/christoph/Developer/mac-notes/docs`, Preview `screenshot-dark.png`.
- The pasteboard access behavior was "always allow" for the inspector in all runs. That says nothing yet about MacJot as a bundled app; ticket 49 logs it on its first run.
- Raycast: scrolling its clipboard history writes nothing to the pasteboard. Its only trace is the restore at 09:08 (`com.raycast.RestoredType`), when an entry was pasted.

**Left open:** the held-modifier result with the real hotkey, and whether MacJot as a bundled app is asked before it reads the pasteboard (both are checked in ticket 49).
