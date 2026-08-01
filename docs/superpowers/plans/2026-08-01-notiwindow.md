# NotiWindow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Swift package that presents arbitrary SwiftUI content as top- or bottom-anchored toasts inside a dedicated passthrough `UIWindow` layered above the host app's UI, including sheets and system alerts.

**Architecture:** A `@MainActor @Observable NotiCenter` holds at most one presentation per edge and owns auto-dismiss timing behind an injectable sleeper seam. A `.notiWindow(center)` view modifier installs a `PassthroughWindow` at `windowLevel = .alert + 1` into the scene resolved from the view hierarchy. A `UIHostingController` renders `NotiRootView`, which draws the two independent slots with edge transitions and dismissal gestures.

**Tech Stack:** Swift 6.1 language mode (Xcode 26.5 / Swift 6.3 toolchain), SwiftUI, UIKit (`UIWindow`, `UIHostingController`, `UIViewRepresentable`), Swift Testing, Swift Package Manager.

**Reference spec:** `docs/superpowers/specs/2026-08-01-notiwindow-design.md`

## Global Constraints

- Package name `NotiWindow`; single library product `NotiWindow`.
- `swift-tools-version:6.1`, `swiftLanguageModes: [.v6]`.
- Platform: `.iOS("18.6")` only. No macOS, tvOS, watchOS, or visionOS.
- No third-party dependencies. Standard library, SwiftUI, and UIKit only.
- Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`), never XCTest.
- **No source-reading tests.** No test may load source with `String(contentsOf:)` / `#filePath` path math and assert with `source.contains(...)`. Protect invariants behaviorally through a seam, or as a pure function.
- **No wall-clock waits in tests.** No `Task.sleep`, no `Date()` poll loops. All timing is driven through the `NotiSleeper` seam.
- The package must know nothing about iAniList. No anime/media/AniList vocabulary anywhere.
- Public API is exactly the surface in the spec's "Public API" section, with the one documented deviation below.
- Test command used throughout: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

## Deviations From The Spec

These four points came out of working the design through to real code. They are
called out here so a reviewer can catch them rather than discover them in a diff.

1. **Expiry tasks are never cancelled.** The spec said replaced/dismissed toasts have
   their expiry tasks cancelled, and that host teardown cancels them. Correctness is
   instead carried entirely by token validation: an expiry task re-reads the slot and
   dismisses only if its own token still occupies it. Cancellation would additionally
   have required a cancellation-aware test double, and the spec's "cancel on host
   teardown" rule was actively wrong — it would have suppressed auto-dismiss for live
   toasts whenever a scene was rebuilt, leaving stale state on screen. Host teardown
   now touches no center state at all. Cost: an explicitly dismissed toast leaves one
   suspended task alive for at most its remaining duration. No user-visible effect.

2. **`\.notiCenter` is `NotiCenter?`, not `NotiCenter`.** An `EnvironmentValues`
   default must be constructible from a nonisolated context, and `NotiCenter.init()`
   is `@MainActor`-isolated, so a non-optional default is not expressible. Views read
   it as an optional.

3. **Scene resolution uses `didMoveToWindow`, not an `updateUIView` retry.** The spec
   described retrying scene lookup on the next `updateUIView`. `updateUIView` is not
   guaranteed to fire again once a view reaches a window, whereas `didMoveToWindow`
   fires exactly when it does — and at that moment `window?.windowScene` is always
   non-nil. Same guarantee, no polling.

4. **Passthrough hit-testing carries runtime risk.** Identity-against-root
   (`hitView === rootViewController?.view`) is the standard pattern and is what the
   spec approved, but it depends on how SwiftUI's hosting view reports hit tests for
   non-interactive regions. Task 12 verifies this empirically in the example app
   before the library is considered done, and documents a frame-reporting fallback if
   it fails.

---

## File Structure

**Package (`Sources/NotiWindow/`)**

| File | Responsibility |
|---|---|
| `NotiEdge.swift` | The two anchor positions. |
| `NotiDuration.swift` | How long a toast holds. |
| `NotiPresentation.swift` | `NotiToken` identity plus the internal presentation record. |
| `NotiSleeper.swift` | Timing seam protocol plus its `Task.sleep` implementation. |
| `NotiCenter.swift` | Slot state, present/dismiss semantics, expiry scheduling. |
| `Window/NotiHitTesting.swift` | Pure passthrough decision. |
| `Window/PassthroughWindow.swift` | `UIWindow` subclass applying that decision. |
| `Window/NotiWindowHost.swift` | Owns the window and hosting controller. |
| `Window/NotiRootView.swift` | Renders both slots; per-slot transition and gestures. |
| `View/NotiWindowModifier.swift` | `.notiWindow(_:)` plus the scene-resolving installer. |
| `View/NotiToast.swift` | Batteries-included styled pill. |
| `Environment/NotiCenterKey.swift` | `\.notiCenter` environment value. |

**Tests (`Tests/NotiWindowTests/`)**

| File | Responsibility |
|---|---|
| `Support/ManualSleeper.swift` | Test double driving timing deterministically. |
| `NotiCenterSlotTests.swift` | Slot occupancy and dismissal semantics. |
| `NotiCenterTimingTests.swift` | Auto-dismiss, indefinite, replacement freshness. |
| `NotiHitTestingTests.swift` | Passthrough decision truth table. |
| `NotiWindowHostTests.swift` | Window level, key status, clear backgrounds. |

**Example (`Example/`)** — `NotiWindowExample.xcodeproj` plus a `NotiWindowExample/` source folder.

---

### Task 1: Convert the repository into a Swift package

The scaffold is an Xcode framework project. It must become a package, and the
`.xcodeproj` must leave the repository root so `xcodebuild` resolves `Package.swift`
rather than the project.

**Files:**
- Create: `Package.swift`
- Create: `Sources/NotiWindow/NotiEdge.swift`
- Create: `Tests/NotiWindowTests/NotiEdgeTests.swift`
- Delete: `NotiWindow/NotiWindow.swift`, `NotiWindow/NotiWindow.docc/`, `NotiWindowTests/NotiWindowTests.swift`, `NotiWindow.xcodeproj/`

**Interfaces:**
- Consumes: nothing.
- Produces: `NotiEdge` — `public enum NotiEdge: Sendable, Hashable, CaseIterable { case top, bottom }`. A working `xcodebuild test` invocation every later task reuses.

- [ ] **Step 1: Remove the framework scaffold**

```bash
cd /Users/justin/dev/ios/NotiWindow
git rm -r --quiet NotiWindow NotiWindowTests NotiWindow.xcodeproj
```

- [ ] **Step 2: Create `Package.swift`**

```swift
// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "NotiWindow",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "NotiWindow", targets: ["NotiWindow"]),
    ],
    targets: [
        .target(name: "NotiWindow"),
        .testTarget(name: "NotiWindowTests", dependencies: ["NotiWindow"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 3: Write the failing test**

Create `Tests/NotiWindowTests/NotiEdgeTests.swift`:

```swift
import Testing
@testable import NotiWindow

