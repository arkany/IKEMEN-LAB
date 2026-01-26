# Smart Collections UI — Product Requirements Document

## Overview

Smart Collections automatically populate based on filter rules, allowing users to create dynamic collections like "Recently Added", "Marvel Characters", or "HD Stages" without manual curation.

**Core Model (Already Implemented):**
- `FilterRule` with field/comparison/value
- `SmartCollectionEvaluator` for rule evaluation
- Collection extended with `isSmartCollection`, `smartRules`, `smartRuleOperator`

---

## User Stories

### As a user, I want to...

1. **Create a smart collection** so content matching my criteria is automatically included
2. **Define multiple rules** with AND/OR logic to create precise filters
3. **Preview matches** before saving to verify my rules work correctly
4. **Edit existing smart collection rules** to refine my criteria
5. **Distinguish smart collections visually** from manual collections
6. **Convert a smart collection to manual** if I want to freeze its contents

---

## UI Components

### 1. Collection List Enhancements

**Visual Indicator for Smart Collections:**
- Use SF Symbol `sparkles` or `wand.and.stars` as icon overlay/badge
- Or show dynamic icon that pulses subtly to indicate "live" content
- Tooltip: "Smart Collection - Auto-updates based on rules"

**Context Menu Additions:**
- "Edit Rules..." (for smart collections only)
- "Convert to Manual Collection" (freezes current matches)

---

### 2. New Smart Collection Sheet

**Trigger:** "+" button in Collections → "New Smart Collection..."

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ New Smart Collection                              [X]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Name: [______________________________]                     │
│  Icon: [🎮 ▼]                                               │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Include:  [✓] Characters  [✓] Stages                       │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  Match: ( ) All rules (AND)  (•) Any rule (OR)              │
│                                                             │
│  Rules:                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Tag        ▼] [contains    ▼] [Marvel        ] [−] │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Author     ▼] [equals      ▼] [Vyn           ] [−] │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [+ Add Rule]                                               │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Preview (12 characters, 3 stages matched)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ○ Spider-Man  ○ Wolverine  ○ Iron Man  ○ Thor      │   │
│  │ ○ Captain America  ○ Hulk  ○ Black Widow  ...      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│                              [Cancel]  [Create Collection]  │
└─────────────────────────────────────────────────────────────┘
```

---

### 3. Rule Row Component

Each rule row contains:

| Element | Type | Options |
|---------|------|---------|
| Field Picker | Popup | Name, Author, Tag, Installed Date, Source Game, Is HD, Has AI, Style, Resolution |
| Comparison Picker | Popup | Varies by field type (see below) |
| Value Input | Text/Popup | Free text or predefined values |
| Remove Button | Button | "−" to delete rule |

**Comparison Operators by Field Type:**

| Field Type | Available Comparisons |
|------------|----------------------|
| Text (name, author) | equals, not equals, contains, not contains, is empty, is not empty |
| Tag | contains, not contains, is empty, is not empty |
| Boolean (isHD, hasAI) | equals (true/false picker) |
| Date (installedAt) | within last X days, before, after |
| Numeric (totalWidth) | equals, greater than, less than |

**Smart Defaults:**
- When user selects "Tag", default to "contains"
- When user selects "Is HD", show true/false toggle instead of text field
- When user selects "Installed Date", show days picker (7, 14, 30, 90, 365)

---

### 4. Preview Panel

**Real-time evaluation** as user edits rules:
- Shows count: "12 characters, 3 stages matched"
- Shows thumbnail grid of first ~20 matches
- Updates on every rule change (debounced 300ms)
- Empty state: "No content matches these rules"

---

### 5. Edit Smart Collection Sheet

**Identical to creation sheet** but:
- Pre-populated with existing rules
- Title: "Edit Smart Collection"
- Button: "Save Changes"
- Option to "Convert to Manual" (removes rules, keeps current matches)

---

## Interaction Flows

### Flow 1: Create Smart Collection

```
1. User clicks "+" in Collections sidebar
2. Menu shows: "New Collection" / "New Smart Collection..."
3. User selects "New Smart Collection..."
4. Sheet opens with empty rule
5. User enters name, adds rules
6. Preview updates in real-time
7. User clicks "Create Collection"
8. Collection appears in sidebar with sparkle indicator
9. Collection auto-populates with matching content
```

### Flow 2: Edit Smart Collection Rules

```
1. User right-clicks smart collection
2. Context menu shows "Edit Rules..."
3. Sheet opens with existing rules
4. User modifies/adds/removes rules
5. Preview shows updated matches
6. User clicks "Save Changes"
7. Collection content updates immediately
```

### Flow 3: Convert to Manual

```
1. User right-clicks smart collection
2. Selects "Convert to Manual Collection"
3. Confirmation: "This will freeze the current 15 characters and 4 stages. 
   The collection will no longer update automatically."
