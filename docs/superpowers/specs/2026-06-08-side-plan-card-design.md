# Side Plan Card macOS App Design

## Summary

Build a personal macOS app for keeping a small planning card available on screen. The app is a native SwiftUI macOS application. Its main surface is a side-triggered floating card with two sides:

- Front: the current daily plan, organized by user-defined groups with checkable tasks.
- Back: long-term planning areas, organized as simple domain lists such as reading, English, social, health, and career.

The app prioritizes quick viewing while working. Editing happens in a separate full editor window. Data is stored locally on the Mac using SwiftData.

## Goals

- Keep the daily plan visible or quickly reachable without opening a full productivity app.
- Support side-edge activation, slide-out behavior, and a pin button for persistent floating use.
- Let the user switch between daily planning and long-term planning with a card flip interaction.
- Let the user manually archive the current day into history and start a blank new day.
- Preserve complete archive history for later browsing and search.
- Keep the first version small enough to implement reliably.

## Non-Goals For Version 1

- iCloud sync or multi-device sync.
- Automatic carryover of unfinished tasks into the next day.
- Automatic daily rollover without user action.
- Complex progress tracking, analytics, recurring tasks, reminders, or calendar integration.
- Direct editing inside the small floating card beyond task completion toggles.
- Markdown file storage or external editor integration.

## User Experience

### Primary Window

The primary window is a floating plan card that appears from the screen edge. The default trigger is the right screen edge. When the mouse approaches the edge trigger zone, the card slides out. When the card is not pinned and the user moves away, it can slide back in.

The card includes a small control row:

- Pin or unpin.
- Flip front or back.
- Open editor.
- Archive current daily plan.

When pinned, the card stays visible as a floating window above normal app windows. The app remembers its pinned state, side, size, position, and currently visible side.

### Front Side: Daily Plan

The front side shows the current daily plan. This is not a "three big things" view. It is a user-authored plan.

The user can create custom groups with arbitrary names, such as:

- Morning
- Evening
- Work
- English
- Social
- Health

Each group contains ordered tasks. Tasks can be checked off from the card. Adding, renaming, reordering, and deleting groups or tasks happens in the editor window.

### Back Side: Long-Term Plan

The back side shows long-term planning areas. Version 1 uses a simple domain list structure:

- Each area has a name and order.
- Each area contains ordered text items.
- Items represent long-term commitments, reading lists, study plans, habits, or reminders.

The back side is meant for orientation and reminders, not detailed project management.

### Editing Window

Clicking Edit opens a separate editor window. The editor has sections for:

- Current daily plan.
- Long-term areas.
- Archive history.

The current daily plan editor supports creating and editing custom groups and tasks. The long-term editor supports creating and editing areas and text items. The archive section supports browsing prior archived days and searching archived content.

### Manual Archive Flow

The user decides when to archive. Pressing Archive performs this flow:

1. Confirm the action if the current plan is not empty.
2. Copy the current daily plan into an archive record, preserving group names, task order, task text, and completion state.
3. Clear the current daily plan.
4. Start a blank new daily plan.

Version 1 archives everything and does not carry unfinished tasks forward. Carryover can be added later.

## Data Model

Use SwiftData for local persistence.

### DailyPlan

Represents the current active daily plan.

Fields:

- `id`
- `planningDate`
- `groups`
- `createdAt`
- `updatedAt`

### DailyPlanGroup

Represents one user-defined section in the current daily plan.

Fields:

- `id`
- `title`
- `sortOrder`
- `tasks`

### DailyTask

Represents a checkable task in a daily group.

Fields:

- `id`
- `title`
- `isCompleted`
- `sortOrder`
- `createdAt`
- `updatedAt`

### ArchiveDay

Represents one manually archived daily plan snapshot.

Fields:

- `id`
- `archiveDate`
- `sourcePlanningDate`
- `groupsSnapshot`
- `createdAt`

`groupsSnapshot` stores the archived groups and tasks as a stable value snapshot so later edits to current plan models cannot mutate history.

### LongTermArea

Represents one long-term domain on the back side.

Fields:

- `id`
- `title`
- `sortOrder`
- `items`
- `createdAt`
- `updatedAt`

### LongTermItem

Represents one long-term text item under an area.

Fields:

- `id`
- `title`
- `sortOrder`
- `createdAt`
- `updatedAt`

### AppSettings

Stores user preferences and window state.

Fields:

- `id`
- `triggerSide`
- `isPinned`
- `cardFrame`
- `editorFrame`
- `visibleSide`
- `lastArchiveDate`

## Architecture

### AppCoordinator

Owns high-level app state, creates windows, wires services, and coordinates between edge trigger, card window, editor window, and persistence.

### PlanCardWindow

Manages the floating side card window:

- Slide-out and slide-in behavior.
- Pinned floating behavior.
- Window frame restoration.
- Multi-screen frame validation.

### EdgeTriggerController

Listens for mouse position near the configured screen edge. It notifies `AppCoordinator` when the card should show or hide. It does not know about plan data.

### PlanCardView

SwiftUI view for the front and back of the card:

- Front renders daily groups and task checkboxes.
- Back renders long-term areas and items.
- Handles card flip animation.
- Sends user actions to view models.

### EditorWindow

Dedicated window for editing:

- Current daily plan editor.
- Long-term area editor.
- Archive history browser and search.

### PlanStore

Persistence boundary around SwiftData. UI code should not directly manage database details. It exposes operations for:

- Loading current daily plan.
- Updating groups and tasks.
- Toggling task completion.
- Managing long-term areas.
- Reading archive history.
- Persisting settings.

### ArchiveService

Handles archive behavior as a single transaction-like operation:

- Build an immutable snapshot from the current plan.
- Save `ArchiveDay`.
- Clear current daily groups and tasks.
- Return the new blank current plan.

If saving the archive fails, the service must not clear the current daily plan.

## Error Handling

- Database write failures show an error in the editor or card instead of silently losing data.
- Archive failure leaves the current daily plan untouched.
- If a restored card frame is outside all connected displays, the card returns to the main display's right edge.
- If edge triggering is unreliable on a display setup, opening the app should still expose the editor and a way to show the card.
- Empty states should be explicit: no daily groups, no long-term areas, and no archive history each get clear empty views.

## Testing

### Unit Tests

`ArchiveService`:

- Archives all groups and tasks.
- Preserves task completion state.
- Preserves group and task order.
- Clears the current plan only after the archive snapshot is saved.
- Leaves the current plan unchanged when archive save fails.

`PlanStore`:

- Creates, edits, deletes, and reorders daily groups.
- Creates, edits, deletes, reorders, and toggles daily tasks.
- Creates, edits, deletes, and reorders long-term areas and items.
- Loads archive history and search results.

`AppSettings`:

- Persists pinned state.
- Persists visible side.
- Persists and validates window frames.

### Manual Verification

- Card slides out from the configured side edge.
- Card can be pinned and unpinned.
- Card flips between daily plan and long-term plan.
- Task completion toggles persist.
- Editor window opens and edits are reflected in the card.
- Archive creates a history entry and starts a blank current plan.
- Relaunch restores settings and current data.

## Version 1 Acceptance Criteria

- The app launches as a native macOS app.
- Moving the mouse to the configured edge can reveal the card.
- The card can be pinned as a floating window.
- The front side shows custom daily groups and checkable tasks.
- The back side shows long-term areas and items.
- The card can flip between front and back.
- The editor window can edit the current plan and long-term areas.
- The user can manually archive the current daily plan.
- Archived days can be browsed and searched.
- Data persists locally across app restarts.
