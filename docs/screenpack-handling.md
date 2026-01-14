# Screenpack Handling Strategy

Screenpacks are complex — they define the entire UI theme and often have specific setup requirements.

## What Screenpacks Typically Contain

```
data/MyScreenpack/
├── system.def          # Main definition (rows, columns, fonts, sounds)
├── system.sff          # Sprites for menus, select screen
├── system.snd          # UI sounds
├── fight.def           # Lifebar/HUD definition
├── fight.sff           # Lifebar sprites
├── fight.snd           # Fight sounds (round call, KO, etc.)
├── select.def          # Optional custom roster (⚠️ may override user's)
├── fightfx.air/.sff    # Hit sparks, effects
├── readme.txt          # CRITICAL: Setup instructions
└── fonts/              # Custom fonts
```

## Why Screenpacks Are Tricky

1. **May include their own select.def** — Could override user's character roster
2. **Often require specific folder structure** — `data/screenpack_name/` expected
3. **May reference absolute paths** — Breaks if installed in wrong location
4. **Font dependencies** — May require fonts in specific locations
5. **Character slot limits** — `rows × columns` defines max characters shown

## Our Approach

| Scenario | Behavior |
|----------|----------|
| Screenpack has readme.txt | **Show in detail panel** before activation |
| Screenpack has select.def | **Warn user**: "This screenpack includes its own roster (X chars). Your current roster (Y chars) will be preserved." |
| Screenpack includes fonts | Auto-detect font/ folder, show in components list |
| Slot limit exceeded | **Warn**: "Your roster has 145 chars but this screenpack shows max 60. Consider [Large screenpack] instead." |
| Activation requested | Preview changes in "dry run" mode, backup config.json first |

## Screenpack Detail Panel

Should show:
- Name, author, resolution (from system.def `[Info]` section)
- Components included (lifebars, select screen, etc.)
- **Character slots**: "60 slots (5×12)" parsed from `rows` × `columns`
- **README contents** (scrollable, if readme.txt exists)
- **Warnings** if slot limit < current roster size
- "Activate" button with confirmation
