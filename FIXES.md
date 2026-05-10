# SoberCurfew — Master Fix List

Generated from 6-section codebase review. Organized by priority.

---

## P0 — Critical (data correctness, safety, crashes)

### 1. HealthKit BAC unit is wrong — values written 100× too small
**File:** `Managers/HealthKitManager.swift`  
`writeBACSample()` divides `bac` by 100 before passing to `HKQuantity(unit: .percent(), doubleValue:)`. HealthKit's `.bloodAlcoholContent` type stores BAC as a percentage fraction already (0.08 = 0.08% BAC). Dividing by 100 again writes 0.0008 instead of 0.08 — two orders of magnitude off.  
**Fix:** Remove the `/ 100.0` — pass `bac` directly to `HKQuantity`.

---

### 2. Watch app data is always empty — no CloudKit/App Group entitlement on Watch target
**File:** `SoberCurfewWatch/WatchApp.swift`, `SoberCurfewWatch/SoberCurfewWatch.entitlements`  
The Watch target's `ModelConfiguration` stores in its own sandbox with no App Group or CloudKit container. `SoberCurfewWatch.entitlements` only declares HealthKit — no `com.apple.developer.icloud-container-identifiers` or `com.apple.security.application-groups`. SwiftData CloudKit sync will never replicate to the Watch. Every computation runs against an empty store with default profile values (79.4 kg male).  
**Fix:** Add the iCloud container entitlement to the Watch target and construct its `ModelConfiguration` with `cloudKitDatabase: .automatic` matching the main app — or pivot to WatchConnectivity to push a data snapshot from the phone.  
**Status:** Code done — entitlements and `ModelConfiguration` updated. ⚠️ **Manual step pending:** In Xcode → Watch target → Signing & Capabilities → enable iCloud capability and add `iCloud.com.sobercurfew.app` container.

---

### 3. Hydration reminder never fires — rescheduled every 30 seconds, countdown always resets
**Files:** `Managers/NotificationManager.swift:28`, `Views/Dashboard/DashboardView.swift:185`  
`scheduleHydrationReminder` cancels and reschedules the same one-shot notification on every `refreshBAC()` call (every 30 s). The countdown resets to the full interval on every tick. The notification can never be delivered while the app is open. After backgrounding, it fires once and never repeats.  
**Fix:** Before scheduling, check `UNUserNotificationCenter.current().pendingNotificationRequests` for an existing `"hydration"` request. Only schedule if none exists. For true repeating behavior, schedule the next notification inside the `UNUserNotificationCenterDelegate` delivery callback, or reschedule only when BAC transitions from 0 → positive.

---

### 4. HealthKit flooded with one sample every 30 seconds
**Files:** `Views/Dashboard/DashboardView.swift:182`, `Managers/HealthKitManager.swift:70`  
`writeBACSample` is called on every `refreshBAC()` tick — including when BAC = 0. A 4-hour session writes ~480 samples. Zero-BAC samples are written indefinitely after the user sobers up.  
**Fix:** (a) Gate on `currentBAC > 0`. (b) Only write when BAC has changed by more than 0.002, or at most once per 5 minutes. Store `lastWrittenBAC: Double` and `lastWriteDate: Date` on `HealthKitManager`.

---

### 5. `sleepImpact()` checks current BAC, not BAC at bedtime
**File:** `Managers/MetabolismManager.swift:70`  
When `soberTime <= bedtime` (sober before bed), the function falls through to `bac >= 0.04 ? .reduced : .optimal` using `currentBAC`. A user at 0.09 now but fully sober 3 hours before bed incorrectly shows `.reduced`. The private helper `bacAt(date:drinks:profile:)` already exists.  
**Fix:**
```swift
let bacAtBed = bacAt(date: bedtime, drinks: drinks, profile: profile)
return bacAtBed >= 0.04 ? .reduced : .optimal
```

---

