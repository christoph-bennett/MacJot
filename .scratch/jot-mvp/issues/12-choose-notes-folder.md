# 12: Choose the Notes Folder

**What to build:** Settings gains a Notes Folder picker. Choosing a different folder switches Jot to it immediately (Note List, search and new Notes all use the new folder). A dialog then tells the user that existing Notes are not moved and must be moved manually, with a **Show Old Folder** button that reveals the previous folder in Finder. Jot never moves or copies Notes itself. The choice persists across relaunch.

**Blocked by:** 04, 05

**Status:** ready-for-agent

- [ ] Settings shows the current Notes Folder and a button to choose another
- [ ] After choosing, the Note List shows the new folder's Notes and new Notes are written there
- [ ] Dialog explains Notes must be moved manually; Show Old Folder reveals the old folder in Finder
- [ ] No files are moved, copied or deleted in either folder
- [ ] The open Note is saved to the old folder before switching
- [ ] Choice persists across relaunch; if the folder is missing at launch it's recreated
