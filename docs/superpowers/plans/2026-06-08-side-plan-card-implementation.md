# Side Plan Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a directly openable macOS app for a side-triggered, pinnable, two-sided planning card with local persistence, editing, manual archive history, and appearance settings.

**Architecture:** Use a Swift Package so the app can be built with Command Line Tools. Keep testable planning/domain logic in `SideNotesCore`, keep SwiftUI/AppKit runtime code in `SideNotesApp`, and produce a `.app` bundle with a shell script. Persistence uses the system SQLite library through `PlanStore`, which satisfies the local database requirement without needing full Xcode or SwiftData macros.

**Tech Stack:** Swift 6.2, Swift Package Manager, SwiftUI, AppKit, XCTest, SQLite, macOS `.app` bundle packaging.

---

## File Structure

- `Package.swift`: Swift package with `SideNotesCore`, `SideNotesApp`, and `SideNotesCoreTests`.
- `Sources/SideNotesCore/Models.swift`: Codable domain models for daily plan, long-term plan, archives, and app settings.
- `Sources/SideNotesCore/SQLiteDatabase.swift`: Small SQLite wrapper for statements, binding, transactions, and schema setup.
- `Sources/SideNotesCore/PlanStore.swift`: SQLite persistence boundary and mutation methods.
- `Sources/SideNotesCore/ArchiveService.swift`: Manual archive operation.
- `Sources/SideNotesCore/SettingsValidator.swift`: Appearance and window-setting validation.
- `Sources/SideNotesApp/main.swift`: AppKit entrypoint.
- `Sources/SideNotesApp/AppCoordinator.swift`: Creates card/editor windows and wires store, trigger, and views.
- `Sources/SideNotesApp/EdgeTriggerController.swift`: Mouse-edge polling for side reveal.
- `Sources/SideNotesApp/PlanCardWindowController.swift`: Floating side-card window behavior.
- `Sources/SideNotesApp/PlanCardView.swift`: Two-sided SwiftUI card.
- `Sources/SideNotesApp/EditorView.swift`: Editor for today, long-term areas, archive history, and appearance settings.
- `Sources/SideNotesApp/ViewModels.swift`: Observable state and UI actions.
- `Tests/SideNotesCoreTests/ArchiveServiceTests.swift`: Archive behavior.
- `Tests/SideNotesCoreTests/PlanStoreTests.swift`: Persistence and mutation behavior.
- `Tests/SideNotesCoreTests/AppSettingsTests.swift`: Settings validation and persistence.
- `Scripts/build_app.sh`: Build release binary and create `Build/SideNotes.app`.
- `README.md`: How to build, open, and use the app.

## Task 1: Package And Core Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/SideNotesCore/Models.swift`
- Create: `Tests/SideNotesCoreTests/AppSettingsTests.swift`

- [ ] **Step 1: Write failing settings tests**

Create `Tests/SideNotesCoreTests/AppSettingsTests.swift` with tests that validate default settings and clamped appearance values.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test --filter AppSettingsTests
```

Expected: FAIL because `SideNotesCore` types do not exist yet.

- [ ] **Step 3: Add package and models**

Create the Swift package and `Models.swift` with Codable structs for `DailyPlan`, `DailyPlanGroup`, `DailyTask`, `ArchiveDay`, `LongTermArea`, `LongTermItem`, `AppSettings`, and `VisibleSide`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test --filter AppSettingsTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/SideNotesCore/Models.swift Tests/SideNotesCoreTests/AppSettingsTests.swift
git commit -m "Add core planning models"
```

## Task 2: Archive Service

**Files:**
- Create: `Sources/SideNotesCore/ArchiveService.swift`
- Create: `Tests/SideNotesCoreTests/ArchiveServiceTests.swift`

- [ ] **Step 1: Write failing archive tests**

Create tests proving archive snapshots preserve group order, task order, task completion, and clear the current plan only after success.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test --filter ArchiveServiceTests
```

Expected: FAIL because `ArchiveService` does not exist yet.

- [ ] **Step 3: Implement archive service**

Implement an `ArchiveService.archive(plan:existingArchives:now:)` function returning updated current plan and archive list.

- [ ] **Step 4: Run tests**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SideNotesCore/ArchiveService.swift Tests/SideNotesCoreTests/ArchiveServiceTests.swift
git commit -m "Add manual archive service"
```

## Task 3: Plan Store Persistence