@Suite("NotiEdge")
struct NotiEdgeTests {
    @Test("Enumerates exactly the two anchor positions")
    func enumeratesBothAnchors() {
        #expect(NotiEdge.allCases == [.top, .bottom])
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'NotiEdge' in scope`.

If instead the scheme cannot be found, run `xcodebuild -list` in the package root and use the scheme it reports; SPM auto-generates a scheme named after the package.

- [ ] **Step 5: Write the minimal implementation**

Create `Sources/NotiWindow/NotiEdge.swift`:

```swift
/// The screen edge a toast is anchored to.
///
/// Each edge is an independent single-occupancy slot: a top toast and a bottom
/// toast may be on screen simultaneously, and presenting on one edge never
/// disturbs the other.
public enum NotiEdge: Sendable, Hashable, CaseIterable {
    case top
    case bottom
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "build: convert scaffold into a Swift package"
```

---

### Task 2: Duration, token, and presentation record

**Files:**
- Create: `Sources/NotiWindow/NotiDuration.swift`
- Create: `Sources/NotiWindow/NotiPresentation.swift`
- Create: `Tests/NotiWindowTests/NotiPresentationTests.swift`

**Interfaces:**
- Consumes: `NotiEdge` (Task 1).
- Produces:
  - `public enum NotiDuration: Sendable, Hashable { case seconds(Double); case indefinite; public static let standard: NotiDuration }`
  - `public struct NotiToken: Hashable, Sendable` with an internal `init()` minting fresh identity and no public members.
  - `struct NotiPresentation` (internal) with `let token: NotiToken`, `let edge: NotiEdge`, `let content: AnyView`, `let duration: NotiDuration`, `let dismissOnTap: Bool`, `let dismissOnSwipe: Bool`.

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/NotiPresentationTests.swift`:

```swift
import SwiftUI
import Testing
@testable import NotiWindow

@Suite("Presentation values")
struct NotiPresentationTests {
    @Test("Standard duration is three seconds")
    func standardDurationIsThreeSeconds() {
        #expect(NotiDuration.standard == .seconds(3))
    }

    @Test("Each token is distinct")
    func tokensAreDistinct() {
        #expect(NotiToken() != NotiToken())
    }

    @Test("A token equals itself")
    func tokenEqualsItself() {
        let token = NotiToken()
        #expect(token == token)
    }

    @MainActor
    @Test("A presentation retains the values it was built with")
    func presentationRetainsItsValues() {
        let token = NotiToken()
        let presentation = NotiPresentation(
            token: token,
            edge: .top,
            content: AnyView(Text("hello")),
            duration: .indefinite,
            dismissOnTap: false,
            dismissOnSwipe: true
        )

        #expect(presentation.token == token)
        #expect(presentation.edge == .top)
        #expect(presentation.duration == .indefinite)
        #expect(presentation.dismissOnTap == false)
        #expect(presentation.dismissOnSwipe == true)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'NotiDuration' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/NotiWindow/NotiDuration.swift`:

```swift
/// How long a toast holds before dismissing itself.
public enum NotiDuration: Sendable, Hashable {
    /// Hold for a fixed interval, then dismiss.
    case seconds(Double)

    /// Never auto-dismiss. The caller is responsible for dismissing, using the
    /// token returned by `NotiCenter.present`.
    case indefinite

    /// The default hold for a transient toast.
    public static let standard: NotiDuration = .seconds(3)
}
```

Create `Sources/NotiWindow/NotiPresentation.swift`:

```swift
import Foundation
import SwiftUI

/// Opaque identity for one presentation.
///
/// Returned by `NotiCenter.present` so an `.indefinite` toast can be dismissed
/// later. Dismissing by token is safe against replacement: if the slot has since
/// been taken by another toast, the dismissal is a no-op rather than tearing down
/// an unrelated toast.
public struct NotiToken: Hashable, Sendable {
    private let id: UUID

    init() {
        id = UUID()
    }
}

/// One toast occupying one edge slot.
///
/// Content is type-erased so `NotiCenter` stays non-generic and can be stored and
/// passed freely. With at most two live toasts the cost is irrelevant.
struct NotiPresentation {
    let token: NotiToken
    let edge: NotiEdge
    let content: AnyView
    let duration: NotiDuration
    let dismissOnTap: Bool
    let dismissOnSwipe: Bool
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add duration, token, and presentation record"
```

---

### Task 3: Timing seam and its test double

The sleeper is what makes auto-dismiss testable without wall-clock waits. Build it
before `NotiCenter` so the center can take it as a dependency from the start.

**Files:**
- Create: `Sources/NotiWindow/NotiSleeper.swift`
- Create: `Tests/NotiWindowTests/Support/ManualSleeper.swift`
- Create: `Tests/NotiWindowTests/ManualSleeperTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `@MainActor protocol NotiSleeper { func sleep(for duration: Duration) async throws }` (internal)
  - `struct TaskNotiSleeper: NotiSleeper` (internal) — production implementation.
  - `ManualSleeper` (test-only) with `var requestedDurations: [Duration]`, `func awaitSleepRequest() async`, `func fireNext()`, `var pendingCount: Int`.

The protocol is `@MainActor`-isolated deliberately: `NotiCenter` is `@MainActor`, so
every call site already is, and isolating the protocol lets `ManualSleeper` hold plain
mutable state without locks or `@unchecked Sendable`.

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/ManualSleeperTests.swift`:

```swift
import Testing
@testable import NotiWindow

@Suite("ManualSleeper")
@MainActor
struct ManualSleeperTests {
    @Test("A sleep stays suspended until fired")
    func sleepSuspendsUntilFired() async {
        let sleeper = ManualSleeper()

        let task = Task { try? await sleeper.sleep(for: .seconds(3)) }

        await sleeper.awaitSleepRequest()
        #expect(sleeper.pendingCount == 1)
        #expect(sleeper.requestedDurations == [.seconds(3)])

        sleeper.fireNext()
        await task.value

        #expect(sleeper.pendingCount == 0)
    }

    @Test("Sleeps fire in the order they were requested")
    func sleepsFireInOrder() async {
        let sleeper = ManualSleeper()

        let first = Task { try? await sleeper.sleep(for: .seconds(1)) }
        await sleeper.awaitSleepRequest()

        let second = Task { try? await sleeper.sleep(for: .seconds(2)) }
        await sleeper.awaitSleepRequest(count: 2)

        #expect(sleeper.requestedDurations == [.seconds(1), .seconds(2)])

        // Awaiting `first` here only returns if `fireNext` resumed the OLDEST sleep.
        // Had it resumed the newer one, this would hang rather than pass.
        sleeper.fireNext()
        await first.value
        #expect(sleeper.pendingCount == 1)

        sleeper.fireNext()
        await second.value
        #expect(sleeper.pendingCount == 0)
    }
}
```

These tests deliberately assert through `pendingCount` rather than a captured
`var finished`. Mutating a captured local from inside a `Task` is rejected under
Swift 6 strict concurrency.

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'ManualSleeper' in scope`.

- [ ] **Step 3: Write the production seam**

Create `Sources/NotiWindow/NotiSleeper.swift`:

```swift
/// Timing seam for auto-dismiss.
///
/// Isolated to the main actor because every call site already is — `NotiCenter` is
/// `@MainActor`, and its expiry tasks inherit that isolation. Isolating the protocol
/// lets test doubles hold plain mutable state.
@MainActor
protocol NotiSleeper {
    func sleep(for duration: Duration) async throws
}

/// Production sleeper. Suspends without blocking the main actor.
struct TaskNotiSleeper: NotiSleeper {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
```

- [ ] **Step 4: Write the test double**

Create `Tests/NotiWindowTests/Support/ManualSleeper.swift`:

```swift
@testable import NotiWindow

/// Sleeper whose suspensions resume only when a test says so.
///
/// Keeps timing tests free of wall-clock waits: a test registers a sleep, asserts
/// nothing has happened yet, then fires it and awaits the resulting work directly.
@MainActor
final class ManualSleeper: NotiSleeper {
    /// Every duration asked for, in request order.
    private(set) var requestedDurations: [Duration] = []

    private var pending: [CheckedContinuation<Void, Never>] = []

    /// How many sleeps are currently suspended.
    var pendingCount: Int { pending.count }

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        await withCheckedContinuation { continuation in
            pending.append(continuation)
        }
    }

    /// Resume the oldest suspended sleep, as though its duration had elapsed.
    func fireNext() {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume()
    }

    /// Suspend until at least `count` sleeps are registered.
    ///
    /// Yields rather than waiting on the clock. Expiry work runs on the main actor,
    /// so yielding is enough to let a just-spawned task reach its `sleep` call.
    func awaitSleepRequest(count: Int = 1) async {
        while pending.count < count {
            await Task.yield()
        }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add timing seam and manual sleeper test double"
```

---

### Task 4: NotiCenter slot semantics

Presentation and dismissal only. Timing arrives in Task 5.

**Files:**
- Create: `Sources/NotiWindow/NotiCenter.swift`
- Create: `Tests/NotiWindowTests/NotiCenterSlotTests.swift`

**Interfaces:**
- Consumes: `NotiEdge`, `NotiDuration`, `NotiToken`, `NotiPresentation`, `NotiSleeper`, `TaskNotiSleeper`.
- Produces:
  - `@MainActor @Observable public final class NotiCenter`
  - `public init()`
  - `init(sleeper: NotiSleeper)` (internal, for tests)
  - `@discardableResult public func present(_ edge: NotiEdge = .bottom, duration: NotiDuration = .standard, dismissOnTap: Bool = true, dismissOnSwipe: Bool = true, @ViewBuilder content: () -> some View) -> NotiToken`
  - `public func dismiss(_ edge: NotiEdge)`
  - `public func dismiss(_ token: NotiToken)`
  - `public func dismissAll()`
  - `func presentation(for edge: NotiEdge) -> NotiPresentation?` (internal — the view and tests read slots through this)

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/NotiCenterSlotTests.swift`:

```swift
import SwiftUI
import Testing
@testable import NotiWindow

@Suite("NotiCenter slots")
@MainActor
struct NotiCenterSlotTests {
    private func makeCenter() -> (NotiCenter, ManualSleeper) {
        let sleeper = ManualSleeper()
        return (NotiCenter(sleeper: sleeper), sleeper)
    }

    @Test("Both slots start empty")
    func slotsStartEmpty() {
        let (center, _) = makeCenter()
        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Presenting populates the requested slot")
    func presentPopulatesRequestedSlot() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("hello") }

        #expect(center.presentation(for: .top)?.token == token)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Presenting defaults to the bottom edge")
    func presentDefaultsToBottom() {
        let (center, _) = makeCenter()
        let token = center.present { Text("hello") }

        #expect(center.presentation(for: .bottom)?.token == token)
    }

    @Test("Presenting on the same edge replaces the current occupant")
    func sameEdgePresentReplaces() {
        let (center, _) = makeCenter()
        let first = center.present(.bottom) { Text("first") }
        let second = center.present(.bottom) { Text("second") }

        #expect(first != second)
        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Top and bottom slots are independent")
    func slotsAreIndependent() {
        let (center, _) = makeCenter()
        let top = center.present(.top) { Text("top") }
        let bottom = center.present(.bottom) { Text("bottom") }

        #expect(center.presentation(for: .top)?.token == top)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }

    @Test("Dismissing an edge clears only that edge")
    func dismissEdgeClearsOnlyThatEdge() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        let bottom = center.present(.bottom) { Text("bottom") }

        center.dismiss(.top)

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }

    @Test("Dismissing all clears both edges")
    func dismissAllClearsBoth() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        center.present(.bottom) { Text("bottom") }

        center.dismissAll()

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Dismissing by token clears the slot it occupies")
    func dismissByTokenClearsItsSlot() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("top") }

        center.dismiss(token)

        #expect(center.presentation(for: .top) == nil)
    }

    @Test("Dismissing a replaced token leaves the replacement alone")
    func dismissingReplacedTokenIsNoOp() {
        let (center, _) = makeCenter()
        let first = center.present(.bottom) { Text("first") }
        let second = center.present(.bottom) { Text("second") }

        center.dismiss(first)

        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Presentation carries the dismissal flags it was given")
    func presentationCarriesDismissalFlags() {
        let (center, _) = makeCenter()
        center.present(.top, dismissOnTap: false, dismissOnSwipe: false) { Text("x") }

        let presentation = center.presentation(for: .top)
        #expect(presentation?.dismissOnTap == false)
        #expect(presentation?.dismissOnSwipe == false)
    }

    @Test("Dismissal flags default to enabled")
    func dismissalFlagsDefaultToEnabled() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("x") }

        let presentation = center.presentation(for: .top)
        #expect(presentation?.dismissOnTap == true)
        #expect(presentation?.dismissOnSwipe == true)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'NotiCenter' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/NotiWindow/NotiCenter.swift`:

```swift
import SwiftUI

/// App-wide toast presentation.
///
/// Holds at most one toast per edge. The two edges are independent slots, so a top
/// and a bottom toast may be on screen at once; presenting again on an occupied edge
/// replaces its occupant.
///
/// The center owns state and timing but knows nothing about windows. A
/// `.notiWindow(center)` modifier renders whatever the center currently holds, which
/// is why a toast presented before the window installs is not lost.
@MainActor
@Observable
public final class NotiCenter {
    private var slots: [NotiEdge: NotiPresentation] = [:]

    @ObservationIgnored private let sleeper: NotiSleeper

    /// Expiry work, kept per edge so tests can await it. Tasks are never cancelled —
    /// each one re-checks that its own token still occupies the slot before
    /// dismissing, so a stale timer cannot cut short the toast that replaced it.
    @ObservationIgnored private var expiryTasks: [NotiEdge: Task<Void, Never>] = [:]

    public init() {
        sleeper = TaskNotiSleeper()
    }

    init(sleeper: NotiSleeper) {
        self.sleeper = sleeper
    }

    /// The toast currently occupying `edge`, if any.
    func presentation(for edge: NotiEdge) -> NotiPresentation? {
        slots[edge]
    }

    /// Expiry work scheduled for `edge`, if any. Test seam.
    func expiryTask(for edge: NotiEdge) -> Task<Void, Never>? {
        expiryTasks[edge]
    }

    /// Surface `content` at `edge`, replacing whatever occupies that edge.
    ///
    /// The returned token identifies this presentation for later dismissal, which
    /// matters most for `.indefinite` toasts that never dismiss themselves.
    @discardableResult
    public func present(
        _ edge: NotiEdge = .bottom,
        duration: NotiDuration = .standard,
        dismissOnTap: Bool = true,
        dismissOnSwipe: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> NotiToken {
        let presentation = NotiPresentation(
            token: NotiToken(),
            edge: edge,
            content: AnyView(content()),
            duration: duration,
            dismissOnTap: dismissOnTap,
            dismissOnSwipe: dismissOnSwipe
        )
        slots[edge] = presentation
        scheduleExpiry(for: presentation)
        return presentation.token
    }

    /// Clear whatever occupies `edge`.
    public func dismiss(_ edge: NotiEdge) {
        slots[edge] = nil
    }

    /// Clear the presentation identified by `token`.
    ///
    /// No-op if that presentation has already been replaced or dismissed, so a late
    /// dismissal cannot tear down an unrelated toast.
    public func dismiss(_ token: NotiToken) {
        for edge in NotiEdge.allCases where slots[edge]?.token == token {
            slots[edge] = nil
        }
    }

    /// Clear both edges.
    public func dismissAll() {
        slots.removeAll()
    }

    /// Schedule auto-dismiss for a fixed-duration presentation.
    ///
    /// `.indefinite` schedules nothing at all, so no task exists to fire later.
    ///
    /// Only the token and edge are captured, never the presentation itself — its
    /// `AnyView` content is not `Sendable` and cannot cross into the task.
    private func scheduleExpiry(for presentation: NotiPresentation) {
        let edge = presentation.edge
        let token = presentation.token

        guard case .seconds(let seconds) = presentation.duration else {
            expiryTasks[edge] = nil
            return
        }

        expiryTasks[edge] = Task { [weak self] in
            guard let self else { return }
            try? await sleeper.sleep(for: .seconds(seconds))
            // Dismissal is token-checked, so a timer belonging to a toast that has
            // since been replaced finds nothing to clear.
            dismiss(token)
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add NotiCenter slot semantics"
```

---

### Task 5: NotiCenter auto-dismiss timing

**Files:**
- Create: `Tests/NotiWindowTests/NotiCenterTimingTests.swift`
- Modify: `Sources/NotiWindow/NotiCenter.swift` (only if a test exposes a defect)

**Interfaces:**
- Consumes: `NotiCenter`, `ManualSleeper`, `NotiCenter.expiryTask(for:)`.
- Produces: no new API. This task proves the timing behavior already written in Task 4.

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/NotiCenterTimingTests.swift`:

```swift
import SwiftUI
import Testing
@testable import NotiWindow

@Suite("NotiCenter timing")
@MainActor
struct NotiCenterTimingTests {
    @Test("A toast dismisses itself when its duration elapses")
    func toastDismissesWhenDurationElapses() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("hello") }
        let expiry = center.expiryTask(for: .bottom)

        await sleeper.awaitSleepRequest()
        #expect(center.presentation(for: .bottom) != nil)
        #expect(sleeper.requestedDurations == [.seconds(3)])

        sleeper.fireNext()
        await expiry?.value

        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("An indefinite toast schedules no expiry at all")
    func indefiniteToastSchedulesNoExpiry() {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.top, duration: .indefinite) { Text("syncing") }

        #expect(center.expiryTask(for: .top) == nil)
        #expect(sleeper.requestedDurations.isEmpty)
        #expect(center.presentation(for: .top) != nil)
    }

    @Test("An indefinite toast dismisses only by token")
    func indefiniteToastDismissesByToken() {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        let token = center.present(.top, duration: .indefinite) { Text("syncing") }
        #expect(center.presentation(for: .top) != nil)

        center.dismiss(token)
        #expect(center.presentation(for: .top) == nil)
    }

    @Test("A replacing toast is granted a fresh full duration")
    func replacementGetsFreshDuration() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("first") }
        await sleeper.awaitSleepRequest()

        center.present(.bottom, duration: .seconds(5)) { Text("second") }
        await sleeper.awaitSleepRequest(count: 2)

        #expect(sleeper.requestedDurations == [.seconds(3), .seconds(5)])
    }

    @Test("A replaced toast's expiry does not dismiss its replacement")
    func staleExpiryDoesNotDismissReplacement() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("first") }
        await sleeper.awaitSleepRequest()
        let staleExpiry = center.expiryTask(for: .bottom)

