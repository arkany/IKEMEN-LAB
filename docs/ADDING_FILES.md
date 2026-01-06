# Setup Instructions for New Files

## Important: Adding New Swift Files to Xcode Project

After pulling the latest changes, you need to manually add the new Swift files to your Xcode project:

### New Files Added
1. `IKEMEN Lab/Models/CollectionInfo.swift`
2. `IKEMEN Lab/UI/CollectionsBrowserView.swift`

### Steps to Add Files

1. **Open the project in Xcode**
   ```bash
   open "IKEMEN Lab.xcodeproj"
   ```

2. **Add the Models file**
   - In Xcode's Project Navigator (left sidebar), expand the "IKEMEN Lab" group
   - Right-click on the "Models" folder
   - Select "Add Files to IKEMEN Lab..."
   - Navigate to `IKEMEN Lab/Models/`
   - Select `CollectionInfo.swift`
   - **Important**: Uncheck "Copy items if needed" (file is already in the right place)
   - Ensure "IKEMEN Lab" target is selected
   - Click "Add"

3. **Add the UI file**
   - Right-click on the "UI" folder
   - Select "Add Files to IKEMEN Lab..."
   - Navigate to `IKEMEN Lab/UI/`
   - Select `CollectionsBrowserView.swift`
   - **Important**: Uncheck "Copy items if needed"
   - Ensure "IKEMEN Lab" target is selected
   - Click "Add"

4. **Build the project**
   ```
   Product → Build (⌘B)
   ```

5. **Verify**
   - Both files should appear in the Project Navigator
   - Build should succeed with no errors
   - The Collections tab should appear in the left sidebar when you run the app

### If You See Build Errors

If you get compilation errors about missing files:
- Clean the build folder: Product → Clean Build Folder (⌘⇧K)
- Ensure the files are in the correct locations:
  - `IKEMEN Lab/Models/CollectionInfo.swift`
  - `IKEMEN Lab/UI/CollectionsBrowserView.swift`
- Check that both files are added to the IKEMEN Lab target (check File Inspector in Xcode)

### Alternative: Use Terminal

If you prefer command-line tools:

```bash
cd "/path/to/IKEMEN-LAB"

# Check files exist
ls -la "IKEMEN Lab/Models/CollectionInfo.swift"
ls -la "IKEMEN Lab/UI/CollectionsBrowserView.swift"

# Open Xcode and add manually (no command-line alternative for adding to .xcodeproj)
open "IKEMEN Lab.xcodeproj"
```

## Why Manual Addition is Needed

Xcode project files (`.pbxproj`) are complex XML-based property lists that track all source files, build phases, and dependencies. While we can create source files directly, modifying the project file programmatically is error-prone and can corrupt the project. Therefore, adding files through Xcode's interface is the recommended approach.

## What's New

These files implement the Collections system:
- **CollectionInfo.swift**: Data models for collections and collection items
- **CollectionsBrowserView.swift**: UI for browsing and creating collections
- **MetadataStore updates**: Database support for storing collections
- **GameWindowController updates**: Navigation integration

See [`docs/COLLECTIONS.md`](docs/COLLECTIONS.md) for full documentation.