### 6. `recentDrinks` filters on `timestamp`, not `effectiveTimestamp`
**Files:** `Views/Dashboard/DashboardView.swift:27`, `Views/Sleep/SleepCurfewView.swift:11`, `SoberCurfewWatch/WatchView.swift:12`  
`MetabolismManager.contribution()` uses `effectiveTimestamp` (applies the retroactive offset), but the filter uses raw `timestamp`. A drink logged as "1 hour ago" has `effectiveTimestamp` 1 hour earlier than `timestamp`. The 12-hour window should be evaluated on `effectiveTimestamp` to match what the engine consumes.  
**Fix:** Change all three filter sites to `$0.effectiveTimestamp > cutoff`.

---

### 7. `isAuthorized` set `true` even when the user denies HealthKit permission
**File:** `Managers/HealthKitManager.swift:37`  
`HKHealthStore.requestAuthorization(toShare:read:)` does not throw on denial (Apple's privacy design). The `do { ... isAuthorized = true }` block always executes.  
**Fix:**
```swift
try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
isAuthorized = store.authorizationStatus(for: bacType) == .sharingAuthorized
```

---

### 8. `writeBACSample` called when `isAuthorized` is false — silent failure
**File:** `Views/Dashboard/DashboardView.swift:182`, `Managers/HealthKitManager.swift:70`  
`DashboardView` gates on `profile.healthKitEnabled` but not `healthKit.isAuthorized`. On cold launch with a persisted `healthKitEnabled = true` profile, HealthKit auth is never re-requested and writes silently fail.  
**Fix:** Add `guard isAuthorized else { return }` at the top of `writeBACSample()`.

---

### 9. `isAuthorized` mutated off `@MainActor` — thread safety violation
**Files:** `Managers/HealthKitManager.swift:38`, `Managers/NotificationManager.swift:19`  
Both managers are `@Observable`. After `await store.requestAuthorization(...)` resumes, `isAuthorized = true` executes on whatever executor resumed the continuation — potentially a background thread. `@Observable` access tracking is not thread-safe.  
**Fix:** Annotate both manager classes with `@MainActor`.

---

### 10. `timeToZero` scans only 24 hours — returns `nil` for heavy sessions, displayed as "Clear"
**File:** `Managers/MetabolismManager.swift:53`  
The 288-step scan covers 24 hours. Any BAC that doesn't reach zero within that window returns `nil`, which the UI renders identically to "no alcohol detected" — "Clear" in the stat tile, `nil` sober time. This is a silent safety failure.  
**Fix:** Extend the loop to at least 48 hours (`48 * 12` steps). Optionally return a distinct sentinel the UI can label as "48h+" rather than "Clear".

---

## P1 — Significant Bugs (broken features, wrong behavior)

### 11. Dashboard BAC not refreshed when drinks are added — only on sheet dismiss
**File:** `Views/Dashboard/DashboardView.swift`  
`refreshBAC()` is called in `onAppear`, on the 30 s timer, and on `onDismiss` of the AddDrink sheet. If a drink is inserted from another path (widget, background), or the sheet is not dismissed via the happy path, BAC stays stale for up to 30 s.  
**Fix:** Add `.onChange(of: allDrinks) { _, _ in refreshBAC() }`. This also makes the `onDismiss` call redundant.

---

### 12. WatchView BAC display freezes — no time-based refresh
**File:** `SoberCurfewWatch/WatchView.swift`  
`bac`, `progress`, and `isAbsorbing` are computed from `Date()` at render time, but SwiftUI only re-renders on SwiftData changes. Between drink additions, the Watch shows a frozen BAC value.  
**Fix:** Add `.onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in }` or wrap in a `TimelineView(.periodic(from: .now, by: 60))` to force periodic recomputes.

---

### 13. `updatePulse()` does not stop `repeatForever` animation when absorbing ends
**File:** `SoberCurfewWatch/WatchView.swift:86`  
`withAnimation(.default) { pulseOpacity = 1.0 }` does not override a live `repeatForever(autoreverses: true)` transaction. The ring may pulse indefinitely after `isAbsorbing` becomes `false`.  
**Fix:** Use `withAnimation(nil) { pulseOpacity = 1.0 }` to strip the transaction, or drive the animation via `.animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAbsorbing)` declaratively on the view instead of `withAnimation` imperatives.

---

### 14. Widget never updates when new drinks are logged
**File:** `Views/Dashboard/DashboardView.swift` (`writeToAppGroup`)  
Fresh BAC data is written to `UserDefaults(suiteName:)` but `WidgetCenter.shared.reloadAllTimelines()` is never called. The widget updates only on its 15-minute `getTimeline` policy.  
**Fix:** Call `WidgetCenter.shared.reloadAllTimelines()` at the end of `writeToAppGroup()`. Requires importing `WidgetKit` into the main app target.

---

### 15. Disclaimer bypass — `saveProfile()` forces `hasAcceptedDisclaimer = true`
**File:** `Views/Profile/ProfileView.swift:402`  
The `else` branch of `saveProfile()` creates a new `UserProfile` and sets `hasAcceptedDisclaimer = true` without the user ever seeing the disclaimer. This is reachable after data loss mid-session.  
**Fix:** Remove `p.hasAcceptedDisclaimer = true` from `saveProfile()`. Disclaimer acceptance should only be written in `DisclaimerView.accept()`.

---

### 16. Duplicate `UserProfile` rows possible from two separate insert paths
**Files:** `Views/Onboarding/DisclaimerView.swift:90`, `Views/Profile/ProfileView.swift:395`  
Both use an independent fetch-or-insert pattern with `try?` that silently swallows errors. If the fetch fails, a second row is inserted. With CloudKit sync, `profiles.first` is non-deterministic between rows.  
**Fix:** Consolidate into a single `UserProfile.fetchOrCreate(in: ModelContext) -> UserProfile` static method used by both call sites. Use a stable sort on an `createdAt: Date` field in all `@Query` declarations.

---

### 17. `@Query var profiles` has no sort — first profile is non-deterministic
**Files:** `App/ContentView.swift:5`, `Views/Dashboard/DashboardView.swift:11`, `Views/Profile/ProfileView.swift:6`  
All three declare `@Query private var profiles: [UserProfile]` with no sort descriptor. If two rows exist, `.first` may return different rows per-view.  
**Fix:** Add a `createdAt: Date` field to `UserProfile` and sort all queries by it: `@Query(sort: \UserProfile.createdAt) var profiles: [UserProfile]`.

---

### 18. `DrinkEntry.id` has no `@Attribute(.unique)` constraint
**File:** `Models/DrinkEntry.swift:39`  
CloudKit merge conflicts can create duplicate rows with the same UUID, silently inflating BAC calculations.  
**Fix:** Add `@Attribute(.unique) var id: UUID`.

---

### 19. Turning off hydration reminders in Profile does not cancel pending notification
**File:** `Views/Profile/ProfileView.swift:274`  
`onChange(of: hydrationRemindersEnabled)` only acts when `enabled == true`. Toggling off leaves the pending notification scheduled.  
**Fix:** Add `else { notifications.cancelHydrationReminders() }` to the `onChange` handler.

---

### 20. `isCarbonated` carries over between drink preset selections
**File:** `Views/AddDrink/AddDrinkView.swift:165`  
Selecting a new preset does not reset `isCarbonated`, so a beer (carbonated) followed by a shot can log the shot with `isCarbonated = true`.  
**Fix:** Set `isCarbonated = false` (or derive from preset category) inside the preset tap closure.

---

### 21. Double-tap on "LOG IT" inserts two identical `DrinkEntry` records
**File:** `Views/AddDrink/AddDrinkView.swift:364`  
The Quick mode log button has no in-flight guard. Two rapid taps call `addQuickDrink()` twice before dismiss fires.  
**Fix:** Add `@State private var isLogging = false`, gate the action on `!isLogging`, and set it `true` immediately on first tap.

---

### 22. `bacProgress` gauge uses inflated theoretical peak — ring is systematically under-filled
**File:** `Managers/MetabolismManager.swift:97`  
`peakBAC` sums each drink's individual peak as if consumed simultaneously, regardless of time spacing. For multi-drink sessions spread over hours, the denominator is too large and `bacProgress` never approaches 1.0.  
**Fix:** Compute true peak by scanning forward from `effectiveTimestamp` of the first drink in 5-minute increments (mirroring `timeToZero`), and use that as the denominator.

---

### 23. `NotificationManager.requestAuthorization` ignores `.provisional` grant
**File:** `Managers/NotificationManager.swift:19`  
`isAuthorized` is set only for `.authorized`. `.provisional` (silent delivery) also permits notification delivery and should be treated as authorized for this use case.  
**Fix:** Change to `isAuthorized = [.authorized, .provisional].contains(settings.authorizationStatus)`.

---

### 24. `fatalError` on `ModelContainer` init — CloudKit schema issues will crash-loop users
**File:** `App/SoberCurfewApp.swift:21`  
CloudKit entitlement mismatches or network errors during schema registration throw here. A `fatalError` means the user cannot open the app without deleting and reinstalling.  
**Fix:** Catch and fall back to a local-only `ModelConfiguration` (without `cloudKitDatabase: .automatic`) if the CloudKit config throws.

---

### 25. No SwiftData migration plan — future schema changes will destroy user data
**File:** `App/SoberCurfewApp.swift:11`  
`ModelContainer` has no `migrationPlan`. Adding any non-optional field without a default will force a destructive store reset on existing installs.  
**Fix:** Define `AppSchemaV1` as a `VersionedSchema` snapshot of the current model before the first production release so future additions use `MigrationStage.lightweight`.

---

### 26. Height slider jumps to 120 cm on first drag when `heightCm = 0`
**File:** `Views/Profile/ProfileView.swift:128`  
`Slider(value: $heightCm, in: 120...220)` clamps `0` to `120` on first interaction.  
**Fix:** Use a separate `@State var heightNotSet: Bool` flag. Show the slider only after the user explicitly taps "Set height", defaulting to a reasonable midpoint (170 cm).

---

### 27. DrinkTypeCard ABV truncates instead of rounds — "Craft Beer" shows 6% instead of 6.5%
**File:** `Views/AddDrink/DrinkTypeCard.swift:29`  
`Int(preset.abv * 100)` truncates. `Int(6.5) = 6`.  
**Fix:** `String(format: "%.1f%%", preset.abv * 100)` — or at minimum `Int((preset.abv * 100).rounded())`.

---

### 28. Ultra mode has no time-offset picker (always logs "right now")
**File:** `Views/AddDrink/AddDrinkView.swift:437`  
`addUltraDrink()` hardcodes `timestampOffsetSec: 0`. Quick mode offers up to 1-hour retroactive offset. Ultra mode, the precision path, is less accurate.  
**Fix:** Add the same "When did you have it?" offset picker from Quick mode to Ultra mode.

---

### 29. `SleepImpactTile` shows "Optimal" badge when zero drinks logged
**File:** `Views/Dashboard/DashboardView.swift`  
With no drinks, `sleepImpact` returns `.optimal` and the tile renders "Restorative Sleep Optimal" — implying the model evaluated something when it hasn't.  
**Fix:** Show a neutral "No drinks logged" placeholder in `SleepImpactTile` when `recentDrinks.isEmpty`, mirroring the empty-state pattern in `SleepCurfewView`.

---

### 30. `DRINKS TODAY` stat tile counts last 12 hours, not the calendar day
**File:** `Views/Dashboard/DashboardView.swift:77`  
The label is semantically wrong. Drinks from 3 AM appear under "DRINKS TODAY" if it's currently 3 PM. Drinks from noon disappear at midnight even though it's the same calendar day.  
**Fix:** Either rename to "LAST 12 HRS", or change the filter cutoff to calendar-day midnight (`Calendar.current.startOfDay(for: Date())`).

---

### 31. `widgetImpactKey` is `private` in `DashboardView` — widget can't access it
**File:** `Views/Dashboard/DashboardView.swift:208`  
`private extension SleepImpact` means the widget extension duplicates or hard-codes the same switch, with no shared source of truth.  
**Fix:** Move `var widgetImpactKey: String` to `MetabolismManager.swift` on `SleepImpact` itself (no access modifier).

---

### 32. Widget `Divider` background modifier doesn't affect line color
**File:** `SoberCurfewWidget/SoberCurfewWidget.swift:121`  
`.background(Color.white.opacity(0.1))` on a `Divider` styles the region behind the line, not the line itself. The divider renders in system separator color, likely invisible on the dark widget background.  
**Fix:** Replace with `Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)`.

---

### 33. `bedtimeDateFrom` in `ProfileView` and `UserProfile.bedtimeDate` have inconsistent day-rollover semantics
**Files:** `Models/UserProfile.swift:144`, `Views/Profile/ProfileView.swift:431`  
`UserProfile.bedtimeDate` correctly rolls forward 1 day if the time has already passed today. `ProfileView.bedtimeDateFrom` does not — the DatePicker initializes to an already-past time on the current day.  
**Fix:** Use `UserProfile.bedtimeDate` (or an equivalent rollover) as the DatePicker binding.

---

## P2 — Non-DRY / Code Quality

### 34. `recentDrinks` filter duplicated in 3 views (also uses wrong field — see P0 #6)
**Files:** `DashboardView.swift:26`, `SleepCurfewView.swift:11`, `WatchView.swift:12`  
Identical 12-hour filter, identical magic constant, identical wrong field.  
**Fix:** Add to `DrinkEntry`:
```swift
static func recent(from entries: [DrinkEntry], hours: Double = 12) -> [DrinkEntry] {
    let cutoff = Date().addingTimeInterval(-hours * 3600)
    return entries.filter { $0.effectiveTimestamp > cutoff }
}
```

---

### 35. `profiles.first ?? UserProfile()` duplicated in 4 views — creates ephemeral throwaway profiles
**Files:** `DashboardView.swift:24`, `SleepCurfewView.swift:9`, `WatchView.swift:10`, `AddDrinkView.swift:80`  
The fallback creates an unpersisted profile; mutations on it are silently lost.  
**Fix:** Centralize in `UserProfile.fetchOrCreate(in:)`. In views, guard against empty profiles with a visible error state rather than a silent default.

---

### 36. `sectionHeader` helper duplicated in `ProfileView` and `AddDrinkView`, inlined in `SleepCurfewView`
**Files:** `ProfileView.swift:332`, `AddDrinkView.swift:395`, `SleepCurfewView.swift` (inlined)  
**Fix:** Extract to a `View` extension or shared `LabelStyle` in `/Components/`.

---

### 37. `selectionButton` / chip styling duplicated across `ProfileView` and `AddDrinkView`
**Files:** `ProfileView.swift:341`, `AddDrinkView.swift:271,327,350`  
Same amber/cardBackground pill shape, corner radius, font, foreground — 4 separate implementations.  
**Fix:** Extract to `Components/ChipButton.swift` parameterised by font size.

---

### 38. Disclaimer footer text has 4 separate implementations with divergent styling
**Files:** `AddDrinkView.swift:384`, `SleepCurfewView.swift:146`, `ProfileView.swift:41`, `DashboardView.swift:90`  
Two use allcaps + `.textSecondary.opacity(0.4)` (font 9, tracking 1). One uses sentence-case + `.sleepYellow` (font 11, icon). One is standalone `Text`.  
**Fix:** Extract to `Components/DisclaimerFooter.swift` with a single canonical style.

---

### 39. `appGroupID` string literal duplicated across targets
**Files:** `DashboardView.swift:4`, `SoberCurfewWidget/SoberCurfewWidget.swift:5`  
A typo in either silently breaks widget data sharing.  
**Fix:** Move to a shared `AppConstants.swift` compiled into both targets (or use an `Info.plist` entry).

---

### 40. `MetabolismManager` is `@Observable` with no stored state — instantiated 3× with `@State`
**Files:** `DashboardView.swift:14`, `SleepCurfewView.swift:7`, `WatchView.swift:7`  
All methods are pure functions. `@Observable` and `@State` allocation add overhead with no benefit. Multiple instances will diverge if state is ever added.  
**Fix:** Remove `@Observable`, convert to a `struct` with static methods (or a `final class` injected once via `.environment()`).

---

### 41. `fetch-or-insert UserProfile` logic duplicated in `DisclaimerView` and `ProfileView`
**Files:** `Views/Onboarding/DisclaimerView.swift:90`, `Views/Profile/ProfileView.swift:382`  
Same `try?` fetch + guard-let + insert pattern, independently maintained.  
**Fix:** Consolidate into `UserProfile.fetchOrCreate(in: ModelContext) -> UserProfile`.

---

### 42. `peakBAC` per-drink formula duplicated inside `contribution()` and `peakBAC()`
**File:** `Managers/MetabolismManager.swift:82,98`  
`(alcoholGrams / vd) * 100.0` appears in both methods.  
**Fix:** Extract `private func peakContribution(of drink: DrinkEntry, profile: UserProfile) -> Double`.

---

### 43. `bedtimeDateFrom` appears in 3 locations including one dead free function
**Files:** `ProfileView.swift:431` (static), `ProfileView.swift:438` (free function, dead), `UserProfile.swift:144` (computed property)  
**Fix:** Delete the free function at line 438. Consolidate all call sites to use `UserProfile.bedtimeDate`.

---

### 44. Dead code: `Double.bacShort` never used
**File:** `Extensions/Double+BAC.swift`  
Defined, zero call sites.  
**Fix:** Delete, or adopt it consistently in place of raw `"%.2f"` format strings.

---

### 45. Dead code: `Color.textPrimary` never used
**File:** `Extensions/Color+Theme.swift`  
Defined as `Color.white`, never referenced. Views use `.white` directly throughout.  
**Fix:** Either adopt `.textPrimary` everywhere (replacing ~15 `.white` call sites), or delete the token.

---

### 46. `SleepImpact → Color` mapping duplicated in 3 places
**Files:** `SleepImpactTile.swift:8`, `SleepCurfewView.swift:63`, `SleepCurfewView.swift:133`  
Same `optimal → .sleepGreen / reduced → .sleepYellow / disrupted → .sleepRed` switch.  
**Fix:** Add `var color: Color { ... }` to `SleepImpact` in `MetabolismManager.swift`.

---

### 47. Widget `WidgetImpact.clear` is dead — never written, visually identical to `.optimal`
**File:** `SoberCurfewWidget/SoberCurfewWidget.swift:19`  
`DashboardView` never writes `"clear"` to `UserDefaults`; the widget's `default` case returns `.clear`. Both `.clear` and `.optimal` map to `.sleepGreen`.  
**Fix:** Collapse `.clear` into `.optimal`, or explicitly write `"clear"` when BAC is 0.

---

### 48. Widget supports only `systemSmall` and `systemMedium` — no lock screen or StandBy sizes
**File:** `SoberCurfewWidget/SoberCurfewWidget.swift:163`  
Lock screen (`accessoryCircular`, `accessoryRectangular`) and StandBy widgets are high-value for a BAC tracker.  
**Fix:** Add at minimum `accessoryCircular` showing current BAC as a gauge, and `accessoryRectangular` for a compact readout.

---

*End of master fix list — 48 items across 6 sections.*
