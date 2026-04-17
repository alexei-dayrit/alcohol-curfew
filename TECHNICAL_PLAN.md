# SoberCurfew — Technical Plan

---

## Stack

| Layer | Technology | Reason |
|---|---|---|
| UI | SwiftUI | Modern, declarative, supports iOS + watchOS + widgets |
| Persistence | SwiftData | Modern CoreData successor, CloudKit support built-in |
| Sync | CloudKit (via SwiftData) | Automatic iOS ↔ Mac sync, zero extra code |
| Health | HealthKit | Read weight/sex, write BAC samples |
| Watch | watchOS 10+ SwiftUI | Single target (no WatchKit App + Extension pattern) |
| Widget | WidgetKit | Home screen small/medium tiles |
| Project Gen | XcodeGen | `project.yml` → `.xcodeproj` without committing Xcode files |

---

## Project Structure

```
alcohol-curfew/
├── project.yml                         # XcodeGen manifest
├── PRD.md
├── TECHNICAL_PLAN.md
├── README.md
│
├── SoberCurfew/                        # iOS main app
│   ├── App/
│   │   ├── SoberCurfewApp.swift        # @main, ModelContainer, CloudKit config
│   │   └── ContentView.swift           # Disclaimer gate → Dashboard
│   ├── Models/
│   │   ├── DrinkEntry.swift            # @Model: name, category, volume, ABV, timestamp
│   │   └── UserProfile.swift           # @Model: weight, sex, bedtime, disclaimer flag
│   ├── Managers/
│   │   ├── MetabolismManager.swift     # Widmark formula, BAC, ZeroLine, sleep impact
│   │   └── HealthKitManager.swift      # HK authorization, read weight/sex, write BAC
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift     # Bento grid layout root view
│   │   │   ├── ZeroLineGaugeView.swift # Circular progress ring
│   │   │   ├── SleepImpactTile.swift   # Color-coded sleep prediction card
│   │   │   └── StatTile.swift          # Reusable bento stat card
│   │   ├── AddDrink/
│   │   │   ├── AddDrinkView.swift      # Sheet: presets + manual entry
│   │   │   └── DrinkTypeCard.swift     # Individual preset drink card
│   │   ├── Sleep/
│   │   │   └── SleepCurfewView.swift   # Metabolic curfew timeline + zones
│   │   ├── Profile/
│   │   │   └── ProfileView.swift       # Weight, sex, bedtime, HealthKit
│   │   └── Onboarding/
│   │       └── DisclaimerView.swift    # First-launch safety gate
│   ├── Components/
│   │   └── BentoCard.swift             # Reusable frosted dark card container
│   ├── Extensions/
│   │   ├── Color+Theme.swift           # Design system colors
│   │   └── Double+BAC.swift            # BAC formatting helpers
│   └── Resources/
│       └── Info.plist                  # HealthKit usage descriptions
│
├── SoberCurfewWatch/                   # watchOS app
│   ├── WatchApp.swift                  # @main, ModelContainer
│   ├── WatchView.swift                 # BAC + ZeroLine display
│   └── Info.plist
│
└── SoberCurfewWidget/                  # iOS widget extension
    ├── SoberCurfewWidget.swift         # TimelineProvider + widget views
    └── Info.plist
```

---

## Math Engine — Widmark Formula

```
BAC (g/dL) = [A / (W × r)] − (β × t)
```

| Variable | Description | Value |
|---|---|---|
| A | Alcohol mass in grams | `volumeML × ABV × 0.789` |
| W | Body weight in grams | `weightKg × 1000` |
| r | Widmark factor | `0.68` (male) / `0.55` (female) |
| β | Elimination rate | `0.015 g/dL/hour` |
| t | Hours elapsed since drink | `(now − drinkTimestamp) / 3600` |

Each drink is calculated independently (different elapsed time) and contributions are summed. This is the standard multi-drink Widmark approach and is accurate to ±20% for most adults.

**ZeroLine time** = `now + (currentBAC / β) hours`

**Sleep Impact logic:**
- `optimal` — soberTime ≤ bedtime AND BAC < 0.04%
- `reduced` — soberTime ≤ bedtime but BAC ≥ 0.04%
- `disrupted` — soberTime > bedtime (alcohol still present at sleep)

---

## Data Models

### DrinkEntry (@Model)
```
id: UUID
name: String
category: DrinkCategory (beer/wine/spirits/custom)
volumeML: Double
abv: Double          // stored as 0.0–1.0 (e.g. 0.05 = 5%)
timestamp: Date

computed:
  alcoholGrams = volumeML × abv × 0.789
  standardDrinks = alcoholGrams / 14.0
```

### UserProfile (@Model)
```
weightKg: Double
biologicalSex: BiologicalSex (male/female)
bedtimeHour: Int
bedtimeMinute: Int
hasAcceptedDisclaimer: Bool
healthKitEnabled: Bool

computed:
  widmarkR → 0.68 or 0.55
  bedtimeDate → next occurrence of bedtime as Date
```

---

## SwiftData + CloudKit Configuration

```swift
ModelContainer(
    for: [DrinkEntry.self, UserProfile.self],
    configurations: [ModelConfiguration(cloudKitDatabase: .automatic)]
)
```

CloudKit requires:
- iCloud entitlement with CloudKit service
- Container identifier: `iCloud.com.sobercurfew.app`
- Signed with an Apple Developer account

For local development without CloudKit, change `cloudKitDatabase: .automatic` to remove the parameter — SwiftData defaults to local SQLite.

---

## HealthKit Integration

**Read permissions:**
- `HKCharacteristicTypeIdentifier.biologicalSex`
- `HKQuantityTypeIdentifier.bodyMass`

**Write permissions:**
- `HKQuantityTypeIdentifier.bloodAlcoholContent`

Synced in `HealthKitManager` (`@Observable`). Weight is pulled once on sync and saved to UserProfile. BAC samples are written whenever a drink is logged.

---

## Widget Data Flow

The widget reads from a shared App Group container so it can access live SwiftData values without launching the main app. The widget refreshes every 15 minutes via `TimelineProvider`.

**Required setup:** Add App Group `group.com.sobercurfew.app` to both the main app and widget extension entitlements.

---

## Watch App Data Flow

watchOS 10 SwiftData with CloudKit syncs automatically. The watch app reads the same `DrinkEntry` and `UserProfile` records. No WatchConnectivity needed when both targets are signed into the same iCloud account.

---

## Setup Instructions

1. Install XcodeGen: `brew install xcodegen`
2. `cd alcohol-curfew`
3. `xcodegen generate`
4. Open `SoberCurfew.xcodeproj`
5. Set your Development Team in each target's Signing & Capabilities
6. Add iCloud capability with CloudKit (or remove for local-only)
7. Add HealthKit capability to the iOS target
8. Build and run

---

## Minimum Deployment Targets

| Platform | Version | Reason |
|---|---|---|
| iOS | 17.0 | SwiftData, `@Observable`, new WidgetKit APIs |
| watchOS | 10.0 | Single-target watch app format |

---

## Liability & App Store Notes

- Age rating: **17+** (Alcohol and Tobacco)
- HealthKit apps require a real device to test — simulator does not support HealthKit
- The disclaimer gate (`DisclaimerView`) must appear on every fresh install before the user can access any BAC data. This satisfies Apple's Health & Safety review criteria.