        let second = center.present(.bottom, duration: .seconds(3)) { Text("second") }
        await sleeper.awaitSleepRequest(count: 2)

        // Fire the FIRST toast's timer. It must find its token gone and do nothing.
        sleeper.fireNext()
        await staleExpiry?.value

        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Expiry on one edge leaves the other edge alone")
    func expiryIsPerEdge() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.top, duration: .seconds(3)) { Text("top") }
        await sleeper.awaitSleepRequest()
        let topExpiry = center.expiryTask(for: .top)

        let bottom = center.present(.bottom, duration: .seconds(3)) { Text("bottom") }
        await sleeper.awaitSleepRequest(count: 2)

        sleeper.fireNext()
        await topExpiry?.value

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS. The behavior was implemented in Task 4; these tests pin it.

If any fail, fix `scheduleExpiry` / `dismiss(_ token:)` in `NotiCenter.swift` rather than weakening the test.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: pin NotiCenter auto-dismiss timing behavior"
```

---

### Task 6: Passthrough hit-testing

**Files:**
- Create: `Sources/NotiWindow/Window/NotiHitTesting.swift`
- Create: `Sources/NotiWindow/Window/PassthroughWindow.swift`
- Create: `Tests/NotiWindowTests/NotiHitTestingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum NotiHitTesting { static func passesThrough(hitView: UIView?, rootView: UIView?) -> Bool }` (internal)
  - `final class PassthroughWindow: UIWindow` (internal)

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/NotiHitTestingTests.swift`:

