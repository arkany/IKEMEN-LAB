# Tagging UI Implementation — Agent Prompt

## Context

IKEMEN Lab is a macOS-native content manager for IKEMEN GO (a MUGEN fighting game engine). It's built with **Swift/AppKit** (not SwiftUI).

The app already has a working `TagDetector.swift` that infers tags from character/stage metadata. The models (`CharacterInfo`, `StageInfo`) have an `inferredTags` computed property. However, **tags are never displayed in the UI**.

## Goal

Display inferred tags in the UI so users can see what franchise/game/style each character belongs to. This is a prerequisite for Smart Collections (tag-based filtering).

---

## Task 1: Display Tags in CharacterDetailsView

**File:** `IKEMEN Lab/UI/CharacterDetailsView.swift`

Add a "Tags" section to the character detail panel showing pill-style badges for each inferred tag.

### Requirements

1. Add a new section below the "Quick Stats" area (after author/version)
2. Section header: "Tags" (use `DesignFonts.captionMedium`, `DesignColors.zinc400`)
3. Display tags as horizontal pill badges that wrap to multiple lines if needed
4. Each pill badge should have:
   - Background: `DesignColors.zinc800` with slight border (`white/10`)
   - Text: `DesignFonts.captionRegular`, `DesignColors.zinc300`
   - Corner radius: 6px
   - Padding: 6px horizontal, 3px vertical
5. If no tags detected, show "No tags detected" in muted text
6. Update when `configure(with character:)` is called

### Reference Code Patterns

Look at how `statsGridView` is created in `CharacterDetailsView.swift` for the section pattern.

For pill badges, create a helper method like:
```swift
private func createTagBadge(_ text: String) -> NSView {
    let badge = NSView()
    badge.wantsLayer = true
    badge.layer?.backgroundColor = DesignColors.zinc800.cgColor
    badge.layer?.cornerRadius = 6
    badge.layer?.borderWidth = 1
    badge.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
    
    let label = NSTextField(labelWithString: text)
    label.font = DesignFonts.captionRegular
    label.textColor = DesignColors.zinc300
    // ... layout constraints
    
    return badge
}
```

### Implementation Steps

1. Add properties for tags section:
   ```swift
   private var tagsHeader: NSTextField!
   private var tagsContainerView: NSView!
   ```

2. Create `setupTagsSection()` method called from `setupContent()`

3. Add `updateTags(for character:)` method that:
   - Clears existing tag badges from container
   - Gets `character.inferredTags`
   - Creates pill badges using `NSStackView` with `orientation = .horizontal` and `alignment = .leading`
   - Enables wrapping for multiple rows

4. Call `updateTags(for:)` from `configure(with:)`

---

## Task 2: Show Tag Badges on Character Grid Cards

**File:** `IKEMEN Lab/UI/CharacterBrowserView.swift`

Add small tag badges (max 2-3) to the bottom of character grid cards.

### Requirements

1. Show up to 3 tags on each card (truncate with "..." or "+N" if more)
2. Position: Bottom of card, above the name label, within the gradient overlay area
3. Smaller pill size than detail view (4px padding, smaller font)
4. Tags should be semi-transparent so they don't obscure the portrait
5. Only show in grid view, not list view

### Implementation Steps

1. Find `CharacterGridCell` (or equivalent) in `CharacterBrowserView.swift`
2. Add a horizontal `NSStackView` for tag badges
3. In `configure(with character:)`, populate with first 3 `inferredTags`
4. Position above the name/author labels

---

## Task 3: Add Tags to Search/Filter

**File:** `IKEMEN Lab/Core/MetadataStore.swift` and `CharacterBrowserView.swift`

Extend search functionality to match tags.

### Requirements

1. When user searches, also match against `inferredTags`
2. Example: searching "Marvel" should find all characters with "Marvel" tag
3. Tags should be stored in SQLite for efficient querying

### Implementation Steps

1. Add `tags TEXT` column to characters table in MetadataStore
2. Store `inferredTags.joined(separator: ",")` when indexing
3. Update search query to: `WHERE name LIKE ? OR author LIKE ? OR tags LIKE ?`
4. Update filter logic in `CharacterBrowserView` to check tags array

---

## Task 4: Update Plan.md

Mark tagging UI tasks as complete and add any new findings.

---

## Design System Reference

All colors and fonts are in `IKEMEN Lab/Shared/UIHelpers.swift`:

```swift
// Colors
DesignColors.zinc950  // Background (darkest)
DesignColors.zinc900  // Card backgrounds
DesignColors.zinc800  // Elevated surfaces
DesignColors.zinc700  // Borders
DesignColors.zinc400  // Secondary text
DesignColors.zinc300  // Body text

// Fonts
DesignFonts.captionMedium   // Section headers
DesignFonts.captionRegular  // Body/labels
```

---

## Files to Modify

1. `IKEMEN Lab/UI/CharacterDetailsView.swift` — Add tags section
2. `IKEMEN Lab/UI/CharacterBrowserView.swift` — Add tags to grid cards
3. `IKEMEN Lab/Core/MetadataStore.swift` — Add tags column
4. `plan.md` — Update task status

## Files to Reference (read-only)

- `IKEMEN Lab/Core/TagDetector.swift` — See how tags are detected
- `IKEMEN Lab/Models/CharacterInfo.swift` — See `inferredTags` property
- `IKEMEN Lab/Shared/UIHelpers.swift` — Design tokens
- `.github/copilot-instructions.md` — Project conventions

---

## Testing

1. Build and run the app
2. Select a character (e.g., one with "Marvel" or "KOF" in the name/author)
3. Verify tags appear in detail panel
4. Verify tags appear on grid cards
5. Search for a tag name and verify matching characters appear
