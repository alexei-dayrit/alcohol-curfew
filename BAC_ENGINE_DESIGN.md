# SoberCurfew: Dual-Mode BAC Engine — Design Document

## Context
The app currently implements a standard Widmark formula (`MetabolismManager.swift`) with sex-based r-factors and **instant absorption** — every drink spikes BAC immediately at log time. The goal is to introduce two calculation modes — **Ultra** (high accuracy, configured sober) and **Quick** (low friction, used while impaired) — without breaking the existing architecture.

---

## My Take vs. the Referenced Framework

The LLM framework cited is academically solid, but it over-engineers some variables and misses the single biggest inaccuracy in the current implementation.

### The Single Biggest Problem: Instant Absorption

The current math treats every drink as if it reaches peak BAC the moment it's logged. In reality absorption takes 30–90 minutes, during which BAC is *rising* — not already at peak. This creates two problems:

1. **Early over-warning**: Log a beer, BAC spikes immediately. In reality you're 45 minutes from peak.
2. **Missing the curve**: The actual BAC-time graph is an asymmetric mountain, not a sawtooth. Getting this right matters more than Watson formula precision.

**Fix**: Replace the single-term Widmark sum with a two-phase piecewise model per drink:
- **Absorption phase**: BAC rises linearly over `T_abs` window (30–75 min depending on food state)
- **Elimination phase**: Standard Widmark decay (`β × t`) after `T_abs`

This is the highest-ROI accuracy improvement and applies to **both modes**.

### What to Keep From the Referenced Framework

| Point | Decision |
|---|---|
| Watson formula for Total Body Water | Add to Ultra — requires height + age in profile |
| Food buffer (Absorption Modifier) | Yes — 3-option selector (empty / light / full), not continuous |
| Carbonation multiplier | Ultra only — optional checkbox per drink, reduces `T_abs` by ~25% |
| Tolerance / metabolic adaptation | Yes — 3 elimination rate options (standard 0.015 / moderate 0.017 / high 0.020) |
| Bolus effect | Handled automatically by the absorption curve — no separate variable needed |
| Mellanby Effect warning | UI note only — ascending limb indicator while still absorbing |
| Congeners | Skip — adds complexity, doesn't change the ethanol math |

### What to Add (Not in Referenced Framework)

1. **Legal threshold markers** — Gauge ring tick marks at 0.05 (EU/AU) and 0.08 (US). Currently absent.
2. **Ascending limb indicator** — While BAC is still rising (within `T_abs` of last drink), show a "still absorbing" state. Prevents false confidence.
3. **Per-drink timestamp flexibility** — Users log drinks late. "15 min ago" offset must be honoured in the math (`effectiveTimestamp`), not just displayed.
4. **Widget data bridge** — Currently `buildEntry()` returns `.clear` hardcoded. This is broken and must ship as part of the same implementation pass.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Absorption curve scope | Both modes | Runs silently — no added friction for Quick users |
| Mode switching | Per-session segmented control in Add Drink sheet | More flexible; no global toggle to remember |
| Widget fix timing | Ships with the engine | Broken widget undermines trust in all accuracy work |

---

## Mode Architecture

### Ultra Mode
Configured in Profile view. Enables Watson-formula volume of distribution and per-drink modifiers.

**Watson TBW Formula (replaces `weightGrams × r` in `MetabolismManager.swift:35`):**
```
Male:   TBW (L) = 2.447 − (0.09516 × age) + (0.1074 × heightCm) + (0.3362 × weightKg)
Female: TBW (L) = −2.097 + (0.1069 × heightCm) + (0.2466 × weightKg)
```
`Vd = TBW × 1000` (grams)

Body composition adjusts TBW further:
- Athletic (+5% TBW — more muscle = more body water)
- Average (no adjustment)
- Sedentary (−5% TBW)

**Elimination rates:**
- Standard: β = 0.015 g/dL/hr
- Moderate tolerance: β = 0.017
- High tolerance: β = 0.020

**Per-drink Ultra modifiers:**
- Carbonation toggle → `T_abs × 0.75` (faster absorption)
- Food state override → inherits session default, can be changed per drink

---

### Quick Mode
Selected at the time of logging. No numbers, no ABV, no mL.

**Entry flow:**
1. Category grid: 🍺 Beer / 🍷 Wine / 🥃 Shot / 🍹 Cocktail
2. Size: S / M / L
3. Time offset: "Just now" / "15 min" / "30 min" / "1 hr"
4. Single "LOG IT" button

**Size defaults:**

| Category | S | M | L |
|---|---|---|---|
| Beer | 355 mL / 4.5% | 473 mL / 5% | 568 mL / 5.5% |
| Wine | 120 mL / 12% | 150 mL / 13% | 200 mL / 14% |
| Shot | 30 mL / 40% | 44 mL / 40% | 60 mL / 40% |
| Cocktail | 150 mL / 12% | 200 mL / 14% | 250 mL / 15% |