```swift
import UIKit
import Testing
@testable import NotiWindow

@Suite("NotiHitTesting")
@MainActor
struct NotiHitTestingTests {
    @Test("A miss passes through")
    func missPassesThrough() {
        let root = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: nil, rootView: root))
    }

    @Test("Hitting the transparent backdrop passes through")
    func backdropPassesThrough() {
        let root = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: root, rootView: root))
    }

    @Test("Hitting toast content does not pass through")
    func contentDoesNotPassThrough() {
        let root = UIView()
        let toast = UIView()
        root.addSubview(toast)

        #expect(NotiHitTesting.passesThrough(hitView: toast, rootView: root) == false)
    }

    @Test("A hit with no root view still does not pass through")
    func hitWithoutRootDoesNotPassThrough() {
        let toast = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: toast, rootView: nil) == false)
    }

    @Test("A miss with no root view passes through")
    func missWithoutRootPassesThrough() {
        #expect(NotiHitTesting.passesThrough(hitView: nil, rootView: nil))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'NotiHitTesting' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/NotiWindow/Window/NotiHitTesting.swift`:

```swift
import UIKit

/// The passthrough decision, isolated from `UIWindow` so it can be tested directly.
enum NotiHitTesting {
    /// Whether a hit-test result means "nothing of ours was touched", and the touch
    /// should therefore fall through to the app's own window.
    ///
    /// Identity against the root view is used rather than comparing against toast
    /// frames: frame math gets rounded corners, transforms, and in-flight transition
    /// geometry wrong, whereas "did we hit anything other than the transparent
    /// backdrop" is correct by construction.
    static func passesThrough(hitView: UIView?, rootView: UIView?) -> Bool {
        hitView == nil || hitView === rootView
    }
}
```