**Files:**
- Create: `Sources/SideNotesCore/SQLiteDatabase.swift`
- Create: `Sources/SideNotesCore/PlanStore.swift`
- Create: `Tests/SideNotesCoreTests/PlanStoreTests.swift`

- [ ] **Step 1: Write failing persistence tests**

Create tests for creating daily groups, adding tasks, toggling completion, adding long-term areas/items, archiving, searching archive text, and round-tripping through an on-disk SQLite database.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test --filter PlanStoreTests
```

Expected: FAIL because `PlanStore` and `SQLiteDatabase` do not exist yet.

- [ ] **Step 3: Implement SQLite-backed plan store**

Implement SQLite persistence under an injected database file URL, with production default in `~/Library/Application Support/SideNotes/SideNotes.sqlite`. Use normalized tables for current groups/tasks, long-term areas/items, settings, and archives. Store archive group snapshots as JSON text inside the `archives` table so history cannot be mutated by later current-plan edits.

- [ ] **Step 4: Run tests**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SideNotesCore/SQLiteDatabase.swift Sources/SideNotesCore/PlanStore.swift Tests/SideNotesCoreTests/PlanStoreTests.swift
git commit -m "Add local plan persistence"
```

## Task 4: SwiftUI Card And Editor Views

**Files:**
- Create: `Sources/SideNotesApp/PlanCardView.swift`
- Create: `Sources/SideNotesApp/EditorView.swift`
- Create: `Sources/SideNotesApp/ViewModels.swift`

- [ ] **Step 1: Build core tests before UI work**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test
```

Expected: PASS.

- [ ] **Step 2: Implement view model and views**

Create an observable view model that loads from `PlanStore`, toggles tasks, flips side, archives, and edits groups/items. Implement SwiftUI views for the card front/back, editor tabs, history search, opacity slider, and corner-radius slider.

- [ ] **Step 3: Compile debug app**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift build
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/SideNotesApp/PlanCardView.swift Sources/SideNotesApp/EditorView.swift Sources/SideNotesApp/ViewModels.swift
git commit -m "Add planning card and editor UI"
```

## Task 5: AppKit Windows And Edge Trigger

**Files:**
- Create: `Sources/SideNotesApp/main.swift`
- Create: `Sources/SideNotesApp/AppCoordinator.swift`
- Create: `Sources/SideNotesApp/EdgeTriggerController.swift`
- Create: `Sources/SideNotesApp/PlanCardWindowController.swift`

- [ ] **Step 1: Compile existing app**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift build
```

Expected: PASS.

- [ ] **Step 2: Implement app runtime**

Implement an AppKit `NSApplicationDelegate`, floating card window, editor window, side-edge polling, pin/unpin, show/hide, and frame restoration.

- [ ] **Step 3: Compile debug app**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift build
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/SideNotesApp/main.swift Sources/SideNotesApp/AppCoordinator.swift Sources/SideNotesApp/EdgeTriggerController.swift Sources/SideNotesApp/PlanCardWindowController.swift
git commit -m "Add macOS window runtime"
```

## Task 6: Build Runnable App Bundle

**Files:**
- Create: `Scripts/build_app.sh`
- Create: `README.md`

- [ ] **Step 1: Write app bundle script**

Create a script that builds release with writable module cache, creates `Build/SideNotes.app`, writes `Info.plist`, copies the binary to `Contents/MacOS/SideNotes`, and marks it executable.

- [ ] **Step 2: Run full test suite**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/sidenotes-module-cache swift test
```

Expected: PASS.

- [ ] **Step 3: Build app bundle**

Run:

```bash
Scripts/build_app.sh
```

Expected: `Build/SideNotes.app` exists and contains an executable binary.

- [ ] **Step 4: Smoke launch**

Run:

```bash
open Build/SideNotes.app
```

Expected: the app opens. Manual check confirms the floating card is visible or appears from the right edge, editor opens, sample content can be added, task checkboxes work, archive creates history, opacity and corner radius controls affect the card.

- [ ] **Step 5: Commit**

```bash
git add Scripts/build_app.sh README.md
git commit -m "Add app bundle build and usage docs"
```

## Self-Review

- Spec coverage: side trigger, pinning, card flip, daily custom groups, checkable tasks, long-term areas, editor, manual archive, archive search, local persistence, opacity, corner radius, and app bundle are covered.
- Tooling note: SwiftData macros are unavailable in the current Command Line Tools environment, so the implementation uses SQLite through `PlanStore`. This still satisfies the local database requirement.
- Placeholder scan: no task uses vague future-work markers; each task has concrete files, commands, and expected results.
