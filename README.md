# MacJot

MacJot is a menu bar app for macOS that lets you write a note the moment you think of it. Press a hotkey in any app, type, and close the panel again. Every note is a plain Markdown file in a folder you choose, so you can open, sync or edit your notes with any other tool, and they outlive the app.

<!-- Screenshot: add docs/screenshot.png (the Capture Panel with the Note List open), then uncomment.
![MacJot's Capture Panel with the Note List open](docs/screenshot.png)
-->

## Features

- Two global hotkeys: ⌃⌥N opens a new note, ⌃⌥F opens the note list with the search field ready. You can change both in Settings.
- Notes are `.md` files in one folder (`~/Documents/MacJot` unless you pick another). MacJot has no database.
- A note's first line is its title, and the filename follows it. Change the title and MacJot renames the file.
- MacJot saves while you type. If it crashes before a new note has its file, it restores the text on the next launch.
- Search finds notes by several words in any order, or by an exact phrase in quotes. It ignores case and accents.
- The editor shows Markdown as you type, with the syntax dimmed. If you'd rather not type the syntax, a formatting toolbar adds headings, bold, italic, lists, checklists, quotes, code blocks and links.
- Finder's Open With can open any `.md` file in MacJot. Files outside the notes folder open read-only until you move them in with one click.
- MacJot can start when you log in.

## Requirements

- macOS 14 or later.
- Swift 6, from either the Command Line Tools or Xcode. You don't need Xcode; the Command Line Tools are enough.

I build and test MacJot on macOS 27 with Swift 6.4 from the Command Line Tools. Older versions should work but I haven't tried them.

## Build and install

There's no ready-made download yet. An app downloaded from the internet has to be signed with an Apple Developer ID and notarized, or macOS refuses to open it. MacJot isn't, so you build it on your own Mac, which takes a minute or two.

1. Open Terminal and check whether Swift is installed:

   ```sh
   swift --version
   ```

   If macOS offers to install the Command Line Tools instead, accept, or run `xcode-select --install`. Wait for the installer to finish, then run `swift --version` again.

2. Download the source code:

   ```sh
   git clone https://github.com/christoph-bennett/MacJot.git
   cd MacJot
   ```

3. Build the app:

   ```sh
   scripts/bundle.sh
   ```

   This compiles MacJot and puts `MacJot.app` in the `build` folder. The first build takes longest.

4. Install and start it:

   ```sh
   scripts/install.sh
   ```

   This copies the app to `~/Applications` (Finder may show this folder under a translated name, such as "Programme" in German), creating the folder if it doesn't exist, and starts MacJot.

MacJot's icon appears in the menu bar. It has no Dock icon.

## First steps

Press ⌃⌥N and start typing. The first line becomes the note's title. Press Esc or the hotkey again to close the panel; there's nothing to save. Press ⌃⌥F to see your notes and search them, then Return to keep writing in the selected one.

The menu bar icon has a menu with Settings. There you can change the hotkeys, choose another notes folder, add the creation date to new filenames, adjust the editor, and have MacJot open at login (General, Startup).

## Update

From the `MacJot` folder:

```sh
git pull
scripts/bundle.sh
scripts/install.sh
```

The install script quits the running MacJot first. It saves the open note before it quits.

## Uninstall

**Your notes stay where they are. None of these steps touches the notes folder.**

1. Quit MacJot from its menu bar icon. If you set it to open at login, turn that off in Settings first.
2. Delete the app and its settings:

   ```sh
   rm -rf ~/Applications/MacJot.app
   rm -rf ~/Library/Application\ Support/MacJot
   defaults delete com.onethingwell.macjot
   ```

`~/Library/Application Support/MacJot` holds only the recovery copy of a note that didn't have its file yet.

## Run the tests

```sh
scripts/test.sh
```

With only the Command Line Tools, plain `swift test` can't run the tests, so the script passes it the options it needs. With Xcode it runs `swift test` as is.

`scripts/benchmark-search.sh` measures how fast loading and search are with thousands of generated notes. It writes them to a temporary folder, never your notes folder.

## How it's built

MacJot is written in Swift with AppKit; Settings uses SwiftUI. The decisions behind it are recorded in [`docs/adr`](docs/adr), the vocabulary in [`GLOSSARY.md`](GLOSSARY.md), the original specification in [`docs/specs/0001-mvp.md`](docs/specs/0001-mvp.md), and what might come next in [`BACKLOG.md`](BACKLOG.md).

## Thanks

- [Stik](https://github.com/0xMassi/stik_app) by 0xMassi was the inspiration. MacJot borrows several of its ideas and goes its own way on others; the specification lists which.
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus records and registers the hotkeys. It's included in [`Vendor/KeyboardShortcuts`](Vendor/KeyboardShortcuts) with a few small changes so it builds without Xcode; its README there lists them.
- [Matt Pocock's skills](https://github.com/mattpocock/skills) shaped how MacJot was designed and built. I built it with [Claude Code](https://claude.com/claude-code), using his skills to question each design, keep the glossary and decision records, and write the tests first.

## License

MIT, see [`LICENSE`](LICENSE). KeyboardShortcuts is also MIT licensed; its license is in [`Vendor/KeyboardShortcuts/license`](Vendor/KeyboardShortcuts/license).