Create `Sources/NotiWindow/Window/PassthroughWindow.swift`:

```swift
import UIKit

/// A window that is invisible to touches except where a toast actually is.
///
/// Sits above the app's own window, so without this override it would swallow every
/// touch in the app. Controls inside a toast keep working normally, because a hit on
/// them resolves to a descendant rather than the backdrop.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        if NotiHitTesting.passesThrough(hitView: hitView, rootView: rootViewController?.view) {
            return nil
        }

        return hitView
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add passthrough window and hit-test decision"
```

---

### Task 7: Toast rendering

`NotiRootView` and its per-slot child. Built before the host so the host has something to render.

**Files:**
- Create: `Sources/NotiWindow/Window/NotiRootView.swift`

**Interfaces:**
- Consumes: `NotiCenter`, `NotiPresentation`, `NotiEdge`.
- Produces:
  - `struct NotiRootView: View` with `init(center: NotiCenter)` (internal)
  - `struct NotiSlotView: View` (internal, same file)

No unit tests: this is layout and gesture wiring with no extractable decision left
once `NotiHitTesting` and `NotiCenter` are separated out. It is exercised by the
example app in Tasks 11 and 12.

- [ ] **Step 1: Write the implementation**

Create `Sources/NotiWindow/Window/NotiRootView.swift`:

```swift
import SwiftUI

/// Root of the toast window: two independent edge slots over a transparent backdrop.
///
/// Nothing here is opaque or interactive except a live toast, which is what lets
/// `PassthroughWindow` hand every other touch back to the app.
struct NotiRootView: View {
    let center: NotiCenter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            slot(.top)
            slot(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func slot(_ edge: NotiEdge) -> some View {
        ZStack(alignment: edge == .top ? .top : .bottom) {
            // Non-interactive filler so the slot can align its toast without
            // becoming a touch target itself.
            Color.clear
                .allowsHitTesting(false)

            if let presentation = center.presentation(for: edge) {
                NotiSlotView(presentation: presentation, center: center)
                    .transition(transition(for: edge))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.3), value: center.presentation(for: edge)?.token)
    }

    /// Slide from the slot's own edge, degrading to a plain fade under Reduce Motion.
    private func transition(for edge: NotiEdge) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .move(edge: edge == .top ? .top : .bottom).combined(with: .opacity)
    }
}

/// One toast, with its dismissal gestures and layout insets.
struct NotiSlotView: View {
    let presentation: NotiPresentation
    let center: NotiCenter

    /// How far the toast must be dragged toward its own edge to dismiss.
    private static let dismissThreshold: CGFloat = 40

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        presentation.content
            .frame(maxWidth: 500)
            .padding(.horizontal, 16)
            .padding(presentation.edge == .top ? .top : .bottom, 8)
            .offset(y: dragOffset)
            .onTapGesture {
                guard presentation.dismissOnTap else { return }
                center.dismiss(presentation.token)
            }
            .gesture(dragGesture)
    }

    /// Drags toward the toast's own edge track the finger; drags away are ignored.
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard presentation.dismissOnSwipe else { return }
                dragOffset = clamped(value.translation.height)
            }
            .onEnded { _ in
                guard presentation.dismissOnSwipe else { return }

                if abs(dragOffset) > Self.dismissThreshold {
                    center.dismiss(presentation.token)
                } else {
                    withAnimation(.spring(duration: 0.2)) { dragOffset = 0 }
                }
            }
    }

    private func clamped(_ translation: CGFloat) -> CGFloat {
        presentation.edge == .top ? min(0, translation) : max(0, translation)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the existing tests to confirm nothing regressed**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: render top and bottom toast slots"
```

---

### Task 8: NotiWindowHost

**Files:**
- Create: `Sources/NotiWindow/Window/NotiWindowHost.swift`
- Create: `Tests/NotiWindowTests/NotiWindowHostTests.swift`

**Interfaces:**
- Consumes: `PassthroughWindow`, `NotiRootView`, `NotiCenter`.
- Produces:
  - `@MainActor final class NotiWindowHost` (internal)
  - `init(scene: UIWindowScene, center: NotiCenter)`
  - `let window: PassthroughWindow`
  - `func tearDown()`

- [ ] **Step 1: Write the failing test**

Create `Tests/NotiWindowTests/NotiWindowHostTests.swift`:

