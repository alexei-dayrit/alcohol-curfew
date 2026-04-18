# SoberCurfew — Feature Status

## Working

| Feature | Notes |
| --- | --- |
| Widmark BAC Engine | Original baseline: `[A / (W × r)] − (β × t)`, sex-based r-factors |
| **Piecewise Absorption Model** | **NEW** — replaces instant-spike Widmark. Each drink has a rising phase (linear over `T_abs`) then a falling phase. Eliminates the "BAC spikes the moment you log" artifact. |
| **Watson TBW / Volume of Distribution** | **NEW** — when height + age are set in profile, uses Watson formula instead of Widmark r-factor. Falls back to Widmark automatically if fields are blank. |
| **Variable Elimination Rate** | **NEW** — Standard 0.015 / Moderate 0.017 / High 0.020 g/dL·hr, set in profile. |
| **Food State Absorption Modifier** | **NEW** — Empty (30 min to peak) / Light (45 min) / Full (75 min). Set as session default in profile, overridable per-drink in Ultra mode. |
| **Carbonation Modifier** | **NEW** — Carbonated drinks reduce `T_abs` by 25% (faster absorption). Ultra mode toggle per drink. |
| **Retroactive Logging Offset** | **NEW** — `timestampOffsetSec` on DrinkEntry. Quick mode "15 min / 30 min / 1 hr" shifts `effectiveTimestamp` back so math honours when the drink was actually consumed. |
| **Ultra Log Mode** | **NEW** — Existing presets grid + per-drink Carbonated toggle + food state override. |
| **Quick Log Mode** | **NEW** — Segmented control in Add Drink sheet. 2×2 category grid (Beer/Wine/Shot/Cocktail) → S/M/L size → relative time offset → LOG IT. No numbers needed. |
| **Ascending Limb Indicator** | **NEW** — "Still absorbing · BAC still rising" amber banner on dashboard while any drink is within its `T_abs` window. Gauge ring and dot also shift from amber → red. |
| **Legal Limit Ticks on Gauge** | **NEW** — Small colored dots on the ring arc at 0.05 (yellow, EU/AU) and 0.08 (red, US). Positioned relative to peak BAC. |
| **Widget App Group Bridge** | **NEW** — Dashboard writes BAC + soberTime + impact to `UserDefaults(suiteName: "group.com.sobercurfew.app")` on every 30 s refresh. Widget reads from same container instead of returning hardcoded `.clear`. |
| **Ultra Calibration Card in Profile** | **NEW** — Height slider (cm + ft/in display), age stepper, body composition (Athletic/Average/Sedentary), tolerance level, session food state. |
| ZeroLine Countdown | Animated ring, updates every 30 s, forward-scan `timeToZero` (5 min steps) correctly handles still-absorbing drinks |
| Drink Logging | 6 presets + manual entry, all persisted to SwiftData with new fields |
| HealthKit Sync | Reads weight + biological sex, writes BAC samples |
| Disclaimer Gate | First-launch gate on `hasAcceptedDisclaimer` |
| Dashboard / Bento Grid | All stat tiles show real data; last drink uses `effectiveTimestamp` |
| Sleep Impact Score | 3-tier logic (optimal / reduced / disrupted) wired to bedtime + BAC |
| Sleep Curfew Timeline | Visual timeline bar with bedtime marker, alcohol window, zones legend |
| Profile & Settings | All fields persist to SwiftData including new Ultra calibration fields |
| Apple Watch App | Mini ZeroLine gauge + BAC display, synced via CloudKit |
| Navigation | All routes wired and functional |
| Theme / Design Tokens | Full color system in `Color+Theme.swift` |
| SwiftData + CloudKit | Schema configured; new model fields have inline defaults for automatic lightweight migration |

---

## Broken / Incomplete

| Feature | Status | What's Missing |
| --- | --- | --- |
| Hydration Reminders | Not started | No `UserNotifications` integration, no scheduling logic |
| HealthKit BAC Write | Wired but not called | `writeBACSample()` exists in `HealthKitManager` but is never invoked after a drink is logged |
| Watch App Absorbing State | Not shown | Watch `WatchView` doesn't display the ascending limb indicator (low priority) |

---

## Branch: `feat/dual-mode-bac-engine`

**Commit:** `459c4ee` — feat: dual-mode BAC engine with piecewise absorption model

### Files Changed

| File | Change |
| --- | --- |
| `SoberCurfew/Models/UserProfile.swift` | Added `heightCm`, `age`, `BodyComposition`, `ToleranceLevel`, `FoodState` enums + `watsonTBW` / `volumeOfDistribution` computed props |
| `SoberCurfew/Models/DrinkEntry.swift` | Added `isCarbonated`, `timestampOffsetSec`, `foodStateAtTime`, `effectiveTimestamp`, `absorptionHours` |
| `SoberCurfew/Managers/MetabolismManager.swift` | Rewrote `currentBAC` (piecewise model), `timeToZero` (forward scan), added `isAbsorbing` |
| `SoberCurfew/Views/Profile/ProfileView.swift` | Added Ultra Calibration card, save/load for new fields |
| `SoberCurfew/Views/AddDrink/AddDrinkView.swift` | Full rewrite — segmented Ultra/Quick control, Quick tab with category grid + size + time offset |
| `SoberCurfew/Views/Dashboard/DashboardView.swift` | Added absorbing banner, App Group write in `refreshBAC()` |
| `SoberCurfew/Views/Dashboard/ZeroLineGaugeView.swift` | Legal limit ticks, absorbing color state, ascending limb subtitle |
| `SoberCurfewWidget/SoberCurfewWidget.swift` | `buildEntry()` reads from App Group instead of hardcoded `.clear` |
| `SoberCurfewWidget/SoberCurfewWidget.entitlements` | Created — App Group entitlement for widget |
| `project.yml` | Widget entitlements path + App Group property added |

### SwiftData Migration Note
All new `@Model` fields have **inline default values with fully qualified type names** (e.g. `FoodState.light` not `.light`). This satisfies SwiftData's `@Model` macro requirement and enables automatic lightweight migration — no migration plan file needed. If the simulator has an old schema (pre-branch), **uninstall the app** before reinstalling to clear the store.

---

## Pre-Launch Checklist

- Set Development Team in Xcode for all 3 targets (iOS, Watch, Widget)
- Enable HealthKit capability in iOS target
- Confirm CloudKit capability is enabled (or remove for local-only mode)
- Test HealthKit read/write on real device (simulator won't work)
- Test CloudKit sync between iPhone and Watch
- Verify widget renders live BAC (App Group now wired — should work after first refresh)
- Wire `writeBACSample()` call after drink is logged
- QA Quick mode with all 4 categories, 3 sizes, 4 time offsets
- QA Ultra mode: carbonated toggle, food state override, manual entry
- QA Profile Ultra Calibration: Watson vs Widmark path (with/without height+age)
