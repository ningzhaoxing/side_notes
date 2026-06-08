# SideNotes

SideNotes is a personal macOS planning card. It stays available from the screen edge, can be pinned as a floating card, flips between today's plan and long-term areas, and stores everything locally in SQLite.

Repository:

```text
git@github.com:ningzhaoxing/side_notes.git
```

## Build

```bash
Scripts/build_app.sh
```

The runnable app is created at:

```text
Build/SideNotes.app
```

## Open

```bash
open Build/SideNotes.app
```

You can also double-click `Build/SideNotes.app` in Finder.

To keep it as a normal personal app under your user Applications folder:

```bash
Scripts/install_app.sh
```

The install script builds the app and copies it to:

```text
~/Applications/SideNotes.app
```

The app runs as a menu-bar accessory and opens with the card pinned by default, so it is visible immediately after launch. Click `取消固定` to let it hide back into the side edge. When hidden, a narrow side bookmark stays on the screen edge; click it or move the mouse to the edge to reveal the card again. Use the `SideNotes` menu-bar item to show the card or open the editor.

## Use

- The front side shows today's custom groups and checkable tasks.
- The back side shows long-term areas and items.
- Drag the small handle in the lower-right corner of the card to resize it.
- Use `编辑` or the menu-bar item to open the editor.
- Use `设置` on the card to open the `外观` tab directly.
- Use `归档` to archive the current day and start a blank plan.
- Use the editor's `外观` tab to change card opacity and corner radius.

## Data

The local database is stored at:

```text
~/Library/Application Support/SideNotes/SideNotes.sqlite
```

No cloud sync is used in version 1.
