# SoberCurfew — Product Requirements Document
*Internal codename: Project Widmark*

---

## Overview

**SoberCurfew** is an iOS-first metabolic timing app that uses the Widmark formula to give social drinkers, fitness enthusiasts, and biohackers real-time BAC estimates and predictions about when alcohol will fully clear their system. Unlike sobriety streak apps, the core value proposition is *predictive metabolic intelligence* — helping users protect tomorrow's sleep, workout, or productivity.

---

## Target Audience

| Segment | Need |
|---|---|
| Social drinkers | Know when they're safe to sleep / drive (next day) |
| Fitness enthusiasts | Protect training recovery and sleep quality |
| Biohackers | Understand metabolic impact of alcohol with data |

---

## Priority 0 Features (Launch Required)

| Feature | Description |
|---|---|
| **Widmark BAC Engine** | Estimate BAC using the Widmark formula adjusted per body weight and biological sex |
| **ZeroLine Countdown** | Real-time "Time to Sober" clock showing exact time BAC reaches 0.00% |
| **Drink Logging** | Quick log preset drinks + manual volume/ABV entry |
| **HealthKit Sync** | Read biological sex and body weight; write BAC samples |
| **Apple Watch Complication** | Current BAC and ZeroLine displayed on wrist |
| **First-launch Disclaimer** | Required "I Agree" acknowledgment that estimates are not medical advice |

---

## Priority 1 Features (Next Release)

| Feature | Description |
|---|---|
| **Sleep Impact Score** | Color-coded Green/Yellow/Red prediction of how current BAC affects REM/Deep Sleep |
| **Metabolic Curfew View** | Timeline visualization showing sobering window vs. user's bedtime |
| **Hydration Reminders** | Push notifications based on estimated alcohol volume consumed |
| **Home Screen Widget** | Bento-style small/medium widget with live BAC and ZeroLine |

---

## Non-Goals

- Sobriety tracking / streaks
- Social sharing features
- Medical advice or diagnosis
- Real-time breathalyzer integration

---

## Design Principles

- **Dark by default** — nighttime-oriented use case
- **Bento Grid layout** — high-end dashboard feel, not a spreadsheet
- **Neon Amber** accent (`#F5A623`) on deep black (`#0A0A0F`)
- **Calm Blue** (`#4FC3F7`) for sleep/night-related elements
- Typography: SF Rounded for numeric displays, SF Pro for body text
- Persistent safety disclaimer visible on Profile screen

---

## App Store Compliance

| Requirement | Implementation |
|---|---|
| Age Rating | 17+ (Alcohol and Tobacco) |
| Safety Disclaimer | Required on first launch — must tap "I Understand" before accessing app |
| Persistent Footer | "ESTIMATES ONLY. NEVER DRIVE UNDER THE INFLUENCE." on all key screens |
| HealthKit | NSHealthShareUsageDescription + NSHealthUpdateUsageDescription required in Info.plist |

---

## Screens

### 1. Dashboard (Bento Grid)
- **Large tile**: ZeroLine circular gauge — current BAC %, exact sober time
- **Medium tile**: Sleep Impact — color-coded status card
- **Small tile**: Quick Log button (+)
- **Stat tiles (2×2)**: Last drink, Estimated BAC, Drinks today, Time to sober

### 2. Log Drink
- Quick-select grid: Pint, Bottle, Wine, Shot, Cocktail, Craft Beer
- Manual entry: volume (mL) + ABV (%) + optional name
- Add button with validation

### 3. Sleep Curfew
- Metabolic Curfew header with current impact status
- Timeline bar: Now → Sober → Bedtime
- Sleep zones legend (Green / Yellow / Red)

### 4. Profile & Settings
- Body weight slider (lbs)
- Biological sex selector
- Bedtime picker
- HealthKit sync toggle + manual sync button
- Persistent safety disclaimer

### 5. Disclaimer (First Launch Only)
- App logo and tagline
- Safety disclaimer card
- "I Understand — Let's Go" CTA

---

## Success Metrics

- DAU/MAU ratio > 30% (nightly use pattern)
- Avg drinks logged per session > 1.5
- HealthKit sync enable rate > 40%
- App Store rating ≥ 4.5
