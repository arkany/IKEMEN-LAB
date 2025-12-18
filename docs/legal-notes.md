# Legal Notes

Deep-dive on licensing, App Store policy, and liability considerations for the macOS MAME project.

---

## MAME Licensing

### License Structure

MAME uses a **dual-license** approach:

1. **GPL-2.0** (primary): Most of the codebase
2. **BSD-3-Clause**: Some individual drivers and components

The practical effect: any binary distribution that links MAME code must comply with GPL-2.0.

### GPL-2.0 Compliance Requirements

| Requirement | How We Comply |
|-------------|---------------|
| Source availability | Host full source on GitHub; link in app's About screen |
| License notice | Include `COPYING` file in app bundle |
| Modification disclosure | All changes to MAME core tracked in git |
| No additional restrictions | Do not add proprietary license terms |

### What GPL-2.0 Does NOT Require

- ❌ Making the app free (can charge on App Store)
- ❌ Open-sourcing non-MAME parts (though recommended for simplicity)
- ❌ Assigning copyright to MAME project

### Recommended Approach

**Open-source the entire macOS shell** under GPL-2.0 or MIT:
- Simplifies compliance
- Builds community trust
- Aligns with preservation ethos

---

## Apple App Store Policy

### Emulator Policy (Updated April 2024)

Apple's App Store Review Guidelines §4.7 now explicitly permits emulators:

> "Retro game console and PC emulator apps can offer to download games."

**Key conditions**:
1. Developer is responsible for all software offered
2. Software must comply with Guidelines and laws
3. Software must not enable piracy of copyrighted content
4. Users must be clearly informed they're downloading from the developer

### How This Applies to MAME

| Apple's Condition | Our Approach |
|-------------------|--------------|
| Developer responsible | We don't host/distribute ROMs; user provides their own |
| Comply with laws | No copyrighted content bundled; GPL compliance |
| No piracy enablement | No ROM links; clear "legal ownership" messaging |
| User informed | Onboarding explains user supplies game files |

### App Review Risk Factors

**Lower risk**:
- Emulator-only app (no content)
- Clear "bring your own games" messaging
- Open-source codebase
- No network features for ROM sharing

**Higher risk** (avoid):
- Links to ROM sites
- In-app ROM browser/search
- Multiplayer/sharing features
- Ambiguous language about game sources

---

## BIOS & Firmware Liability

### The Problem

Many arcade systems (and consoles) require BIOS/firmware files to run. These are copyrighted by the original manufacturers.

### Legal Status

| Content Type | Bundling Allowed? | Notes |
|--------------|-------------------|-------|
| MAME source code | ✓ | GPL-2.0 |
| Arcade game ROMs | ✗ | Copyrighted; user must own |
| System BIOS files | ✗ | Copyrighted; user must own |
| Homebrew games | ✓ | With author permission |
| Public domain games | ✓ | Verify PD status |

### Safe Approach for BIOS

1. **Never bundle** BIOS files in the app
2. **Never link** to BIOS download sites
3. **Document requirements** clearly:
   - "This system requires firmware file X (SHA1: abc123)"
   - Link to mamedev.org documentation
4. **Provide UI** for users to add their own files via file picker
5. **Validate files** by SHA1 hash (UX improvement, not piracy assistance)

### Example UI Copy

> **System Files Required**
> 
> Some games need system firmware to run. You can add these files in Preferences → Firmware & BIOS.
> 
> [Learn more at mamedev.org](https://www.mamedev.org/)

---

## Trademark Considerations

### MAME Trademark

"MAME" is a trademark of the MAME team. Usage guidelines:

- ✓ "Powered by MAME" (attribution)
- ✓ "Built on MAME" (factual)
- ✗ "MAME for Mac" (implies official)
- ✗ Using MAME logo without permission

### Arcade Game Trademarks

- Do NOT use game names/logos in marketing
- Do NOT show copyrighted game screenshots in App Store listing
- Use generic/placeholder art in promotional materials
- User's own library can show game art (fair use for personal organization)

### Recommended App Name

Avoid "MAME" in the app name. Consider:
- Descriptive: "Arcade Player" / "Retro Arcade"
- Abstract: "[Your Name] Arcade"
- Technical: "ArcadeCore"

---

## Data Privacy

### What Data We Collect

| Data Type | Collected? | Purpose |
|-----------|------------|---------|
| Game library metadata | Local only | Library organization |
| Play history | Local only | "Recently Played" |
| Crash reports | Opt-in | Debugging |
| Usage analytics | Opt-in | Feature prioritization |

### GDPR/Privacy Considerations

- No account required
- No server-side data storage
- iCloud sync is Apple's infrastructure (user's own account)
- Privacy Policy required for App Store (template in deliverables)

---

## Summary Checklist

### Before App Store Submission

- [ ] GPL-2.0 compliance verified
- [ ] Source code publicly available
- [ ] No bundled ROMs or BIOS
- [ ] No links to ROM/BIOS download sites
- [ ] Clear "user provides game files" messaging
- [ ] Privacy Policy published
- [ ] App name doesn't infringe trademarks
- [ ] No copyrighted screenshots in listing

---

## References

- [MAME License FAQ](https://www.mamedev.org/legal.html)
- [GPL-2.0 Full Text](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
- [Apple App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple's April 2024 Emulator Policy Update](https://developer.apple.com/news/?id=0kjli9o1)
