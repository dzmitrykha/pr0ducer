# Activity Tracker (watchOS 26) — Implementation Plan

> A motivation-focused activity tracker for Apple Watch. The hero of the app is a
> circular complication that starts/stops an activity with a single tap and shows
> how many activities you have logged today. The app itself shows a scrollable
> history of day cards with a 0–24h timeline of activity segments.
>
> This document is the source of truth for building the **watchOS prototype**.
> An iOS companion app is planned later and the architecture is chosen so the
> core packages can be reused without rewrites.

---

## How to use this document

This plan is written so that **a fresh agent can pick up any single phase with no
prior context**. Each phase is self-contained and states:

- **Context recap** — the minimum background to start cold.
- **Goal / Definition of Done**.
- **Prerequisites** — which earlier phases must be complete.
- **Tasks** — concrete, ordered steps.
- **Files to create / modify**.
- **Verification** — exact commands and acceptance checks.

Before starting **any** phase, the agent must read:

1. This file's **§1 Product spec**, **§2 Interaction model**, **§3 Architecture**,
   **§4 Data model**, and **§5 Conventions**.
2. The technical baseline doc:
   `~/Library/Mobile Documents/com~apple~CloudDocs/NEW_APP_TECHNICAL_INSTRUCTIONS.md`
   (adapted for watchOS by §3 below).

Then read only the specific phase being implemented.

---

## 1. Product specification

### 1.1 What the app does

The app helps the user **start doing things instead of procrastinating**. The user
logs "activities" (focused work / deliberate effort sessions). The core loop is:

1. Glance at the watch face complication.
2. Tap to **start** an activity (the ring fills, indicating "in progress").
3. Tap again to **stop** it (the ring empties).
4. The number above the ring shows **how many activities were started today**.

The full app shows the history as **day cards** so the user can see how active
each day was and stay motivated.

### 1.2 Core concepts

- **Activity (session):** a single tracked effort with a start time and an end
  time. While running, it has no end time ("in progress").
- **Active state:** there is exactly **0 or 1** in-progress activity at a time.
  Starting an activity while one is running is not allowed (the running one must
  be stopped first); the toggle handles this automatically.
