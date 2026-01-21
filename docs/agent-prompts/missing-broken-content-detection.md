# Task: Complete Missing & Broken Content Detection for IKEMEN Lab

## Context
IKEMEN Lab is a macOS-native content manager for IKEMEN GO (fighting game engine). We've already implemented detection of **active**, **unregistered**, and **disabled** content by comparing the filesystem against `select.def`. 

Now we need to complete the content status model by detecting:
1. **Missing** content — listed in `select.def` but folder/files don't exist
2. **Broken** content — folder exists but .def file is missing or invalid

## Current State

### ContentStatus enum (already exists)
Location: `IKEMEN Lab/Models/CharacterInfo.swift`
```swift
public enum ContentStatus: String, Codable, Hashable, Sendable {
    case active = "active"
    case unregistered = "unregistered"
    case missing = "missing"
    case broken = "broken"
    case duplicate = "duplicate"
    case disabled = "disabled"
}
```

### Current detection logic
Location: `IKEMEN Lab/Core/EmulatorBridge.swift`

`loadCharacters()` (around line 340-440):
- Parses select.def to get `activeSet`, `disabledSet`, and `selectDefOrder`
- Scans `chars/` folder for valid character directories
- Sets status based on whether the folder matches activeSet/disabledSet
- **Gap**: Only processes folders that exist; doesn't detect entries in select.def with no folder

`loadStages()` (around line 460-550):
- Similar pattern for stages in `stages/` folder
- **Same gap**: Doesn't detect missing entries

## Requirements

### 1. Detect Missing Characters
Modify `loadCharacters()` in EmulatorBridge.swift to:

1. After scanning filesystem, iterate through `activeSet` and `disabledSet`
2. For each entry, check if we found a matching character in `foundCharacters`
3. If NOT found, create a "ghost" CharacterInfo with status = `.missing`
4. The ghost entry should have:
   - `id`: the select.def entry path
   - `name`/`displayName`: extracted from the path (e.g., "kfm" from "kfm/kfm.def")
   - `status`: `.missing`
   - `defFile`: constructed URL (even though it doesn't exist)
   - `directory`: constructed URL
   
CharacterInfo may need a new initializer for missing content since the normal init parses the .def file.

### 2. Detect Missing Stages
Same pattern for `loadStages()`:
- Check stage entries in select.def against found stages
- Create ghost StageInfo entries for missing ones

### 3. Detect Broken Characters
In `loadCharacters()`, when scanning character directories:

1. If a directory exists but has NO valid .def file, mark as `.broken`
2. Currently, such directories are silently skipped
3. Instead, create a CharacterInfo with status = `.broken`

### 4. Detect Broken Stages  
Same for stages — if a stage entry points to a folder with no valid .def file.

### 5. UI Treatment
Location: `IKEMEN Lab/UI/CharacterBrowserView.swift` and `StageBrowserView.swift`

For **missing** content:
- Red overlay/badge (use DesignColors.red500 or similar)
- Tooltip: "Folder not found - remove from select.def?"
- Context menu: "Remove from select.def"

For **broken** content:
- Yellow/amber overlay/badge (use DesignColors.amber500 or similar)  
- Tooltip: "Invalid or missing .def file"
- Context menu: "Reveal in Finder" (so user can fix)

### 6. Context Menu Actions
Add to both browsers:

For `.missing` status:
```swift
menu.addItem(withTitle: "Remove from select.def", action: #selector(removeFromSelectDef), ...)
```

Implement `removeFromSelectDef` in ContentManager:
- Parse select.def
- Comment out or remove the line for this entry
- Backup before modifying (already pattern exists)
- Refresh content

### 7. Filter Updates
Update the filter dropdown to include:
- "Missing Only" 
- "Broken Only"
- Or add to existing "Issues" filter if one exists

## Files to Modify

1. **IKEMEN Lab/Core/EmulatorBridge.swift**
   - `loadCharacters()` — add missing/broken detection
   - `loadStages()` — add missing/broken detection
   
2. **IKEMEN Lab/Models/CharacterInfo.swift**
   - Add convenience initializer for missing/broken content
   
3. **IKEMEN Lab/Models/StageInfo.swift**
   - Add convenience initializer for missing/broken content
   
4. **IKEMEN Lab/Core/ContentManager.swift**
   - Add `removeFromSelectDef(characterPath:)` method
   - Add `removeFromSelectDef(stagePath:)` method
   
5. **IKEMEN Lab/UI/CharacterBrowserView.swift**
   - Add visual indicators for missing/broken
   - Add filter options
   - Add context menu actions
   
6. **IKEMEN Lab/UI/StageBrowserView.swift**
   - Same visual treatment

7. **IKEMEN Lab/Shared/UIHelpers.swift**
   - Add filter enum cases if needed: `.missingOnly`, `.brokenOnly`
   - Add any new design colors for error states

## Design Tokens
Use existing DesignColors from UIHelpers.swift:
- Look for existing error/warning colors, or add:
  - `DesignColors.errorBadge` for missing (red)
  - `DesignColors.warningBadge` for broken (amber/yellow)

## Testing
1. Remove a character folder that's listed in select.def → should show as "Missing"
2. Create a character folder with no .def file → should show as "Broken"
3. Test "Remove from select.def" action on missing content
4. Verify filters work correctly
5. Verify existing active/unregistered/disabled detection still works

## Safety Rules
- NEVER auto-delete any content
- ALWAYS backup select.def before modifying
- Missing content should be prominently visible, not hidden
- Actions should be explicit user choices

## Reference Files
- See `docs/existing-installation-import.md` for full spec
- See existing unregistered visual treatment in CharacterBrowserView.swift as pattern
- See `ContentManager.swift` for select.def backup pattern
