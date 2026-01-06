# Collections System

## Overview

The Collections system allows users to create named groups (e.g., "Marvel", "SNK Bosses") to organize characters, stages, and screenpacks.

## Architecture

### Models

- **CollectionInfo** (`Models/CollectionInfo.swift`)
  - Represents a collection with ID, name, description, and items
  - Supports character, stage, and screenpack items
  - Provides helper methods for managing items

- **CollectionItem** and **CollectionItemType**
  - Represents an item within a collection
  - Type-safe enum for item types

### Database

Collections are stored in SQLite via MetadataStore:

- **collections** table
  - id (primary key)
  - name, description
  - createdAt, updatedAt

- **collection_items** table (junction table)
  - collectionId (foreign key)
  - itemId, itemType
  - addedAt
  - Composite primary key on (collectionId, itemId, itemType)

### UI Components

- **CollectionsBrowserView** (`UI/CollectionsBrowserView.swift`)
  - Lists all collections in card format
  - Shows item counts and descriptions
  - "New Collection" button to create collections
  - Empty state handling

- **Navigation**
  - Added "Collections" nav item to left sidebar
  - Shows count badge with number of collections
  - Icon: folder.fill (SF Symbol)

## Usage

### Creating a Collection

1. Navigate to Collections in the left sidebar
2. Click "New Collection" button
3. Enter name (required) and description (optional)
4. Click "Create"

### Viewing Collections

Collections are displayed as cards showing:
- Collection name
- Item summary (e.g., "5 characters, 3 stages")
- Description (if provided)

## Database Operations

```swift
// Create a collection
let collection = try MetadataStore.shared.createCollection(
    name: "Marvel Characters",
    description: "Characters from Marvel universe"
)

// Add an item to a collection
try MetadataStore.shared.addItemToCollection(
    collectionId: collection.id,
    itemId: "ryu",
    itemType: .character
)

// Get all collections
let collections = try MetadataStore.shared.allCollections()

// Search collections
let results = try MetadataStore.shared.searchCollections(query: "marvel")
```

## Future Enhancements

### In Progress
- [ ] CollectionDetailsView - view and manage items within a collection
- [ ] Context menu integration - "Add to Collection" in character/stage/screenpack browsers
- [ ] Collection editing - rename, change description, delete
- [ ] Item removal from collections

### Planned
- [ ] Collection export/import
- [ ] Smart collections based on filters
- [ ] Collection sharing
- [ ] Nested collections
- [ ] Collection icons/colors
- [ ] Drag and drop to add items to collections

## Files Added

- `IKEMEN Lab/Models/CollectionInfo.swift` - Collection models
- `IKEMEN Lab/UI/CollectionsBrowserView.swift` - Collections browser UI
- Updated `IKEMEN Lab/Core/MetadataStore.swift` - Database operations
- Updated `IKEMEN Lab/App/GameWindowController.swift` - Navigation integration

## Notes

**Important**: The new Swift files need to be added to the Xcode project manually:
1. Open the project in Xcode
2. Right-click on the appropriate group (Models or UI)
3. Select "Add Files to IKEMEN Lab..."
4. Select the new files
5. Ensure "Copy items if needed" is unchecked
6. Ensure the IKEMEN Lab target is selected