- **Today's count:** number of activities whose **start time** falls on the
  current calendar day (in the user's current time zone).

### 1.3 Screens / surfaces

1. **Toggle complication** (`.accessoryCircular`): circular widget on the watch
   face / Smart Stack.
   - **In progress:** ring fully filled.
   - **Idle:** ring empty (thin outline only).
   - **Top of the circle:** today's activity count as a number.
   - **Tap:** toggles start/stop directly (interactive App Intent, no app launch).

2. **Open-app complication** (`.accessoryCircular` second kind): visually similar
   but its only job is to **open the app** when tapped (`widgetURL`).

3. **App — Day List (root):** vertically scrollable list of day cards.
   - **Today** on top, then **yesterday**, **day before**, etc. (descending).
   - Each card (landscape layout):
     - Left: the **number of activities** for that day.
     - Right: a **0–24 hour horizontal track** with filled **segments** for each
       activity registered that day. Activities crossing midnight are split
       across the two day cards.

4. **App — Activity Session (optional confirmation surface):** when an activity
   is started/stopped via the *open-app* path, the app can show a short countdown
   with a **Cancel** button before committing the state change (see §2.4). For the
   prototype this is a secondary surface; the primary control is the toggle
   complication.

### 1.4 Out of scope for the prototype

- iOS companion app (planned; keep packages portable but do not build it now).
- CloudKit sync (architecture must not block it later; see §3.6).
- Activity categories/types, notes, editing past activities, notifications,
  goals/streaks. (Capture as backlog, do not implement.)

---

## 2. Interaction model (watchOS 26) — finalized

This section records the research and the **decisions**. Do not re-litigate; if a
decision is invalidated on-device during the Phase 2 spike, update this section.

### 2.1 Research findings (watchOS 26)

- **Interactive complications work.** Since watchOS 11 (and fully in watchOS 26),
  a `Button(intent:)` / `Toggle(isOn:intent:)` inside a widget runs the App
  Intent's `perform()` **without launching the app**. This is supported for watch
  face complications **and** the Smart Stack, for all widget families (subject to
  size). Source: WWDC24 "What's new in watchOS 11"; WWDC25 "What's new in
  watchOS 26"; "Adding interactivity to widgets and Live Activities".
- **Long-press cannot be intercepted by apps.** A firm/long press on the watch
  face is reserved by the system (enters watch-face customize mode). The only
  app-accessible gesture is **double-tap** (`.handGestureShortcut(.primaryAction)`),
  which is an in-app pinch gesture, not a complication gesture. Source: Apple
  Developer Forums (Frameworks Engineer): "The double-tap gesture is the only
  gesture that apps are able to respond to."
- **Apple's guidance:** interactive buttons/toggles should do **more than open
  the app**; to *open* the app from a widget use `widgetURL` / `Link`. So a single
  complication is effectively either "interactive action" **or** "opens app",
  not both via different gestures.

**Conclusion:** "tap = toggle, long-press = open app" on one complication is
**not possible** on watchOS 26. But one-tap toggle directly from the complication
**is** possible.

#### Phase 2 spike results (2026-06-14)

| Question | Result |
|----------|--------|
| Does `ToggleActivityIntent.perform()` mutate the shared DB? | **Yes** — verified by `ActivityIntentsTests` with in-memory DB + fixed clock. |
| Does the spike widget compile with `Button(intent: ToggleActivityIntent())`? | **Yes** — `SpikeToggleComplication` builds and registers in `ActivityWidgetBundle`. |
| Does `widgetURL(activitytracker://open)` compile on the open-app spike? | **Yes** — `SpikeOpenAppComplication` builds; deep-link handling lands in Phase 4. |
| Does tapping the interactive complication run the intent **without** launching the app? | **Expected yes** per WWDC guidance; **manual confirmation** required on Simulator/device (add spike complications to watch face or Smart Stack, tap toggle, confirm ring flips and app stays closed). |
| Does tapping the open-app complication launch the app? | **Expected yes** via `widgetURL`; **manual confirmation** required once Phase 4 handles `activitytracker://open`. |

**Implementation notes from spike:**

- `IntentDependencies.bootstrap()` is called from `ActivityWidgetBundle.init()` so
  intents running in the widget extension process get a live App Group database.
- Every intent calls `WidgetCenter.shared.reloadAllTimelines()` after writes.
- Fixed watch-only `Info.plist` keys (`WKApplication`, `WKWatchOnly`) so the app
  installs on the watchOS Simulator (removed conflicting/empty companion keys).

**No change to §2.2 decision** — two separate complications remains the plan; spike
widgets will be replaced by production complications in Phase 3.

### 2.2 Decision (per user): two complications

Ship **two separate complications** (two widget kinds in the same widget bundle):

1. **`ToggleActivityComplication`** — interactive `.accessoryCircular`.
   - Full-area `Button(intent: ToggleActivityIntent())`.
   - Renders filled/empty ring + today's count.
   - Tap toggles start/stop in place; no app launch.

2. **`OpenAppComplication`** — `.accessoryCircular` (distinct `kind`).
   - Uses `.widgetURL(activitytracker://open)`.
   - Tap opens the app to the Day List.
   - Renders the same ring + count for visual consistency (read-only).

Opening the app from the **app grid / Dock / Smart Stack** is also acceptable, so
the open-app complication is a convenience, not the only way in.

### 2.3 Why the toggle uses a Button + App Intent (not a tap on a plain view)

A plain tap on a non-interactive complication always launches the app. To toggle
**in place** you must use `Button(intent:)`/`Toggle(intent:)` with an `AppIntent`.
The intent writes to the shared database and calls
`WidgetCenter.shared.reloadAllTimelines()`.

### 2.4 Accidental-tap safety (optional, low priority for prototype)

A stray tap could stop an active session. Two options exist; **do not build
unless time allows**, and prefer (a):

- **(a)** `ToggleActivityIntent` requests confirmation via `requestConfirmation()`
  before committing a **stop** (start commits immediately — starting is always
  safe and motivating).
- **(b)** A variant intent with `openAppWhenRun = true` that opens the app to the
  **Activity Session** countdown screen (N-second countdown + Cancel) and commits
  only when the countdown elapses. This is the "timer + cancel" flow.

Keep the commit logic in the `ActivityDatabase` client so either mechanism reuses
the same write path.

### 2.5 Process & data sharing model

- The app and the widget extension are **separate processes**. They share state
  only through a database file in a shared **App Group** container (§3.4).
- The interactive intent's `perform()` runs in the **widget extension process by
  default**; it must write through the same `ActivityDatabase` client the app uses
  and then reload timelines. The app refreshes its UI on `scenePhase` active and
  by observing the database (SQLiteData live queries).

---

## 3. Architecture

Follows the technical baseline doc, **adapted for watchOS**. Same stack:

- **Swift 6.3**, strict concurrency.
- App target generated with **XcodeGen** (the baseline says "iOS app target"; for
  this prototype the generated target is a **watchOS app** + a **widget
  extension**; iOS is added later).
- **All product code lives in Swift Package Manager targets.** The app and widget
  targets are thin and only link SPM products.
- **The Composable Architecture (TCA)** for app state/feature composition/navigation.
- **Swift Dependencies** for runtime + test dependency control.
- **SQLiteData + GRDB + StructuredQueries** for local persistence.
- **Swift Testing + TestStore + CustomDump** for tests.

> Note: TCA runs in the **app** only. The **widget extension** does not run TCA —
> its timeline provider reads the DB through the `ActivityDatabase` client, and
> the App Intent writes through the same client. Keep the widget extension code
> minimal.

### 3.1 Repository layout

```text
pr0ducer/                                 # repo root
├─ IMPLEMENTATION_PLAN.md                  # this file
├─ README.md
├─ .gitignore
├─ App/                                    # thin Xcode targets only (XcodeGen)
│  ├─ project.yml                          # XcodeGen source of truth
│  ├─ Watch/
│  │  ├─ ActivityTrackerApp.swift          # @main; prepareDependencies + root store
│  │  ├─ Info.plist
│  │  ├─ ActivityTracker.entitlements      # App Group
│  │  └─ Assets.xcassets/
│  └─ Widget/
│     ├─ ActivityWidgetBundle.swift        # @main WidgetBundle (both complications)
│     ├─ Info.plist
│     └─ ActivityWidget.entitlements       # same App Group
└─ Packages/
   └─ ActivityTracker/
      ├─ Package.swift
      ├─ Sources/
      │  ├─ AppFeature/                     # root coordinator (watch app)
      │  ├─ DayListFeature/                 # day cards list + 0–24h timeline
      │  ├─ ActivitySessionFeature/         # countdown + cancel surface (§2.4)
      │  ├─ ActivityWidgetUI/               # shared SwiftUI: ring + count views
      │  ├─ ActivityIntents/                # App Intents (Toggle/Start/Stop)
      │  ├─ Database/                       # schema, migrations, client, models
      │  └─ Shared/                         # app-group constants, date helpers, UI primitives
      └─ Tests/
         ├─ AppFeatureTests/
         ├─ DayListFeatureTests/
         ├─ ActivitySessionFeatureTests/
         ├─ ActivityIntentsTests/
         └─ DatabaseTests/
```

### 3.2 Module dependency graph

```text
Shared            <- (no deps; app-group ids, date math, view primitives)
Database          <- Shared, SQLiteData, GRDB, StructuredQueries, Dependencies
ActivityWidgetUI  <- Shared            (pure SwiftUI, no DB writes)
ActivityIntents   <- Database, Shared, AppIntents framework
DayListFeature    <- Database, ActivityWidgetUI, Shared, ComposableArchitecture
ActivitySessionFeature <- Database, Shared, ComposableArchitecture
AppFeature        <- DayListFeature, ActivitySessionFeature, ActivityIntents, Database, Shared, ComposableArchitecture
```

Target linking in `project.yml`:

- **Watch app target** links: `AppFeature` (pulls the rest transitively).
- **Widget extension target** links: `ActivityWidgetUI`, `ActivityIntents`,
  `Database`, `Shared`.

### 3.3 Why these module boundaries

- `Database` isolates persistence (baseline rule). Both processes use its client.
- `ActivityIntents` isolates App Intents (baseline rule) and is linked by **both**
  the app and the widget extension (Apple requires the intent type in both).
- `ActivityWidgetUI` holds the ring/count SwiftUI so the widget **and** the app can
  render the same visual without the widget depending on TCA.
- `AppFeature` owns cross-feature coordination, deep links (`activitytracker://`),
  and pending-action resolution (baseline rule).

### 3.4 App Group & shared database

- Create one **App Group** (e.g. `group.<your-team-id>.activitytracker` — the
  agent must pick the real identifier and set it in entitlements + a constant in
  `Shared`).
- The SQLite database file lives in the App Group container so both the app and
  the widget extension open the **same** file.
- `Shared` exposes `AppGroup.identifier` and `AppGroup.databaseURL` so nothing
  hardcodes the path twice.

### 3.5 Startup & dependency wiring (baseline)

- `ActivityTrackerApp.swift` calls `prepareDependencies { ... }` to install the
  persistent `ActivityDatabase` (App Group). On failure, fall back to an
  in-memory database so the app still boots.
- Construct the root TCA `Store` in `ActivityTrackerApp` and host the root view.
- In debug builds, use `._printChanges()` on the root reducer.

### 3.6 CloudKit-readiness (do not build now)

- Keep all writes behind the `ActivityDatabase` client.
- Keep schema migrations explicit and append-only.
- Per the baseline doc, if sync is added later, attach the CloudKit metadatabase
  during DB setup rather than scattering sync code into features.

---

## 4. Data model

### 4.1 Table: `activities`

| Column        | Type     | Notes                                                        |
|---------------|----------|--------------------------------------------------------------|
| `id`          | TEXT PK  | UUID string, normalized lowercase (baseline: normalize text IDs) |
| `startedAt`   | INTEGER  | Unix epoch seconds, UTC. Required.                           |
| `endedAt`     | INTEGER? | Unix epoch seconds, UTC. `NULL` = in progress.               |
| `createdAt`   | INTEGER  | Unix epoch seconds, UTC. For audit/ordering.                 |

Constraints / indices:

- Index on `startedAt` (range queries per day).
- Partial index / query to find the single in-progress row (`endedAt IS NULL`).
- Enforce **at most one** in-progress activity in the **client** (transactional
  check), not via DB constraint (SQLite can't easily express it). Enable SQLite
  **foreign keys** in both persistent and in-memory configs (baseline rule) even
  though there are no FKs yet — keeps test/live parity and is future-proof.

### 4.2 Derived values (computed, not stored)

- **isActive:** `SELECT EXISTS(SELECT 1 FROM activities WHERE endedAt IS NULL)`.
- **todayCount:** activities with `startedAt` in `[startOfToday, startOfTomorrow)`
  in the current time zone. (Decision: count by **start time**.)
- **Day segments:** for a given calendar day `[dayStart, dayEnd)`, each activity
  overlapping the day yields a segment `[max(startedAt, dayStart),
  min(endedAt ?? now, dayEnd)]`. In-progress activities render up to "now".
  Activities spanning midnight appear (clipped) on each day they touch.

### 4.3 Time zone & "now"

- Use the **current calendar / time zone** at read time for day bucketing.
- Never call `Date()` directly in reducers/clients — use the
  `@Dependency(\.date)` clock and `@Dependency(\.calendar)` (baseline rule).
- The widget timeline provider also uses injected date/calendar.

### 4.4 Model types (illustrative)

```swift
// Database/Models/Activity.swift
public struct Activity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?   // nil == in progress
    public var createdAt: Date
}
```

Use StructuredQueries `@Table` / SQLiteData macros to back this with the
`activities` table. Store `Date` as epoch seconds; keep conversions in one place.

---

## 5. Conventions & Definition of Done

These apply to **every** phase.

### 5.1 Code conventions (from baseline doc)

- `@Reducer` + `@ObservableState` for features; `Scope` to compose children.
- Use `@Presents` for presentation state, not parallel booleans.
- Keep views thin: views send actions and render state; reducers own mutation,
  effects, navigation.
- Side effects only via `@Dependency` (clock, uuid, calendar, database). Never
  `Date()`, `UUID()`, or singletons directly.
- Async work via `.run` effects feeding results back as explicit actions.
- Persistence only through the `ActivityDatabase` dependency client — never raw
  GRDB/SQLite calls from reducers.
- Keep state minimal/derived; avoid duplicated values that can drift.
- The root reducer (`AppFeature`) owns anything crossing feature boundaries:
  deep links, pending actions, cross-feature coordination.

### 5.2 Testing (from baseline doc)

- Swift Testing for all tests; reducers tested with `TestStore`.
- Control clock, uuid, calendar, database via dependencies in tests.
- Use in-memory database for `DatabaseTests` and feature tests.
- Prefer `expectNoDifference` for state assertions.
- Feature tests cover: local mutation, follow-up actions, failure handling.
- `AppFeature` tests cover navigation / cross-feature flows + deep links.
- Link `DependenciesTestSupport` where needed; don't redundantly link transitive
  deps already provided by the target under test.

### 5.3 Definition of Done for a phase

A phase is done only when:

1. `Packages/ActivityTracker` builds (`swift build`) with no warnings introduced.
2. All tests for the phase's targets pass (`swift test`).
3. The app + widget build for the watchOS simulator via `xcodebuild` (Phase 0+).
4. New files are reflected in `project.yml` and `xcodegen generate` was re-run
   if app/widget target files changed.
5. No business logic leaked into the `App/` targets (baseline non-goal).
6. The phase's **Verification** checklist passes.

### 5.4 Build & verify commands

```bash
# SPM packages (fast inner loop; run from repo root)
cd Packages/ActivityTracker && swift build && swift test

# Regenerate Xcode project after changing App/ target files
cd App && xcodegen generate

# Build app + widget for the watch simulator
xcodebuild \
  -project App/ActivityTracker.xcodeproj \
  -scheme ActivityTracker \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  -scmProvider system \
  build
```

> Adjust the simulator name to one available via `xcrun simctl list devices`.
> Use `-scmProvider system` if Xcode's SCM package resolution is unreliable
> (baseline guidance).

### 5.5 Naming / identifiers (decide once in Phase 0, reuse everywhere)

- URL scheme: `activitytracker://` (deep links: `activitytracker://open`).
- App Group: `group.<team>.activitytracker` (real value chosen in Phase 0).
- Bundle IDs: `<reverse-dns>.ActivityTracker` (app),
  `<reverse-dns>.ActivityTracker.Widget` (extension).
- Widget kinds: `"ToggleActivity"` and `"OpenApp"`.

---

## 6. Phases

Phases are ordered. Each builds on the previous. A fresh agent should read §1–§5
plus the single phase it is implementing.

### Phase overview

| # | Phase | Outcome |
|---|-------|---------|
| 0 | Project scaffolding & tooling | Empty but buildable watch app + widget + SPM packages |
| 1 | Database layer | `activities` schema, migrations, `ActivityDatabase` client, tests |
| 2 | App Intents + on-device spike | Toggle/Start/Stop intents; validate interactive complication on device |
| 3 | Widgets (2 complications) | Interactive toggle complication + open-app complication |
| 4 | App shell (AppFeature) + deep links | Root coordinator, scenePhase refresh, `activitytracker://` handling |
| 5 | Day List feature | Scrollable day cards with 0–24h timeline + counts |
| 6 | Activity Session + integration polish | Optional countdown/cancel, state sync, a11y, localization, final pass |

---

## Phase 0 — Project scaffolding & tooling

### Context recap
Greenfield repo at `pr0ducer/`. We are building a watchOS 26 activity tracker
(see §1). Stack: Swift 6.3, XcodeGen for the Xcode project, all logic in SPM
targets, TCA + Swift Dependencies + SQLiteData/GRDB/StructuredQueries + Swift
Testing (§3). This phase produces an **empty but compiling** skeleton.

### Goal / Definition of Done
- `xcodegen generate` produces an Xcode project with a **watchOS app** target and
  a **widget extension** target, both thin.
- The watch app launches in the simulator showing a placeholder view.
- The widget extension contains an empty `WidgetBundle` that builds.
- `Packages/ActivityTracker` defines all 7 source targets (§3.1) and 5 test
  targets as **empty compiling stubs**, with dependencies declared per §3.2.
- `swift build` and `swift test` succeed (tests can be empty/trivially passing).
- App Group + entitlements + URL scheme + bundle IDs configured (§5.5).

### Prerequisites
None.

### Tasks
1. `git init`; add a Swift/Xcode `.gitignore` (ignore `App/*.xcodeproj`,
   `.build/`, `DerivedData/`, `*.xcuserstate`).
2. Add `README.md` (short: what the app is, how to build — link §5.4 commands).
3. Create `Packages/ActivityTracker/Package.swift`:
   - platforms: `.watchOS(.v26)` (and `.iOS(.v26)` so packages stay portable).
   - Add dependencies (resolve **latest** versions; do not hardcode guesses):
     - `pointfreeco/swift-composable-architecture`
     - `pointfreeco/swift-dependencies`
     - `pointfreeco/sqlite-data` (provides `SQLiteData`; pulls GRDB +
       StructuredQueries)
     - `pointfreeco/swift-custom-dump` (if not already transitive)
   - Declare the 7 library targets + 5 test targets per §3.1–§3.2 with empty
     `// TODO(phase N)` stub files so each compiles.
4. Create `App/project.yml` (XcodeGen) defining:
   - A **watchOS app** target (`ActivityTracker`) — Single-target watch app
     (watchOS 26 style, no paired iOS app needed for the prototype).
   - A **widget extension** target (`ActivityTrackerWidget`).
   - App Group capability on **both** targets; matching entitlements files.
   - URL scheme `activitytracker` on the app target Info.plist.
   - Local SPM package reference to `../Packages/ActivityTracker`.
   - App target links product `AppFeature`; widget links `ActivityWidgetUI`,
     `ActivityIntents`, `Database`, `Shared`.
5. Create thin sources:
   - `App/Watch/ActivityTrackerApp.swift` — `@main`, placeholder root view
     (real wiring lands in Phase 4; keep a `TODO`).
   - `App/Widget/ActivityWidgetBundle.swift` — `@main WidgetBundle` returning an
     empty/placeholder widget (real widgets in Phase 3).
6. Put shared constants in `Sources/Shared/AppGroup.swift`
   (`identifier`, `databaseURL`) — used by later phases.
7. Run `cd App && xcodegen generate`; fix until it builds.

### Files to create
- `.gitignore`, `README.md`
- `Packages/ActivityTracker/Package.swift`
- `Packages/ActivityTracker/Sources/<each target>/<Stub>.swift` (×7)
- `Packages/ActivityTracker/Tests/<each test target>/<Stub>Tests.swift` (×5)
- `App/project.yml`
- `App/Watch/{ActivityTrackerApp.swift, Info.plist, ActivityTracker.entitlements, Assets.xcassets}`
- `App/Widget/{ActivityWidgetBundle.swift, Info.plist, ActivityWidget.entitlements}`

### Verification
- `cd Packages/ActivityTracker && swift build && swift test` → success.
- `cd App && xcodegen generate` → success, no manual `.xcodeproj` edits.
- `xcodebuild ... build` (§5.4) → success on watch simulator.
- Launch the watch app in the simulator → placeholder view appears.
- Confirm App Group identifier matches in both entitlements + `AppGroup.swift`.

### Notes / risks
- watchOS single-target app vs paired app: prefer the **single-target watchOS
  app** template (no iOS host) — simpler and supported on watchOS 26.
- If SPM resolution is flaky in Xcode, use `-scmProvider system` (§5.4).
- Pin the watchOS deployment target to **26.0** (only supported version).

---

## Phase 1 — Database layer

### Context recap
We need local persistence for `activities` (§4). Persistence is isolated in the
`Database` SPM target and exposed to the rest of the app as a **Swift Dependencies
client** (baseline rule: reducers never touch raw storage). Uses SQLiteData +
GRDB + StructuredQueries. The DB file lives in the App Group container (§3.4) so
the widget extension shares it.

### Goal / Definition of Done
- `activities` table created via an explicit, append-only migration.
- `Activity` model backed by StructuredQueries `@Table`.
- `DatabaseBootstrap` that opens the persistent DB (App Group) with FK enabled,
  and an in-memory variant for tests/fallback.
- `ActivityDatabase` dependency client with the operations below.
- `DatabaseTests` cover every operation against an in-memory DB.

### Prerequisites
Phase 0 complete (targets + App Group constant exist).

### `ActivityDatabase` client API (design before coding)
Model as a struct of closures (Swift Dependencies style), with `liveValue`,
`testValue`, and a `previewValue`:

```swift
public struct ActivityDatabase: Sendable {
    // Reads
    public var currentActivity: @Sendable () async throws -> Activity?      // in-progress or nil
    public var todayCount: @Sendable () async throws -> Int                 // by start time, current TZ
    public var activities: @Sendable (_ dayStart: Date, _ dayEnd: Date) async throws -> [Activity]
    public var snapshot: @Sendable () async throws -> WidgetSnapshot        // {isActive, todayCount} for the widget
    // Writes (transactional; enforce single in-progress)
    public var start: @Sendable (_ now: Date) async throws -> Activity      // no-op-safe if already running
    public var stop:  @Sendable (_ now: Date) async throws -> Void          // ends current; no-op if none
    public var toggle: @Sendable (_ now: Date) async throws -> WidgetSnapshot // start if idle, else stop
}
```

- `toggle` is the single entry point used by the App Intent; it returns the new
  snapshot so the intent can update the widget optimistically.
- `start`/`stop`/`toggle` must be **transactional** (baseline: bundle-style
  save helpers) and guarantee the "at most one in-progress" invariant.
- Normalize UUID text to lowercase on read and write (baseline rule).

### Tasks
1. Define `Activity` (§4.4) and `WidgetSnapshot { isActive: Bool; todayCount: Int }`
   in `Database` (snapshot is shared with widget — consider placing the snapshot
   type in `Shared` if both `Database` and `ActivityWidgetUI` need it; pick one
   home and document it).
2. Write migration `001_create_activities` (explicit, append-only) creating the
   table + indices from §4.1. Keep migrations in `DatabaseBootstrap.swift`.
3. Implement `DatabaseBootstrap.persistent()` (App Group URL, FK on) and
   `.inMemory()` (FK on). Both share migration registration.
4. Implement `ActivityDatabase.liveValue` using the bootstrapped DB. Day bucketing
   uses injected `@Dependency(\.calendar)`; "now" comes from callers (intents/
   features pass it) — keep the client deterministic given inputs.
5. Provide `testValue` (unimplemented closures that fail) and a `previewValue`
   backed by an in-memory DB with seed data.
6. Register the client as a `DependencyKey` / `@DependencyClient`.

### Files to create
- `Sources/Database/Models/Activity.swift`
- `Sources/Database/DatabaseBootstrap.swift` (open + migrations + FK)
- `Sources/Database/ActivityDatabase.swift` (client + live/test/preview)
- `Sources/Shared/WidgetSnapshot.swift` (if shared home chosen)
- `Tests/DatabaseTests/ActivityDatabaseTests.swift`

### Verification (`DatabaseTests`)
- Migration creates the schema; FK pragma is ON for both configs.
- `start` then `currentActivity` returns a running activity; second `start` does
  **not** create a duplicate in-progress row.
- `stop` ends the current activity (`endedAt` set); `stop` with none is a no-op.
- `toggle` from idle → starts; from active → stops; returns correct snapshot.
- `todayCount` counts by start time within the day; ignores other days; respects
  injected calendar/time zone.
- `activities(dayStart, dayEnd)` returns rows overlapping the range, including an
  in-progress row (open-ended).
- All tests use the in-memory DB and controlled dates.

### Notes / risks
- Confirm the exact SQLiteData/StructuredQueries macro API for `@Table` and query
  building against the resolved package version; adjust syntax accordingly.
- Decide and document the storage unit for dates (epoch seconds recommended) and
  keep all conversions in one helper.

---

## Phase 2 — App Intents + on-device interaction spike

### Context recap
The interactive toggle complication needs an `AppIntent` whose `perform()` toggles
the activity and reloads widget timelines (§2). App Intents live in the dedicated
`ActivityIntents` target (baseline rule) and are linked by **both** the app and
the widget extension. This phase also runs an **on-device spike** to confirm the
interactive complication actually toggles in place on watchOS 26 (decisions in §2
are based on docs/WWDC; verify on hardware/simulator).

### Goal / Definition of Done
- `ToggleActivityIntent`, `StartActivityIntent`, `StopActivityIntent` implemented,
  writing through `ActivityDatabase` and calling
  `WidgetCenter.shared.reloadAllTimelines()`.
- Intents resolve the database via the dependency system (not a singleton).
- `ActivityIntentsTests` verify `perform()` mutates state and returns results
  using a controlled in-memory DB + fixed clock.
- **Spike documented** in this file (§2): does a tap on the interactive
  complication run the intent without launching the app? Is the open-app
  complication's `widgetURL` reliable? Record the answer + any adjustments.

### Prerequisites
Phase 1 (database client) complete.

### Tasks
1. `ToggleActivityIntent: AppIntent`:
   - `perform()` resolves the date (`@Dependency(\.date.now)`), calls
     `database.toggle(now)`, reloads timelines, returns `.result()`.
   - Keep `openAppWhenRun = false` (toggle in place).
   - Add a `title` and make it discoverable in Shortcuts (nice-to-have).
2. `StartActivityIntent` / `StopActivityIntent`: thin wrappers around
   `database.start` / `database.stop` (useful for Shortcuts and the optional
   open-app countdown variant in §2.4). Reload timelines.
3. Ensure intents work in the **widget extension process**: resolving
   `@Dependency(\.defaultDatabase)`/`ActivityDatabase` must bootstrap the App
   Group DB if not already prepared. Provide a small `IntentDependencies.bootstrap()`
   helper that both the app and the extension can call so intents have a live DB
   even when run outside the app.
4. (Optional, §2.4) Add a `ConfirmStopActivityIntent` using `requestConfirmation()`
   before stopping — only if time allows; gate behind a flag.
5. **Spike**: build a throwaway minimal interactive `.accessoryCircular` widget
   (or reuse Phase 3 scaffolding) with a `Button(intent: ToggleActivityIntent())`,
   add it to a watch face / Smart Stack in the simulator, tap it, and observe
   whether the DB row toggles **without** the app opening. Record results.

### Files to create
- `Sources/ActivityIntents/ToggleActivityIntent.swift`
- `Sources/ActivityIntents/StartActivityIntent.swift`
- `Sources/ActivityIntents/StopActivityIntent.swift`
- `Sources/ActivityIntents/IntentDependencies.swift` (DB bootstrap for extension)
- `Tests/ActivityIntentsTests/ToggleActivityIntentTests.swift`

### Verification
- `ActivityIntentsTests`: with an in-memory DB seeded idle, `perform()` of
  `ToggleActivityIntent` starts an activity; performed again, it stops it.
  `Start`/`Stop` behave correctly and are idempotent at the boundaries.
- Manual spike: tapping the interactive complication toggles the ring and does
  **not** launch the app; the open-app complication launches the app. Document
  the outcome and update §2 if reality differs (e.g., if on the watch face the
  tap launches the app anyway, switch the toggle complication to the Smart Stack
  and/or adopt the open-app + countdown flow from §2.4).

### Notes / risks
- App Intents that perform DB work inside the widget extension must not rely on
  app-only setup. The `IntentDependencies.bootstrap()` helper de-risks this.
- `WidgetCenter.reloadAllTimelines()` is the cross-process signal that updates the
  complication after a write from either process.
- If `requestConfirmation()` behaves oddly on watchOS, defer §2.4 to Phase 6.

---

## Phase 3 — Widgets (two complications)

### Context recap
Per §2.2 we ship **two** `.accessoryCircular` widget kinds in one bundle:
`ToggleActivity` (interactive start/stop) and `OpenApp` (opens the app via
`widgetURL`). Both render the same visual: a ring (filled when active, empty when
idle) with today's count number on top. The reusable ring/count SwiftUI lives in
`ActivityWidgetUI` so it can be shared with the app. The widget reads state via
the `ActivityDatabase` client; the toggle's interactivity comes from the
`ToggleActivityIntent` (Phase 2).

### Goal / Definition of Done
- `ActivityWidgetUI` exposes a `ActivityRingView(snapshot:)` (filled/empty ring +
  count) used by both widgets and later by the app.
- A timeline provider supplies `WidgetSnapshot` from the shared DB.
- `ToggleActivityComplication` (kind `"ToggleActivity"`): interactive, full-area
  `Button(intent: ToggleActivityIntent())`.
- `OpenAppComplication` (kind `"OpenApp"`): `.widgetURL(URL("activitytracker://open"))`.
- Both registered in `ActivityWidgetBundle` (`App/Widget`).
- Renders correctly on the watch face and in the Smart Stack
  (`containerBackground` only affects Smart Stack — fine).
- Updates after a toggle (timeline reload from the intent).

### Prerequisites
Phases 1–2 complete (DB client + intents).

### Tasks
1. In `ActivityWidgetUI`:
   - `ActivityRingView(snapshot: WidgetSnapshot)`:
     - active → fully filled circle (accent color);
     - idle → thin outline ring only;
     - count rendered at the top inside the circle.
   - Keep it pure SwiftUI; no DB access here.
2. Timeline provider (in the widget extension, `App/Widget` or a small file in
   `ActivityWidgetUI` consumed by the extension):
   - `TimelineProvider`/`AppIntentTimelineProvider` that calls
     `database.snapshot()` and returns a single entry; refresh policy `.never`
     (we drive updates via `reloadAllTimelines()` after writes) plus a periodic
     fallback so in-progress duration visuals stay fresh if needed.
   - Bootstrap DB via the Phase 2 `IntentDependencies.bootstrap()` helper.
3. `ToggleActivityComplication` widget:
   - `StaticConfiguration` (kind `"ToggleActivity"`), `.accessoryCircular`.
   - Body wraps `ActivityRingView` in `Button(intent: ToggleActivityIntent())`
     with `.buttonStyle(.plain)` so the whole circle is the tap target.
4. `OpenAppComplication` widget:
   - `StaticConfiguration` (kind `"OpenApp"`), `.accessoryCircular`.
   - Body is `ActivityRingView` + `.widgetURL(URL(string: "activitytracker://open")!)`.
5. Register both in `App/Widget/ActivityWidgetBundle.swift`.
6. Provide sample/placeholder snapshots for the widget gallery and redacted/
   Always-On states.

### Files to create / modify
- `Sources/ActivityWidgetUI/ActivityRingView.swift`
- `Sources/ActivityWidgetUI/ActivitySnapshotProvider.swift` (timeline provider)
- `App/Widget/ToggleActivityComplication.swift`
- `App/Widget/OpenAppComplication.swift`
- `App/Widget/ActivityWidgetBundle.swift` (modify: register both)
- `Tests/` — snapshot/state-mapping tests for `ActivityRingView` inputs if practical

### Verification
- Both complications appear in the watch face complication picker and Smart Stack.
- Idle: empty ring + count. Start one activity (via app or intent): toggle
  complication shows a filled ring; count increments.
- Tapping the **toggle** complication flips the ring without opening the app
  (per Phase 2 spike outcome).
- Tapping the **open-app** complication launches the app (deep link handled in
  Phase 4).
- Always-On / redacted rendering looks acceptable.

### Notes / risks
- `.accessoryCircular` is small; keep the count legible (1–2 digits expected).
  If counts exceed 99, cap display at `99+`.
- `containerBackground(for: .widget)` is required for Smart Stack; it is ignored
  on the watch face — set it and verify both surfaces.
- If the Phase 2 spike showed the watch-face tap launches the app, keep the
  toggle complication primarily for the Smart Stack and document it.

---

## Phase 4 — App shell (`AppFeature`) + deep links + state refresh

### Context recap
The watch app is a thin host; all logic is in `AppFeature` (root coordinator) per
the baseline. `AppFeature` owns navigation, the `activitytracker://` deep link
(from the open-app complication), pending-action resolution, and cross-feature
coordination. It must refresh when the app becomes active (the widget/extension
may have changed the DB) and when the database changes (SQLiteData live queries).

### Goal / Definition of Done
- `ActivityTrackerApp.swift` calls `prepareDependencies` (install persistent
  `ActivityDatabase` with in-memory fallback) and builds the root `Store`.
- `AppFeature` reducer with `@ObservableState`, composing child features via
  `Scope` (DayList added in Phase 5; for now host a minimal Day List placeholder
  or the real one if Phase 5 lands first).
- Deep link handling: `activitytracker://open` routes to the Day List root.
- On `scenePhase == .active`, AppFeature triggers a refresh of derived state.
- Pending-action pattern: if a shortcut/intent persisted a pending route, resolve
  it when the app becomes active (baseline rule) — wire the plumbing even if the
  only route today is "open".
- `AppFeatureTests` cover deep-link routing and active-phase refresh.

### Prerequisites
Phases 1–2 (DB + intents). Phase 3 helpful but not strictly required. Can proceed
in parallel with Phase 5 if interfaces are agreed.

### Tasks
1. `AppFeature`:
   - State: holds child feature state (DayList), current route/destination via
     `@Presents` where needed.
   - Actions: `.onAppear`, `.scenePhaseChanged(ScenePhase)`,
     `.deepLink(URL)`, child actions.
   - Reducer: on `.deepLink`, parse `activitytracker://open` → ensure DayList is
     shown. On active phase → send refresh to children. Use `._printChanges()` in
     debug.
2. `ActivityTrackerApp.swift`:
   - `prepareDependencies { $0.activityDatabase = .liveValue(...) }` with
     persistent App Group DB; fall back to in-memory on failure (baseline).
   - Build `Store(initialState:) { AppFeature() }`; host root view.
   - Forward `.onOpenURL` and `scenePhase` changes into the store.
3. Root view: thin `AppView` rendering the DayList (or placeholder) and any
   presented destinations.
4. Deep-link parser util in `Shared` (`DeepLink` enum: `.open`).

### Files to create / modify
- `App/Watch/ActivityTrackerApp.swift` (modify: real wiring)
- `Sources/AppFeature/AppFeature.swift`
- `Sources/AppFeature/AppView.swift`
- `Sources/Shared/DeepLink.swift`
- `Tests/AppFeatureTests/AppFeatureTests.swift`

### Verification
- Launching from the open-app complication opens the app to the Day List.
- After toggling via the widget while the app is backgrounded, foregrounding the
  app shows the updated count/state.
- `AppFeatureTests` (TestStore): `.deepLink(open)` sets the expected route;
  `.scenePhaseChanged(.active)` issues the refresh effect; no business logic in
  the app target.

### Notes / risks
- Keep navigation ownership only in `AppFeature` (baseline non-goal: no duplicated
  navigation ownership).
- For live DB observation, prefer SQLiteData's observation/`@FetchAll` in the
  feature that displays data (Phase 5) rather than manual polling; the
  active-phase refresh is a backstop for cross-process writes.

---

## Phase 5 — Day List feature (day cards + 0–24h timeline)

### Context recap
The app's main screen is a vertical list of **day cards** (today on top, then
descending). Each card shows the day's activity **count** on the left and a
**horizontal 0–24h track** on the right with filled **segments** for each activity
that day. Segment math and midnight splitting are defined in §4.2. This is a
`DayListFeature` TCA module reading via the `ActivityDatabase` client / SQLiteData
live queries.

### Goal / Definition of Done
- `DayListFeature` reducer + views render N most-recent days (e.g., last 30 days,
  decide a window; lazy-load older on scroll).
- Each `DayCardView`:
  - left: count of activities for that day;
  - right: 0–24h track with proportional segments (clipped to the day);
  - in-progress activity renders up to "now" and visually distinct (e.g., pulsing
    or lighter fill).
- Reuses accent styling consistent with the widget ring.
- `DayListFeatureTests` cover day bucketing, segment computation, midnight split,
  and in-progress rendering data.

### Prerequisites
Phase 1 (DB client). Integrates under `AppFeature` (Phase 4).

### Tasks
1. Define presentation models computed from `[Activity]`:
   - `DayCard { date: Date; count: Int; segments: [ActivitySegment] }`
   - `ActivitySegment { start: Double; end: Double; isInProgress: Bool }` where
     `start`/`end` are fractions of the day in `[0, 1]` (or minutes 0…1440).
2. Pure mapping function `makeDayCards(activities:calendar:now:)` →
   `[DayCard]` that:
   - buckets activities by start day;
   - splits midnight-spanning activities into per-day segments;
   - clips each segment to `[dayStart, dayEnd)`;
   - marks in-progress segments (open end → `now`).
   Keep this pure and unit-test it hard (no I/O).
3. `DayListFeature` reducer:
   - State: list of `DayCard` (or raw activities + derived cards), loading state,
     the visible day window.
   - Loads activities via `ActivityDatabase` for the window; recomputes cards.
   - Refresh action (called by AppFeature on active phase) reloads.
   - Optional: subscribe to DB changes for live updates while open.
4. Views:
   - `DayListView`: `List`/`ScrollView` of `DayCardView`, today first.
   - `DayCardView`: HStack [count] [HourTrackView]; `HourTrackView` draws the
     0–24 axis (lightweight ticks at 0/6/12/18/24) and the segments via `Canvas`
     or stacked capsules.
5. Hook `DayListFeature` into `AppFeature` (replace any Phase 4 placeholder).

### Files to create / modify
- `Sources/DayListFeature/DayListFeature.swift`
- `Sources/DayListFeature/DayCardModel.swift` (DayCard, ActivitySegment, mapping)
- `Sources/DayListFeature/DayListView.swift`
- `Sources/DayListFeature/DayCardView.swift`
- `Sources/DayListFeature/HourTrackView.swift`
- `Sources/AppFeature/AppFeature.swift` (modify: compose DayList)
- `Tests/DayListFeatureTests/DayCardModelTests.swift`
- `Tests/DayListFeatureTests/DayListFeatureTests.swift`

### Verification
- `DayCardModelTests` (pure): single activity within a day → one correctly
  positioned segment; activity 23:30→00:30 → two segments on adjacent days,
  correctly clipped; in-progress activity → segment ends at `now` and is flagged;
  count matches activities started that day.
- `DayListFeatureTests` (TestStore): load populates cards; refresh reloads after a
  simulated DB change; empty day shows count 0 and empty track.
- On device: today's card updates after starting/stopping via the complication
  (foreground refresh).

### Notes / risks
- Watch screen is small; the hour track must stay readable. Consider showing only
  a few axis labels (0, 12, 24) and rely on segment positions.
- Decide the initial day window (recommend 14–30 days) and lazy-load older days
  to keep memory/scroll smooth.
- Keep the heavy mapping pure and off the main actor if it grows.

---

## Phase 6 — Activity Session (optional countdown) + integration polish

### Context recap
Core flows exist: complications toggle/open, the app shows day cards. This phase
adds the optional "timer + Cancel" confirmation surface (§2.4), guarantees the
widget and app stay in sync, and handles polish: Always-On, accessibility,
localization (RU/EN), empty states, and a final end-to-end pass.

### Goal / Definition of Done
- (If pursued) `ActivitySessionFeature`: when entered via the open-app path with a
  pending start/stop, show an N-second countdown with a **Cancel** button; commit
  the toggle only when the countdown completes; Cancel aborts with no DB change.
- Widget ↔ app state stays consistent across processes (writes reload timelines;
  app refreshes on active phase / DB observation).
- Accessibility: VoiceOver labels for the ring ("Activity in progress / not in
  progress, N today") and day cards.
- Localization: RU + EN strings (the user communicates in Russian); use
  `String(localized:)` / String Catalog. No hardcoded user-facing strings.
- Empty/first-run state (no activities yet) is friendly and motivating.
- `AppFeatureTests` cover the cross-feature session flow if built.

### Prerequisites
Phases 1–5 complete.

### Tasks
1. (Optional, per §2.4) `ActivitySessionFeature`:
   - State: `pendingAction` (start/stop), `remaining` countdown, running flag.
   - Uses `@Dependency(\.continuousClock)` for the countdown; commits via
     `ActivityDatabase` on completion; Cancel cancels the effect.
   - Presented by `AppFeature` when a deep link / pending action requests it.
   - Wire `StartActivityIntent`/`StopActivityIntent` with `openAppWhenRun = true`
     variants (or a pending-action payload) to route here if this mode is enabled.
2. State sync hardening:
   - Ensure every DB write path (intents + in-app) calls
     `WidgetCenter.shared.reloadAllTimelines()`.
   - Verify app shows fresh data after background widget toggles.
3. Accessibility + Always-On:
   - Add `accessibilityLabel`/`accessibilityValue` to ring and cards.
   - Verify Always-On rendering of complications and app.
4. Localization:
   - Add a String Catalog; provide RU + EN. Localize widget gallery names,
     VoiceOver labels, and app copy.
5. Empty state + motivation copy (count 0 / no in-progress).
6. Final pass: run all tests; build app + widget; manual end-to-end on simulator
   (toggle from complication, open from complication, see day card update, start a
   long activity and confirm it renders as in-progress across midnight if testable).

### Files to create / modify
- `Sources/ActivitySessionFeature/ActivitySessionFeature.swift` (if pursued)
- `Sources/ActivitySessionFeature/ActivitySessionView.swift` (if pursued)
- `Sources/AppFeature/AppFeature.swift` (modify: present session, pending actions)
- String Catalog(s) in `App/` and/or per-package resources
- `Tests/ActivitySessionFeatureTests/ActivitySessionFeatureTests.swift`

### Verification
- (If built) Session countdown commits on completion; Cancel makes no DB change
  (TestStore with controlled clock).
- Toggling from the widget while the app is foregrounded updates the visible day
  card within a refresh cycle.
- VoiceOver reads meaningful labels; RU and EN both render.
- Full `swift test` green; `xcodebuild` app+widget build green.

### Notes / risks
- The countdown mode is **optional** for the prototype; if §2 spike showed the
  interactive toggle is reliable, the countdown is a nice-to-have, not required.
- Watch continuous-clock effects must be cancellable on Cancel and on view
  dismissal to avoid committing after the user leaves.

---

## 7. Risks & open questions

| Risk / question | Impact | Mitigation / when resolved |
|-----------------|--------|----------------------------|
| Interactive complication tap may launch the app on the **watch face** (vs Smart Stack) | Core UX | Phase 2 on-device spike; if so, target Smart Stack for the toggle and/or use the §2.4 open-app+countdown flow |
| App Intent running in the **widget extension** needs a live DB | Toggle silently no-ops | `IntentDependencies.bootstrap()` opens the App Group DB in-process (Phase 2) |
| SQLiteData / StructuredQueries macro API specifics on the resolved version | Build errors | Verify macro syntax against the actually-resolved package in Phase 1; adjust |
| Cross-process write visibility (extension writes, app reads) | Stale UI | App Group DB + `reloadAllTimelines()` + active-phase refresh + DB observation |
| `.accessoryCircular` space for ring + count | Legibility | Cap count at `99+`; large bold numeral; thin ring |
| watchOS 26-only APIs / single supported version | Compatibility | Pin deployment target 26.0; no availability fallbacks needed |
| App Group identifier requires a real team ID | Build/signing | Choose in Phase 0; set in both entitlements + `AppGroup.swift` |

## 8. Backlog (explicitly NOT in the prototype)

- iOS companion app (reuse `Database`, `ActivityIntents`, feature logic; add an
  iOS app target to `project.yml` and iOS views).
- CloudKit sync (attach metadatabase at DB setup; keep migrations append-only).
- Activity categories/types, notes, manual editing of past sessions.
- Goals, streaks, notifications/reminders, complications variants (corner/inline).
- Statistics / weekly summaries.

## 9. Future iOS readiness checklist (informational)

When the iOS app is added later, the following should require **no rewrites**:

- `Database`, `ActivityIntents`, `DayListFeature`, `ActivitySessionFeature`,
  `AppFeature`, `Shared`, `ActivityWidgetUI` are already platform-portable SPM
  targets (Package declares `.iOS(.v26)` too).
- Add an iOS app target + iOS widget extension to `App/project.yml`.
- Reuse the same App Group + DB schema (or sync via CloudKit).
- Provide iOS-specific views where the watch layout doesn't translate (the day
  card timeline scales up well to iOS).

---

### Appendix A — Phase kickoff prompt template (for a fresh agent)

> You are implementing **Phase N** of the Activity Tracker watchOS app.
> 1. Read `IMPLEMENTATION_PLAN.md` §1–§5 and the **Phase N** section.
> 2. Read `~/Library/Mobile Documents/com~apple~CloudDocs/NEW_APP_TECHNICAL_INSTRUCTIONS.md`.
> 3. Confirm prerequisites (earlier phases) are present in the repo.
> 4. Implement only Phase N's tasks. Follow §5 conventions and Definition of Done.
> 5. Run the §5.4 build/verify commands and the phase's Verification checklist.
> 6. Do not start later phases. Report what you built and any deviations (update
>    §2 / §7 if a decision changed).












