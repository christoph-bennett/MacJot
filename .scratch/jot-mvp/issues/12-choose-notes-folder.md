# 12: Choose the Notes Folder

**What to build:** Settings gains a Notes Folder picker. Choosing a different folder switches Jot to it immediately (Note List, search and new Notes all use the new folder). A dialog then tells the user that existing Notes are not moved and must be moved manually, with a **Show Old Folder** button that reveals the previous folder in Finder. Jot never moves or copies Notes itself. The choice persists across relaunch.

**Blocked by:** 04, 05

**Status:** done

- [x] Settings shows the current Notes Folder and a button to choose another
- [x] After choosing, the Note List shows the new folder's Notes and new Notes are written there
- [x] Dialog explains Notes must be moved manually; Show Old Folder reveals the old folder in Finder
- [x] No files are moved, copied or deleted in either folder
- [x] The open Note is saved to the old folder before switching
- [x] Choice persists across relaunch; if the folder is missing at launch it's recreated

**Added at the user's request:** Jot keeps a bookmark next to the folder's path, so it notices when the Notes Folder itself is renamed, moved or deleted, both while running (FSEvents root changes) and at launch.

- [x] Renamed or moved: Jot follows the folder, with the open Note, and says where it is now
- [x] In the Trash or gone: never followed; an alert offers Quit Jot (e.g. to put it back first) or Create New Folder at the old path
- [x] A folder synced by a cloud service (iCloud Drive, or a File Provider service under `~/Library/CloudStorage` such as Dropbox, Google Drive, OneDrive) can be chosen after a warning: the service may evict files, so it's only recommended if the folder always stays downloaded
