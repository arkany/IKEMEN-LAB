# Character Cutoff Indicator — Agent Prompt

## Context

IKEMEN Lab is a macOS-native content manager for IKEMEN GO. The app tracks:
- **Characters** in the library (displayed in `CharacterBrowserView`)
- **Screenpacks** with slot limits (parsed from `system.def` as `rows × columns`)

Currently, the Screenpack Browser shows a warning badge when the roster exceeds the slot limit. However, the **Character Browser** doesn't indicate which characters will actually appear in-game vs which ones are "cut off" due to the screenpack limit.

## Goal

Add a visual divider in the Character Browser (grid and list views) that shows **where the screenpack cutoff occurs**. Characters below this line won't appear on the in-game select screen.

---

## Task 1: Get Active Screenpack Slot Limit

**Files:** `CharacterBrowserView.swift`, `EmulatorBridge.swift`

### Requirements

1. `CharacterBrowserView` needs to know the active screenpack's `characterSlots` value
2. Get this from `EmulatorBridge.shared.screenpacks.first(where: { $0.isActive })?.characterSlots`
3. Store as a property and update when screenpacks change (subscribe to `EmulatorBridge.shared.$screenpacks`)

### Implementation

Add to `CharacterBrowserView`:
```swift
private var activeScreenpackSlotLimit: Int = 0

// In setup() or init, subscribe to screenpack changes:
EmulatorBridge.shared.$screenpacks
    .receive(on: DispatchQueue.main)
    .sink { [weak self] screenpacks in
        self?.activeScreenpackSlotLimit = screenpacks.first(where: { $0.isActive })?.characterSlots ?? 0
        self?.collectionView.reloadData()  // Refresh to show/hide divider
    }
    .store(in: &cancellables)
```

---

## Task 2: Add Cutoff Divider in Grid View

**File:** `CharacterBrowserView.swift`

### Requirements

1. Show a horizontal divider between the last "visible" character and the first "cut off" character
2. The divider should span the full width of the grid
3. Above the divider: "✓ 60 characters will appear" (green text)
4. Below the divider: "⚠️ 85 characters hidden" (orange/warning text)
5. Only show if `characters.count > activeScreenpackSlotLimit` and `activeScreenpackSlotLimit > 0`

### Design

```
┌─────────────────────────────────────────────────────────┐
│  [Char 58]  [Char 59]  [Char 60]                        │
├─────────────────────────────────────────────────────────┤
│  ✓ 60 characters shown          ⚠️ 85 characters hidden │
├─────────────────────────────────────────────────────────┤
│  [Char 61]  [Char 62]  [Char 63]  ← dimmed/faded        │
│  [Char 64]  [Char 65]  [Char 66]                        │
└─────────────────────────────────────────────────────────┘
```

### Implementation Approach

Option A: **Supplementary View** (recommended for NSCollectionView)
- Register a supplementary view of type "cutoff-divider"
- Return it from `collectionView(_:viewForSupplementaryElementOfKind:at:)`
- Position after the cutoff index using layout

Option B: **Section Break**
- Split characters into two sections: "Visible" and "Hidden"
- Add section header between them
- Requires refactoring data source

**Recommended: Option A** — less disruptive to existing code.

### Supplementary View Setup

```swift
// Register supplementary view
collectionView.register(
    CutoffDividerView.self,
    forSupplementaryViewOfKind: "CutoffDivider",
    withIdentifier: NSUserInterfaceItemIdentifier("CutoffDivider")
)

// Create CutoffDividerView class
class CutoffDividerView: NSView, NSCollectionViewElement {
    private var visibleCountLabel: NSTextField!
    private var hiddenCountLabel: NSTextField!
    private var dividerLine: NSView!
    
    func configure(visibleCount: Int, hiddenCount: Int) {
        visibleCountLabel.stringValue = "✓ \(visibleCount) characters shown"
        hiddenCountLabel.stringValue = "⚠️ \(hiddenCount) characters hidden"
    }
}
```

### Styling

- Divider line: `DesignColors.zinc700`, 1px height
- Visible label: `DesignFonts.captionMedium`, green color (`NSColor.systemGreen`)
- Hidden label: `DesignFonts.captionMedium`, orange color (`NSColor.systemOrange`)
- Background: `DesignColors.zinc900` with subtle gradient
- Height: 40px
- Full width spanning all columns

---

## Task 3: Dim "Cut Off" Characters

**File:** `CharacterBrowserView.swift` (grid cell configuration)

### Requirements

1. Characters beyond the slot limit should appear **dimmed** (50% opacity)
2. Add a subtle overlay or reduce alpha on the cell
3. Optionally show a small "hidden" badge in corner

### Implementation

In `collectionView(_:itemForRepresentedObjectAt:)`:
```swift
let isBeyondCutoff = activeScreenpackSlotLimit > 0 && indexPath.item >= activeScreenpackSlotLimit
cell.alphaValue = isBeyondCutoff ? 0.5 : 1.0
// Or add a "hidden" indicator badge
```

---

## Task 4: Add Cutoff Indicator in List View

**File:** `CharacterBrowserView.swift`

### Requirements

1. In list/table view, show a separator row at the cutoff point
2. Same text: "✓ X characters shown" / "⚠️ Y characters hidden"
3. Rows below should be dimmed

### Implementation

If using NSTableView for list mode:
- Insert a special "divider row" at the cutoff index
- Or use row coloring to dim cut-off rows

---

## Task 5: Update When Characters Change

### Requirements

1. Divider position should update when:
   - Characters are added/removed
   - Active screenpack changes
   - User reorders characters
2. Recalculate `hiddenCount = max(0, characters.count - activeScreenpackSlotLimit)`

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No active screenpack | Don't show divider |
| Slot limit = 0 (unknown) | Don't show divider |
| All characters fit | Don't show divider |
| Exactly at limit | Don't show divider (no hidden characters) |
| User reorders characters | Divider stays at same position (slot limit) |

---

## Files to Modify

1. `IKEMEN Lab/UI/CharacterBrowserView.swift` — Main implementation
2. (Optional) Create `IKEMEN Lab/UI/CutoffDividerView.swift` — Reusable divider view

## Files to Reference

- `IKEMEN Lab/Models/ScreenpackInfo.swift` — See `characterSlots` property
- `IKEMEN Lab/Core/EmulatorBridge.swift` — See `screenpacks` publisher, `activeScreenpackPath`
- `IKEMEN Lab/UI/ScreenpackBrowserView.swift` — See existing overflow warning pattern (lines 629-634)
- `IKEMEN Lab/Shared/UIHelpers.swift` — Design tokens

---

## Testing

1. Install a screenpack with known slot limit (e.g., 60 slots)
2. Add more than 60 characters to the library
3. Verify:
   - Divider appears between character 60 and 61
   - Characters 61+ are dimmed
   - Labels show correct counts
4. Change active screenpack to one with different limit
5. Verify divider repositions correctly
6. Test with screenpack that has no limit (divider should not appear)
