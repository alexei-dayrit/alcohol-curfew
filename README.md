# SoberCurfew

Predictive metabolic tracking to reclaim tomorrow morning.

**Internal codename:** Project Widmark

---

## What it does

SoberCurfew uses the Widmark formula to estimate your Blood Alcohol Content in real time and show you the exact time your BAC reaches 0.00% — the "ZeroLine." It predicts how alcohol will impact your sleep based on your bedtime, and surfaces all of this through a high-end Bento Grid dashboard.

---

## Quick Start

### Prerequisites

- Xcode 15.0+
- macOS 14.0+
- XcodeGen: `brew install xcodegen`
- Apple Developer account (for HealthKit + CloudKit)

### Setup

```bash
cd alcohol-curfew
xcodegen generate
open SoberCurfew.xcodeproj
```

In Xcode:
1. Set your **Development Team** in each target's Signing & Capabilities tab
2. Add **HealthKit** capability to the `SoberCurfew` iOS target
3. Add **iCloud** capability with CloudKit to `SoberCurfew` (or skip for local-only builds — see TECHNICAL_PLAN.md)
4. Build and run on a real device (HealthKit doesn't work on simulator)

---

## Architecture

See [TECHNICAL_PLAN.md](TECHNICAL_PLAN.md) for full architecture details.

See [PRD.md](PRD.md) for product requirements and feature priorities.

### Key files

| File | Purpose |
|---|---|
| `MetabolismManager.swift` | Widmark BAC calculation, ZeroLine, sleep impact |
| `DrinkEntry.swift` | SwiftData model for logged drinks |
| `UserProfile.swift` | SwiftData model for physiological profile |
| `DashboardView.swift` | Main Bento Grid dashboard |
| `ZeroLineGaugeView.swift` | Circular BAC progress ring |
| `SleepCurfewView.swift` | Metabolic curfew timeline |
| `HealthKitManager.swift` | HealthKit read/write |

---

## Safety

This app provides **estimates only**. The Widmark formula is accurate to approximately ±20% and does not account for food intake, medications, individual tolerance variation, or other metabolic factors.

**Never drive or operate machinery based on this app's output.**

---

## Platforms

- iOS 17.0+
- watchOS 10.0+
- Home Screen Widgets (small + medium)
