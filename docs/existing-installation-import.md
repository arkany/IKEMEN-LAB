# Existing Installation Import Strategy

When IKEMEN Lab connects to an existing IKEMEN GO folder with content already installed.

## Phase 1: Read-Only Discovery

| Step | Action | Notes |
|------|--------|-------|
| Scan chars/ folder | Index all .def files, extract metadata | No modifications |
| Scan stages/ folder | Index all stage .def files | No modifications |
| Parse select.def | Read current roster order, slot positions | Preserve exactly |
| Detect screenpack | Identify active screenpack, grid dimensions | For capacity warnings |
| Hash existing files | Generate checksums for duplicate detection | Compare NEW content only |
| Store "baseline" state | Snapshot of folder structure + select.def | For diff comparison |

## Phase 2: Non-Destructive Cataloging

- Index **unregistered** content (chars/stages not in select.def) → show in "Unregistered" tab
- Detect potential issues (missing .sff, broken paths) → show as warnings, don't auto-fix
- Identify naming convention user prefers (snake_case, lowercase, etc.) → match for new installs
- Flag potential duplicates → inform user, let them decide

## Phase 3: User-Controlled Actions

| Feature | Behavior | Safety |
|---------|----------|--------|
| Add new character | Append to select.def only | Never reorder existing |
| "Register untracked" | Add existing chars to select.def | User picks which ones |
| "Find duplicates" | Show comparison UI | User confirms removal |
| "Cleanup names" | Offer rename suggestions | Opt-in per-item, backup first |
| "Optimize roster" | Suggest reordering | Preview changes, one-click revert |

## Key Safety Rails

1. **Never auto-delete** — Duplicates shown for review, user must confirm
2. **Never auto-rename** — Suggest only; renaming can break .def references
3. **Never reorder select.def** — Existing roster order is sacred; only append
4. **Backup select.def** — Create `select.def.backup` before any modification
5. **"Dry run" mode** — Preview all changes before applying
6. **Undo stack** — Track recent changes, allow rollback

## Edge Cases

- Characters in select.def but folder deleted → Mark as "Missing" (red badge)
- Multiple .def files in same folder → Let user pick which to register
- Custom folder structure (e.g., `chars/Marvel/Cyclops/`) → Preserve paths exactly
- select.def uses relative vs absolute paths → Match existing style
- Screenpack at capacity → Warn before adding, don't silently fail

## Content Status Model

Every character/stage has a **status** derived from comparing filesystem vs select.def:

| Status | Meaning |
|--------|---------|
| ✅ Active | In select.def AND folder exists AND files valid |
| 📁 Unregistered | Folder exists BUT not in select.def |
| ❌ Missing | In select.def BUT folder/files not found |
| ⚠️ Broken | In select.def, folder exists, but .def invalid |
| 🔄 Duplicate | Same character exists in multiple locations |

## UI Treatment

- **Active** → Normal display, fully functional
- **Unregistered** → Shown in separate tab/filter, "Register" button available
- **Missing** → Red badge, "Remove from roster" or "Locate folder" options
- **Broken** → Yellow badge, shows specific error, "Attempt repair" option
- **Duplicate** → Orange badge, "Compare versions" action
