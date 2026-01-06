# Screenpack Promo Card — Design Plan

## Overview
A dismissible promotional card on the Dashboard that highlights new/recommended screenpacks.

## The Core Problem
There's no centralized API for "what screenpacks exist." The MUGEN/IKEMEN community is fragmented across:
- **MUGEN Archive** (mugenarchive.com) — largest, but requires login, no public API
- **MUGEN Free For All** (mugenfreeforall.com) — forum-based
- **GitHub** — some creators host there
- **Individual sites** — many creators have personal pages

## Data Source Options

| Option | Pros | Cons |
|--------|------|------|
| **A. Curated JSON hosted by us** | Full control, reliable, no scraping | Manual maintenance, becomes stale |
| **B. Scrape community sites** | Real-time data | Fragile, TOS issues, needs constant maintenance |
| **C. GitHub releases only** | API available, stable | Limited to GitHub-hosted screenpacks |
| **D. User-submitted feed** | Community-driven | Needs moderation, infrastructure |
| **E. Skip promos, focus on discovery** | No maintenance burden | Less "alive" feeling |

## Recommended Approach: Hybrid (A + C)

1. **Curated JSON file** hosted on GitHub (or bundled in app updates):
   ```json
   {
     "featured": [
       {
         "id": "screenpack-mugen-megamix",
         "name": "MUGEN Megamix: Black Edition",
         "author": "Devon",
         "version": "8.0",
         "slots": 60,
         "resolution": "1280x720",
         "downloadUrl": "https://...",
         "previewImageUrl": "https://...",
         "description": "Heavy on animation frames...",
         "tags": ["HD", "large-roster"]
       }
     ],
     "lastUpdated": "2026-01-04"
   }
   ```

2. **Check for updates** on app launch (or weekly) by fetching this JSON
3. **Compare to installed screenpacks** — only show promo if user doesn't have it
4. **Multiple promos** → Rotate through them, or show "X new screenpacks available" with browse action

## UI Behavior

| Scenario | Behavior |
|----------|----------|
| No new screenpacks | Card hidden |
| 1 new screenpack | Show promo card with name, preview, "Install" button |
| Multiple new | Show "3 new screenpacks" with "Browse" button → opens Screenpack browser filtered |
| User dismisses | Remember dismissal per screenpack ID (UserDefaults) |
| User installs | Remove from promo, mark as installed |

## Promo Card Design

```
┌─────────────────────────────────────────────────────┐
│ 🎨 NEW SCREENPACK                              [×] │
├─────────────────────────────────────────────────────┤
│  ┌──────────┐                                      │
│  │ Preview  │  MUGEN Megamix: Black Edition       │
│  │  Image   │  by Devon · 60 slots · 1280×720     │
│  │          │                                      │
│  └──────────┘  [View Details]  [Install]          │
└─────────────────────────────────────────────────────┘
```

## Implementation Steps

1. **Create `ScreenpackFeed.swift`** — Model for JSON feed, fetch logic
2. **Add `screenpack-feed.json`** — Start with bundled file, later host remotely
3. **Add promo card UI** to DashboardView
4. **Track dismissed promos** in UserDefaults
5. **Optional: GitHub releases check** — For screenpacks hosted on GitHub

## Open Questions

1. **Where to host the JSON?** GitHub raw file? Your own domain? Bundled only?
2. **How often to check?** App launch? Daily? Weekly with cache?
3. **Who curates the list?** You manually? Community submissions?
4. **Should this extend to characters/stages too?** ("5 new Marvel characters this week")

## MVP Recommendation

**Start simple:**
- Bundle a static `featured-screenpacks.json` in the app
- Show promo card for screenpacks user doesn't have installed
- Dismissible (stored in UserDefaults)
- Update the JSON with each app release

**Later (v2+):**
- Host JSON remotely for live updates
- Add character/stage promos
- Community submission system