```swift
import UIKit
import Testing
@testable import NotiWindow

@Suite("NotiWindowHost")
@MainActor
struct NotiWindowHostTests {
    /// The scene the test runner's own window belongs to.
    ///
    /// The iOS test bundle runs inside a runner app, which always has a window
    /// scene. `#require` therefore treats a nil scene as a genuine failure — these
    /// tests cannot be meaningfully evaluated without one, and silently passing
    /// would hide that the window was never configured.
    private func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }

    @Test("The window sits above sheets and system alerts")
    func windowSitsAboveAlerts() throws {
        let scene = try #require(activeScene())
        let host = NotiWindowHost(scene: scene, center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.windowLevel == .alert + 1)
    }

    @Test("The window never becomes key")
    func windowNeverBecomesKey() throws {
        let scene = try #require(activeScene())
        let host = NotiWindowHost(scene: scene, center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isKeyWindow == false)
    }

    @Test("The window is visible")
    func windowIsVisible() throws {
        let scene = try #require(activeScene())
        let host = NotiWindowHost(scene: scene, center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isHidden == false)
    }

    @Test("Window and root view backgrounds are clear")
    func backgroundsAreClear() throws {
        let scene = try #require(activeScene())
        let host = NotiWindowHost(scene: scene, center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.backgroundColor == .clear)
        #expect(host.window.rootViewController?.view.backgroundColor == .clear)
    }

    @Test("Tearing down hides the window and releases its content")
    func tearDownHidesWindow() throws {
        let scene = try #require(activeScene())
        let host = NotiWindowHost(scene: scene, center: NotiCenter())

        host.tearDown()

        #expect(host.window.isHidden == true)
        #expect(host.window.rootViewController == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'NotiWindowHost' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/NotiWindow/Window/NotiWindowHost.swift`:

```swift
import SwiftUI
import UIKit

/// Owns the toast window for one scene.
///
/// This is the seam the `.notiWindow(_:)` modifier is a thin wrapper over: it can be
/// constructed directly against a scene, which is what makes the window's
/// configuration testable without driving a SwiftUI hierarchy.
///
/// Teardown deliberately touches no `NotiCenter` state. The center outlives the
/// window, so a rebuilt scene re-renders whatever is still live rather than
/// inheriting a cleared or frozen slot.
@MainActor
final class NotiWindowHost {
    let window: PassthroughWindow

    init(scene: UIWindowScene, center: NotiCenter) {
        let controller = UIHostingController(rootView: NotiRootView(center: center))
        controller.view.backgroundColor = .clear

        window = PassthroughWindow(windowScene: scene)
        window.rootViewController = controller
        window.backgroundColor = .clear
        // Above sheets and above system alerts — the reason this library exists.
        window.windowLevel = .alert + 1
        // Visible without ever becoming key, so the app keeps first responder and
        // text fields elsewhere are unaffected.
        window.isHidden = false
    }

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add NotiWindowHost"
```

---

### Task 9: Installation modifier and environment value

**Files:**
- Create: `Sources/NotiWindow/Environment/NotiCenterKey.swift`
- Create: `Sources/NotiWindow/View/NotiWindowModifier.swift`

**Interfaces:**
- Consumes: `NotiCenter`, `NotiWindowHost`.
- Produces:
  - `extension EnvironmentValues { public var notiCenter: NotiCenter? }`
  - `extension View { public func notiWindow(_ center: NotiCenter) -> some View }`
  - `extension View { public func notiWindow() -> some View }`

No unit tests: installation depends on a live view hierarchy attaching to a window.
Task 12 verifies it end to end in the example app.

- [ ] **Step 1: Write the environment value**

Create `Sources/NotiWindow/Environment/NotiCenterKey.swift`:

```swift
import SwiftUI

public extension EnvironmentValues {
    /// The toast center installed by `.notiWindow(_:)`, if one is.
    ///
    /// Optional because an `EnvironmentValues` default must be constructible from a
    /// nonisolated context, and `NotiCenter.init()` is main-actor isolated. Views
    /// below a `.notiWindow(_:)` always find a value here.
    @Entry var notiCenter: NotiCenter?
}
```

- [ ] **Step 2: Write the modifier**

Create `Sources/NotiWindow/View/NotiWindowModifier.swift`:

```swift
import SwiftUI
import UIKit

public extension View {
    /// Install a toast window for this view's scene, driven by `center`.
    ///
    /// Attach once at the app root. The center is supplied rather than created so
    /// non-view code can hold the same reference and present from anywhere.
    ///
    /// The window's lifetime tracks this view, so each scene in a multi-window app
    /// gets its own window and none leak.
    func notiWindow(_ center: NotiCenter) -> some View {
        background(NotiWindowInstaller(center: center).frame(width: 0, height: 0))
            .environment(\.notiCenter, center)
    }

    /// Install a toast window with a center this modifier owns.
    ///
    /// Convenient when every caller reaches the center through
    /// `@Environment(\.notiCenter)`. Apps that present from non-view code should use
    /// `notiWindow(_:)` and hold the center themselves.
    func notiWindow() -> some View {
        modifier(OwnedNotiWindowModifier())
    }
}

/// Holds a center for the no-argument `notiWindow()` overload.
private struct OwnedNotiWindowModifier: ViewModifier {
    @State private var center = NotiCenter()

    func body(content: Content) -> some View {
        content.notiWindow(center)
    }
}

/// Resolves the scene from the view hierarchy and installs the window into it.
///
/// Reading `window?.windowScene` from a view that is actually in the hierarchy gives
/// the exact scene, avoiding a `UIApplication.connectedScenes` guess that would pick
/// the wrong window in a multi-scene app.
private struct NotiWindowInstaller: UIViewRepresentable {
    let center: NotiCenter

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        let coordinator = context.coordinator
        let center = center

        // `didMoveToWindow` is the reliable signal — `updateUIView` is not guaranteed
        // to fire again once the view reaches a window.
        view.onMoveToWindow = { scene in
            guard coordinator.host == nil, let scene else { return }
            coordinator.host = NotiWindowHost(scene: scene, center: center)
        }

        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    static func dismantleUIView(_ uiView: InstallerView, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            coordinator.host?.tearDown()
            coordinator.host = nil
        }
    }

    @MainActor
    final class Coordinator {
        var host: NotiWindowHost?
    }
}

/// Zero-size view whose only job is to report the scene it lands in.
private final class InstallerView: UIView {
    var onMoveToWindow: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onMoveToWindow?(window?.windowScene)
    }
}
```

- [ ] **Step 3: Verify it compiles and tests still pass**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add .notiWindow installation modifier"
```

---

### Task 10: NotiToast convenience view

**Files:**
- Create: `Sources/NotiWindow/View/NotiToast.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `public struct NotiToast: View` with `public init(_ text: String, systemImage: String? = nil, tint: Color = .primary)`.

No unit tests: this is pure styling with no decision to extract. Task 11 exercises it.

- [ ] **Step 1: Write the implementation**

Create `Sources/NotiWindow/View/NotiToast.swift`:

```swift
import SwiftUI

/// A styled toast pill, for callers who do not want to build their own.
///
/// Entirely optional — `NotiCenter.present` accepts any view. This exists so simple
/// call sites are one-liners, and it depends on nothing in the windowing core.
public struct NotiToast: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color

    /// - Parameters:
    ///   - text: Already-localized copy. This view performs no string lookup.
    ///   - systemImage: Optional leading SF Symbol.
    ///   - tint: Colors the symbol only; text always uses the primary style.
    public init(_ text: String, systemImage: String? = nil, tint: Color = .primary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    VStack(spacing: 12) {
        NotiToast("Saved to your list")
        NotiToast("Couldn't save", systemImage: "exclamationmark.circle.fill", tint: .red)
        NotiToast("Syncing…", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
    }
    .padding()
}
```

- [ ] **Step 2: Verify it compiles and tests still pass**

Run: `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add NotiToast convenience view"
```

---

### Task 11: Example app

An Xcode project is required because SPM cannot build an iOS `.app`.

**Files:**
- Create: `Example/NotiWindowExample.xcodeproj/project.pbxproj`
- Create: `Example/NotiWindowExample/NotiWindowExampleApp.swift`
- Create: `Example/NotiWindowExample/DemoScreen.swift`

**Interfaces:**
- Consumes: the entire public API — `NotiCenter`, `NotiToast`, `.notiWindow(_:)`, `NotiEdge`, `NotiDuration`, `NotiToken`.
- Produces: a runnable app whose buttons cover every behavior claimed by the spec.

- [ ] **Step 1: Write the app entry point**

Create `Example/NotiWindowExample/NotiWindowExampleApp.swift`:

```swift
import NotiWindow
import SwiftUI

@main
struct NotiWindowExampleApp: App {
    /// Held here rather than created by the modifier, mirroring how a real app
    /// presents toasts from non-view code.
    @State private var center = NotiCenter()

    var body: some Scene {
        WindowGroup {
            DemoScreen(center: center)
                .notiWindow(center)
        }
    }
}
```

- [ ] **Step 2: Write the demo screen**

Create `Example/NotiWindowExample/DemoScreen.swift`:

```swift
import NotiWindow
import SwiftUI

struct DemoScreen: View {
    let center: NotiCenter

    @State private var isSheetPresented = false
    @State private var syncToken: NotiToken?

    var body: some View {
        NavigationStack {
            List {
                Section("Placement") {
                    Button("Bottom toast") {
                        center.present(.bottom) {
                            NotiToast("Saved to your list", systemImage: "checkmark.circle.fill", tint: .green)
                        }
                    }

                    Button("Top toast") {
                        center.present(.top) {
                            NotiToast("Connection restored", systemImage: "wifi", tint: .blue)
                        }
                    }

                    Button("Both at once") {
                        center.present(.top) {
                            NotiToast("Top", systemImage: "arrow.up", tint: .blue)
                        }
                        center.present(.bottom) {
                            NotiToast("Bottom", systemImage: "arrow.down", tint: .purple)
                        }
                    }

                    Button("Replace the bottom toast") {
                        center.present(.bottom) { NotiToast("First") }
                        center.present(.bottom) { NotiToast("Second replaced it") }
                    }
                }

                Section("Lifetime") {
                    Button(syncToken == nil ? "Start indefinite toast" : "Stop indefinite toast") {
                        if let token = syncToken {
                            center.dismiss(token)
                            syncToken = nil
                        } else {
                            syncToken = center.present(.top, duration: .indefinite) {
                                NotiToast("Syncing…", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
                            }
                        }
                    }

                    Button("Undismissable for 3 seconds") {
                        center.present(.bottom, dismissOnTap: false, dismissOnSwipe: false) {
                            NotiToast("Tap and swipe are disabled", systemImage: "hand.raised.fill", tint: .orange)
                        }
                    }
                }

                Section("Custom content") {
                    Button("Toast with a working button") {
                        center.present(.bottom, duration: .indefinite) {
                            UndoToast {
                                center.present(.top) { NotiToast("Undone") }
                            }
                        }
                    }
                }

                Section("The reason this library exists") {
                    Button("Present, then open a sheet") {
                        center.present(.bottom, duration: .seconds(30)) {
                            NotiToast("I should stay visible over the sheet", systemImage: "square.3.layers.3d", tint: .pink)
                        }
                        isSheetPresented = true
                    }
                }

                Section("Passthrough check") {
                    Button("Present, then tap this row") {
                        center.present(.top, duration: .seconds(30)) {
                            NotiToast("Rows below must still respond", systemImage: "hand.tap.fill", tint: .teal)
                        }
                    }

                    Button("Tap me while a toast is up") {
                        center.present(.bottom) { NotiToast("Passthrough works") }
                    }
                }
            }
            .navigationTitle("NotiWindow")
            .sheet(isPresented: $isSheetPresented) {
                SheetScreen(center: center)
            }
        }
    }
}

/// Proves that interactive content inside a toast keeps working.
private struct UndoToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Removed from list")
                .font(.callout)

            Spacer(minLength: 12)

            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SheetScreen: View {
    let center: NotiCenter

    var body: some View {
        NavigationStack {
            List {
                Text("A toast presented before this sheet opened should be visible on top of it.")

                Button("Present from inside the sheet") {
                    center.present(.bottom) {
                        NotiToast("Presented from the sheet", systemImage: "square.stack.3d.up.fill", tint: .indigo)
                    }
                }
            }
            .navigationTitle("Sheet")
        }
    }
}
```

- [ ] **Step 3: Create the Xcode project**

Create `Example/NotiWindowExample.xcodeproj/project.pbxproj` with exactly this content:

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		E100000A00000000000000A1 /* NotiWindow in Frameworks */ = {isa = PBXBuildFile; productRef = E100000900000000000000A1 /* NotiWindow */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		E100000200000000000000A1 /* NotiWindowExample.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NotiWindowExample.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		E100000300000000000000A1 /* NotiWindowExample */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = NotiWindowExample;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		E100000400000000000000A1 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				E100000A00000000000000A1 /* NotiWindow in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		E100000500000000000000A1 = {
			isa = PBXGroup;
			children = (
				E100000300000000000000A1 /* NotiWindowExample */,
				E100000600000000000000A1 /* Products */,
			);
			sourceTree = "<group>";
		};
		E100000600000000000000A1 /* Products */ = {
			isa = PBXGroup;
			children = (
				E100000200000000000000A1 /* NotiWindowExample.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		E100000700000000000000A1 /* NotiWindowExample */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = E100000B00000000000000A1 /* Build configuration list for PBXNativeTarget "NotiWindowExample" */;
			buildPhases = (
				E100000800000000000000A1 /* Sources */,
				E100000400000000000000A1 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				E100000300000000000000A1 /* NotiWindowExample */,
			);
			name = NotiWindowExample;
			packageProductDependencies = (
				E100000900000000000000A1 /* NotiWindow */,
			);
			productName = NotiWindowExample;
			productReference = E100000200000000000000A1 /* NotiWindowExample.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		E100000100000000000000A1 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 2650;
				TargetAttributes = {
					E100000700000000000000A1 = {
						CreatedOnToolsVersion = 26.5;
					};
				};
			};
			buildConfigurationList = E100000C00000000000000A1 /* Build configuration list for PBXProject "NotiWindowExample" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = E100000500000000000000A1;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				E100000D00000000000000A1 /* XCLocalSwiftPackageReference ".." */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = E100000600000000000000A1 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				E100000700000000000000A1 /* NotiWindowExample */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		E100000800000000000000A1 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		E100001000000000000000A1 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 18.6;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		E100001100000000000000A1 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 18.6;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		E100001200000000000000A1 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.justinf.NotiWindowExample;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		E100001300000000000000A1 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.justinf.NotiWindowExample;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		E100000B00000000000000A1 /* Build configuration list for PBXNativeTarget "NotiWindowExample" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				E100001200000000000000A1 /* Debug */,
				E100001300000000000000A1 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		E100000C00000000000000A1 /* Build configuration list for PBXProject "NotiWindowExample" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				E100001000000000000000A1 /* Debug */,
				E100001100000000000000A1 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		E100000D00000000000000A1 /* XCLocalSwiftPackageReference ".." */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = ..;
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		E100000900000000000000A1 /* NotiWindow */ = {
			isa = XCSwiftPackageProductDependency;
			productName = NotiWindow;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = E100000100000000000000A1 /* Project object */;
}
```

- [ ] **Step 4: Verify the project opens and builds**

```bash
cd /Users/justin/dev/ios/NotiWindow/Example
xcodebuild -list -project NotiWindowExample.xcodeproj
xcodebuild build -project NotiWindowExample.xcodeproj -scheme NotiWindowExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `-list` reports the `NotiWindowExample` scheme; the build succeeds.

**If the project fails to load** ("The project cannot be opened because it is in a future Xcode project file format" or a parse error), do not debug the pbxproj by hand. Recreate it through Xcode instead — File ▸ New ▸ Project ▸ iOS App named `NotiWindowExample`, saved to `Example/`, interface SwiftUI, then File ▸ Add Package Dependencies ▸ Add Local and select the repository root. Delete Xcode's generated `ContentView.swift` and `NotiWindowExampleApp.swift`, keeping the two files written in Steps 1 and 2. Then re-run the build command above.

- [ ] **Step 5: Verify the package tests still pass from the repository root**

Run: `cd /Users/justin/dev/ios/NotiWindow && xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS. This confirms the example project did not shadow the package at the root.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add example app exercising the public API"
```

---

### Task 12: Runtime verification and README

The library's central claim — a toast renders above a sheet while the app stays
usable underneath — has not yet been observed. This task observes it.

**Files:**
- Create: `README.md`
- Modify: `Sources/NotiWindow/Window/NotiRootView.swift` (only if verification fails)

**Interfaces:**
- Consumes: everything.
- Produces: a verified library and its documentation.

- [ ] **Step 1: Launch the example app on the simulator**

```bash
cd /Users/justin/dev/ios/NotiWindow/Example
xcodebuild build -project NotiWindowExample.xcodeproj -scheme NotiWindowExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
xcrun simctl install booted \
  "$(xcodebuild -project NotiWindowExample.xcodeproj -scheme NotiWindowExample \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}' | head -1)/NotiWindowExample.app"
xcrun simctl launch booted dev.justinf.NotiWindowExample
```

- [ ] **Step 2: Verify each claim, capturing a screenshot per check**

Use `xcrun simctl io booted screenshot <path>` after each interaction. If tapping
the simulator programmatically is unavailable, drive it by hand and use the
`inspecting-ios-simulator-animations` skill for the transition checks.

Verify all of:

1. **Bottom toast** appears at the bottom, then disappears on its own after ~3s.
2. **Top toast** appears at the top and respects the status bar / Dynamic Island safe area.
3. **Both at once** shows two toasts simultaneously without either moving the other.
4. **Passthrough** — with a 30-second toast up, "Tap me while a toast is up" still responds. **This is the critical check.**
5. **Toast content stays interactive** — the Undo button inside the custom toast fires.
6. **Over a sheet** — "Present, then open a sheet" leaves the toast visible above the sheet.
7. **Presenting from inside the sheet** renders above the sheet with no second host attached.
8. **Tap to dismiss** removes a toast; **swipe** toward its own edge removes it; a short drag springs back.
9. **Disabled dismissal** — the "Tap and swipe are disabled" toast ignores both and only leaves on its own.
10. **Indefinite** toast stays until stopped.

- [ ] **Step 3: If passthrough (check 4) fails, apply the fallback**

If touches are swallowed while a toast is up, `_UIHostingView` is reporting itself as
the hit view across the whole window rather than only over content. Replace the
identity check with frame reporting:

In `NotiRootView.swift`, report each live toast's global frame to the host:

```swift
NotiSlotView(presentation: presentation, center: center)
    .transition(transition(for: edge))
    .onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .global)
    } action: { frame in
        center.setContentFrame(frame, for: edge)
    }
```

Add to `NotiCenter` an `@ObservationIgnored private(set) var contentFrames: [NotiEdge: CGRect]`, a
`func setContentFrame(_ frame: CGRect, for edge: NotiEdge)`, and clear the entry
whenever that slot is cleared. Then change the decision in `NotiHitTesting` to:

```swift
static func passesThrough(point: CGPoint, contentFrames: [CGRect]) -> Bool {
    !contentFrames.contains { $0.contains(point) }
}
```

and have `PassthroughWindow` hold a weak reference to the center to consult it.
Update `NotiHitTestingTests` to cover the frame variant: a point inside a frame does
not pass through, a point outside all frames does, and an empty frame list always
passes through. Re-run Step 2's check 4.

- [ ] **Step 4: Write the README**

Create `README.md`:

````markdown
# NotiWindow

Toasts that render above everything — including sheets and system alerts — in a
dedicated passthrough window, while the app underneath stays fully usable.

## Why

A toast built with `.overlay` lives inside the view hierarchy, so anything presented
above that hierarchy covers it. The usual workaround is attaching another toast host
inside every sheet. NotiWindow hosts toasts in their own `UIWindow` at
`windowLevel = .alert + 1`, so there is exactly one host and nothing covers it.

## Requirements

iOS 18.6+. No dependencies.

## Install

```swift
.package(url: "https://github.com/<owner>/NotiWindow", from: "1.0.0")
```

## Use

Attach the window once at your app root, holding the center yourself so non-view
code can present too:

```swift
@main
struct MyApp: App {
    @State private var center = NotiCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .notiWindow(center)
        }
    }
}
```

Present from anywhere:

```swift
center.present(.bottom) {
    NotiToast("Saved", systemImage: "checkmark.circle.fill", tint: .green)
}
```

Any view works, not just `NotiToast`:

```swift
center.present(.top, duration: .seconds(5)) {
    HStack {
        ProgressView()
        Text("Uploading…")
    }
    .padding()
    .background(.regularMaterial, in: Capsule())
}
```

Indefinite toasts dismiss by token:

```swift
let token = center.present(.top, duration: .indefinite) {
    NotiToast("Syncing…")
}
// later
center.dismiss(token)
```

Inside views, reach the center through the environment:

```swift
@Environment(\.notiCenter) private var center
```

## Behavior

- **Two independent slots.** Top and bottom each hold one toast, and can be occupied
  at the same time. Presenting on an occupied edge replaces its occupant.
- **Dismissal.** Tap and swipe-toward-its-own-edge are both on by default; disable
  either per call with `dismissOnTap:` / `dismissOnSwipe:`.
- **Reduce Motion.** Slide transitions collapse to a fade automatically.
- **Passthrough.** Touches outside a toast reach the app untouched. Buttons inside a
  toast work normally.

## License

MIT
````

- [ ] **Step 5: Run the full test suite one last time**

Run: `cd /Users/justin/dev/ios/NotiWindow && xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs: add README and record runtime verification"
```

---

## Verification Checklist

Before declaring the library done, confirm every one of these:

- [ ] `xcodebuild test -scheme NotiWindow -destination 'platform=iOS Simulator,name=iPhone 17'` passes from the repository root
- [ ] `xcodebuild build -project Example/NotiWindowExample.xcodeproj -scheme NotiWindowExample -destination 'platform=iOS Simulator,name=iPhone 17'` succeeds
- [ ] No test reads source files or asserts on source text
- [ ] No test calls `Task.sleep`, `Date()`, or otherwise waits on the clock
- [ ] All ten runtime checks in Task 12 Step 2 observed, especially passthrough and over-a-sheet
- [ ] The package references nothing from iAniList
- [ ] The public API matches the spec, with only the four documented deviations
- [ ] The spec has been updated to match the four deviations, or each has been
      consciously accepted as a plan-level departure