4. User confirms
5. Collection becomes manual (sparkle indicator removed)
6. Current matches become permanent roster
```

---

## Technical Implementation

### New Files to Create

```
IKEMEN Lab/UI/
├── SmartCollectionSheet.swift       # Main creation/edit sheet
├── RuleRowView.swift                # Individual rule row component
├── RulePreviewView.swift            # Preview grid of matches
└── SmartCollectionSheet+Helpers.swift  # Field/comparison helpers
```

### Key Classes

**SmartCollectionSheet** (NSViewController)
- Hosts the entire sheet UI
- Manages rule array state
- Calls SmartCollectionEvaluator for preview
- Creates/updates Collection via CollectionStore

**RuleRowView** (NSView)
- Field popup, comparison popup, value field
- Delegate callbacks for changes
- Adapts value input based on field type

**RulePreviewView** (NSView)
- Small collection view of matching content
- Thumbnail + name for each match
- Scrollable if many matches

### CollectionStore Extensions

```swift
extension CollectionStore {
    /// Create a new smart collection
    func createSmartCollection(
        name: String,
        icon: String,
        rules: [FilterRule],
        ruleOperator: RuleOperator,
        includeCharacters: Bool,
        includeStages: Bool
    ) -> Collection
    
    /// Update smart collection rules
    func updateSmartCollectionRules(
        _ collectionId: UUID,
        rules: [FilterRule],
        ruleOperator: RuleOperator
    )
    
    /// Convert smart collection to manual
    func convertToManualCollection(_ collectionId: UUID)
}
```

---

## Design Specifications

### Colors & Styling

- Follow existing dark theme (DesignColors)
- Rule rows: `cardBackground` with `borderSubtle`
- Add button: `textSecondary`, hover `textPrimary`
- Remove button: `negative` on hover
- Preview panel: Slightly darker `zinc900` background

### Spacing

- Sheet width: 560px
- Sheet min-height: 400px
- Rule row height: 44px
- Rule row spacing: 8px
- Preview thumbnail size: 48x48
- Padding: 20px throughout

### Typography

- Title: `DesignFonts.heading(size: 16)`
- Labels: `DesignFonts.label(size: 12)`
- Field text: `DesignFonts.body`
- Preview count: `DesignFonts.label(size: 11)` secondary color

---

## Preset Smart Collections (Future)

Offer one-click templates:

| Preset | Rules |
|--------|-------|
| Recently Added | installedAt within 7 days |
| HD Characters | isHD equals true |
| Characters with AI | hasAI equals true |
| [Source Game] | sourceGame equals "[game]" |
| By Author | author contains "[name]" |

---

## Edge Cases

1. **No rules defined** → Include all content (warn user)
2. **Rules match nothing** → Show empty state, allow save anyway
3. **Field not applicable** → Stage-only fields ignored for character evaluation
4. **Deleted content** → Automatically removed from smart collection results
5. **New content added** → Automatically evaluated and included if matches

---

## Accessibility

- All controls keyboard navigable
- VoiceOver labels for rule components
- Focus ring on active rule row
- Escape key closes sheet (with confirmation if unsaved changes)

---

## Success Metrics

- Users create at least one smart collection
- Smart collections are activated (not just created)
- Reduction in manual collection curation time
- Feature discovery via "+" menu

---

## Implementation Phases

### Phase 1: Core UI (MVP)
- [ ] SmartCollectionSheet with basic layout
- [ ] RuleRowView with all field types
- [ ] Real-time preview
- [ ] Create smart collection flow

### Phase 2: Edit & Convert
- [ ] Edit existing smart collection
- [ ] Convert to manual collection
- [ ] Context menu integration

### Phase 3: Polish
- [ ] Preset templates
- [ ] Animations and transitions
- [ ] Keyboard shortcuts
- [ ] Empty state illustrations
