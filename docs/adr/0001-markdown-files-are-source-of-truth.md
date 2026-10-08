# Markdown files are the only source of truth

Notes live exclusively as `.md` files in the Notes Folder; the Search Index (in-memory for the MVP, SQLite FTS5 later) is derived from them, may be deleted and rebuilt at any time, and never holds data the files don't. We chose this over a database-first design so notes stay portable, readable by other tools (Obsidian, VS Code, iCloud sync), and survive the app being deleted. Consequence: the app must watch the Notes Folder and reconcile external edits, deletions and sync conflicts rather than assuming it is the only writer.