Quick mode uses standard Widmark r-factor (not Watson) and standard β (0.015). Absorption curve still applies — food state defaults to the session food state set in Profile.

---

## Data Model Changes

### `UserProfile.swift` — new fields
```swift
var heightCm: Double = 170.0        // Watson formula input
var age: Int = 30                   // Watson formula input
var bodyComposition: BodyComposition = .average  // enum
var toleranceLevel: ToleranceLevel = .standard   // enum
var sessionFoodState: FoodState = .light         // persisted session default
```

### `DrinkEntry.swift` — new fields
```swift
var isCarbonated: Bool = false      // Ultra only — shrinks T_abs
var timestampOffsetSec: Int = 0     // seconds subtracted from timestamp (Quick mode)
var foodStateAtTime: FoodState = .light  // per-drink food state
```

`effectiveTimestamp = timestamp - timestampOffsetSec`

### `MetabolismManager.swift` — `currentBAC` rewrite

Replace existing implementation with a piecewise model per drink:

```
T_abs = food state absorption window (empty: 30min / light: 45min / full: 75min)
      × carbonation multiplier (carbonated: 0.75, else 1.0)

t = hours since effectiveTimestamp

If t < T_abs:
    contributionBAC = peakBAC × (t / T_abs)           // rising
Else:
    contributionBAC = peakBAC − β × (t − T_abs)       // falling
    contributionBAC = max(0, contributionBAC)

peakBAC = (alcoholGrams / Vd) × 100                   // Watson Vd (Ultra) or weightGrams × r (Quick)
```

Sum contributions across all recentDrinks (still the existing 12-hour window).

---

## UI Changes

### Profile View (`ProfileView.swift`)
- New "Ultra Calibration" card (below existing Physiology card):
  - Height input (ft/in or cm, unit toggle)
  - Age input
  - Body composition: 3-button selector (Athletic / Average / Sedentary)
  - Tolerance level: 3-button selector (Standard / Moderate / High)
  - Session food state: 3-button selector (Empty / Light / Full)
- Existing weight + sex stay in the existing Physiology card

### Add Drink View (`AddDrinkView.swift`)
- Segmented control at top: `Ultra | Quick`
- **Ultra tab**: existing presets grid + Carbonated toggle per card + food state override
- **Quick tab**: full-screen category → size → time offset flow, "LOG IT" button

### Dashboard (`DashboardView.swift`)
- "Still Absorbing" indicator when last drink is within its `T_abs` window
- Gauge ring tick marks at 0.05 and 0.08 BAC

### ZeroLine Gauge (`ZeroLineGaugeView.swift`)
- Add legal threshold tick marks at 0.05 and 0.08 on the ring arc

### Widget (`SoberCurfewWidget.swift` + `project.yml`)
- Configure App Group entitlement
- Write BAC + soberTime to shared `UserDefaults(suiteName:)` when drinks are added
- Widget provider reads from App Group container instead of returning `.clear`

---

## Critical Files

| File | Change |
|---|---|
| `SoberCurfew/Models/UserProfile.swift` | Add heightCm, age, bodyComposition, toleranceLevel, sessionFoodState |
| `SoberCurfew/Models/DrinkEntry.swift` | Add isCarbonated, timestampOffsetSec, foodStateAtTime |
| `SoberCurfew/Managers/MetabolismManager.swift` | Rewrite `currentBAC` with piecewise absorption/elimination model |
| `SoberCurfew/Views/Profile/ProfileView.swift` | Add Ultra Calibration card |
| `SoberCurfew/Views/AddDrink/AddDrinkView.swift` | Add segmented control + Quick tab flow |
| `SoberCurfew/Views/Dashboard/DashboardView.swift` | Add ascending limb indicator |
| `SoberCurfew/Views/Dashboard/ZeroLineGaugeView.swift` | Add legal threshold ticks |
| `SoberCurfewWidget/SoberCurfewWidget.swift` | Fix App Group data bridge |
| `project.yml` | Add App Group entitlement to iOS + Widget targets |

---

## Verification Plan

1. **Absorption curve math**:
   - Single beer (empty stomach) → BAC rises for 30 min to peak, then decays linearly at 0.015/hr
   - Same beer (full stomach) → peak at 75 min, identical peak height, slower onset
   - Carbonated drink → peak at ~22 min (30 × 0.75)
   - 3 shots in 10 min → single merged rising curve, not 3 separate spikes

2. **Watson vs Widmark**: Same drink, same weight/sex — Ultra mode produces lower BAC for an athletic user, higher for sedentary vs. the Widmark default.

3. **Quick mode**: "30 min ago" entry → `timestampOffsetSec = 1800`, `effectiveTimestamp` is 30 min earlier, BAC calculated as if drink was logged 30 min prior.

4. **Widget bridge**: Add drink in app → wait ≤ 15 min → widget shows non-zero BAC matching dashboard value.

5. **Watch**: Add drink on phone → watch displays updated BAC within CloudKit sync latency (~1–5 min).
