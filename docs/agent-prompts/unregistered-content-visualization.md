# Task: Visualize Unregistered Content in Character/Stage Browsers

## Context
IKEMEN Lab is a macOS-native content manager for IKEMEN GO. Characters and stages can exist on disk (in `chars/` and `stages/` folders) but not be registered in `select.def`. Currently, the app shows ALL content found on disk, but users can't tell which items are actually playable in-game vs. which are "orphaned" files.

## Objective
Add visual indicators to distinguish between:
1. **Registered content** - Listed in select.def, will appear in-game
2. **Unregistered content** - Exists on disk but NOT in select.def, won't appear in-game

## Technical Requirements

### 1. Extend ContentManager to Track Registration Status
Location: `IKEMEN Lab/Core/ContentManager.swift`

Add method to check if a character/stage is registered:
```swift
func isCharacterRegistered(_ folderName: String) -> Bool
func isStageRegistered(_ defPath: String) -> Bool
```

This requires parsing `select.def` (located at `{ikemenPath}/data/select.def`) to extract:
- Character entries: Lines like `kfm, random, order=1` or `chars/Ryu/Ryu.def`
- Stage entries: Lines in `[ExtraStages]` section

### 2. Add Registration Status to Models
Location: `IKEMEN Lab/Models/CharacterInfo.swift` and `StageInfo.swift`

Add property:
```swift
var isRegistered: Bool = true  // Default true, updated during scan
```

### 3. Update MetadataStore to Track Registration
Location: `IKEMEN Lab/Core/MetadataStore.swift`

Add `isRegistered` column to the database schema (with migration).

### 4. Visual Indicators in Grid View
Location: `IKEMEN Lab/UI/CharacterBrowserView.swift`

For unregistered characters, add:
- Semi-transparent overlay (50% opacity) on the card
- Small "unregistered" badge or icon (e.g., a slash-circle icon)
- Tooltip explaining "Not in select.def - won't appear in game"

Use existing design tokens from `DesignColors` and `DesignFonts` in UIHelpers.swift.

### 5. Visual Indicators in List View
For list view rows, show:
- Dimmed text (use `DesignColors.textSecondary` instead of `textPrimary`)
- Status column or icon indicating unregistered state

### 6. Filter Options
Add filter to CharacterBrowserView toolbar:
- "All" (default)
- "Registered Only"  
- "Unregistered Only"

This helps users quickly find orphaned content to either register or delete.

### 7. Context Menu Action
Add right-click option for unregistered content:
- "Add to select.def" - Registers the character/stage

## Files to Modify
1. `IKEMEN Lab/Core/ContentManager.swift` - Add registration checking
2. `IKEMEN Lab/Core/MetadataStore.swift` - Add isRegistered column + migration
3. `IKEMEN Lab/Models/CharacterInfo.swift` - Add isRegistered property
4. `IKEMEN Lab/Models/StageInfo.swift` - Add isRegistered property
5. `IKEMEN Lab/UI/CharacterBrowserView.swift` - Grid/list visual indicators + filter
6. `IKEMEN Lab/UI/StageBrowserView.swift` - Same visual treatment

## Design Reference
- Use `DesignColors.zinc700` for dimmed/unregistered state
- Badge style should match existing tag badges (see CharacterDetailsView)
- Filter dropdown should match existing view mode toggle style

## Testing
1. Create a character folder in `chars/` but don't add to select.def
2. Verify it appears with unregistered visual treatment
3. Use "Add to select.def" context action
4. Verify visual treatment updates to registered state
5. Test filter toggles work correctly

## Safety Rules
- Never auto-delete unregistered content
- Always show unregistered content by default (don't hide it)
- Backup select.def before any modifications
