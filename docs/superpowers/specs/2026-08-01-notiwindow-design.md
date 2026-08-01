# NotiWindow — Design

**Date:** 2026-08-01
**Status:** Approved, pending implementation plan

## Purpose

NotiWindow is a standalone Swift package that presents arbitrary SwiftUI content as
transient toasts anchored to the top or bottom of the screen, hosted in a dedicated
passthrough `UIWindow` layered above the app's own UI.

The motivating problem comes from iAniList. Its current toast is a `ViewModifier`
applying `.overlay(alignment: .bottom)` inside the view hierarchy, so anything
presented above that hierarchy covers it. `EditEntrySheet` works around this by
attaching a second toast host inside the sheet. Every new modal surface needs the
same workaround. A toast hosted in its own window at `windowLevel = .alert + 1`
renders above sheets and system alerts, and the workaround disappears.

iAniList is the first consumer, but the package takes no dependency on it and knows
nothing about anime, media, or AniList.

**Out of scope for this spec:** any change to iAniList. Migrating the app —
deleting `ToastOverlay`, retargeting `ToastCenter` call sites, removing the
`EditEntrySheet` double-host — is a separate spec written after this library exists.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Packaging | Swift Package | Matches how iAniList already consumes `AniListDataModel`; no Xcode project to maintain; open-sourceable later. |
| Platform | iOS 18.6+ only | `UIWindow` is UIKit. Matches iAniList's deployment target. The scaffold's iOS 26.5 would have made the package unusable by its only consumer. |
| Presentation API | Imperative center | Near drop-in for existing `ToastCenter.show(...)` call sites, and callable from non-view code such as `ListService`. |
| Concurrency | Single slot per edge, top and bottom independent | Preserves current behavior. Queueing and stacking are additive later without breaking the API. |
| Dismissal | Tap and swipe, both default on | Matches current tap-to-dismiss; swipe toward the toast's own edge is standard iOS feel. |
| Styling | Host owns placement, caller owns chrome, plus an optional `NotiToast` | Keeps the core a placement primitive while making trivial call sites one-liners. |
| Installation | `.notiWindow(center)` view modifier | Resolves the exact `UIWindowScene` from the view hierarchy — no `connectedScenes` heuristic — and binds window lifetime to the installing view. |
| Verification | Unit tests plus an example app | The core claim ("renders above a sheet") is only provable at runtime; proving it in isolation beats discovering window bugs during the iAniList migration. |

### Why not SwiftUI scenes

`WindowGroup` and `Window` cannot do this on iOS. SwiftUI exposes no API to layer
content above itself, and its scene types create *sibling* scenes — separate app
windows in the app switcher or Split View — not a floating layer over the running
UI. There is also no SwiftUI-level control over `windowLevel` or hit-testing. A
UIKit `UIWindow` subclass with an elevated level and a `hitTest` override is the
only mechanism that produces a passthrough overlay.

The UIKit window is therefore an implementation detail. The public API is a SwiftUI
view modifier; consumers never see or touch UIKit.

### Why not a scene modifier or a consumer-owned host

A `WindowGroup { … }.notiWindow()` scene modifier reads more naturally, but `Scene`
offers no hook that hands you the `UIWindowScene`. It would have to fall back to
scanning `UIApplication.shared.connectedScenes` for a foreground-active scene —
reintroducing the guesswork the view modifier avoids.

A consumer-owned host object (`NotiWindowHost.install(in: scene)`) is the most
explicit option but pushes window lifetime management onto every app, and iAniList
has no `SceneDelegate` to hang it on. That type still exists as the seam beneath the
modifier, which is what makes the window testable.

## Package layout

```
NotiWindow/
  Package.swift                    // swift-tools 6.1, .iOS("18.6")
  Sources/NotiWindow/
    NotiCenter.swift               // presentation state + lifetime
    NotiEdge.swift
    NotiDuration.swift
    NotiPresentation.swift
    NotiSleeper.swift              // timing seam
    Window/
      PassthroughWindow.swift      // UIWindow subclass, hitTest override
      NotiWindowHost.swift         // owns window + hosting controller
      NotiRootView.swift           // renders top/bottom slots
      NotiHitTesting.swift         // pure decision function
    View/
      NotiWindowModifier.swift     // .notiWindow(center)
      NotiToast.swift              // batteries-included pill
    Environment/
      NotiCenterKey.swift
  Tests/NotiWindowTests/
  Example/NotiWindowExample.xcodeproj
  README.md
```

The existing `NotiWindow.xcodeproj` framework scaffold is converted into the example
**app** project under `Example/`. SPM cannot build an iOS `.app`, so the example
needs an Xcode project regardless; reusing the scaffold avoids maintaining a
redundant framework target.

## Public API

This is the complete public surface.

```swift
public enum NotiEdge: Sendable { case top, bottom }

public enum NotiDuration: Sendable {
    case seconds(Double)
    case indefinite
    public static let standard: NotiDuration = .seconds(3)
}

@MainActor @Observable
public final class NotiCenter {
    public init()

    @discardableResult
    public func present(
        _ edge: NotiEdge = .bottom,
        duration: NotiDuration = .standard,
        dismissOnTap: Bool = true,
        dismissOnSwipe: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> NotiToken

    public func dismiss(_ edge: NotiEdge)
    public func dismiss(_ token: NotiToken)
    public func dismissAll()
}

public struct NotiToken: Hashable, Sendable {
    // Opaque identity; wraps a private UUID. No public members.
}

extension View {
    public func notiWindow(_ center: NotiCenter) -> some View
    public func notiWindow() -> some View
}

extension EnvironmentValues {
    public var notiCenter: NotiCenter { get set }
}

public struct NotiToast: View {
    /// `tint` colors the leading SF Symbol; the text always uses the primary
    /// foreground style. `systemImage: nil` renders text only.
    public init(_ text: String, systemImage: String? = nil, tint: Color = .primary)
}
```

**`notiWindow(_:)` takes the center rather than creating one.** iAniList reaches its
toast center from non-view code (`ListService`); a privately-owned center would break
that path. The app holds the center — mirroring its current
`@State private var toastCenter` — and hands it in. The no-argument overload creates
one and injects it into the environment only, for simple apps and the example.

**`present` returns a `NotiToken`.** Required for `.indefinite` toasts: present
"Syncing…", hold the token, dismiss when the work finishes. `dismiss(_ token:)`
no-ops if that presentation was already replaced, so a late dismissal cannot kill an
unrelated toast that has since taken the slot.

**Content is type-erased** to `AnyView` inside `NotiPresentation`. With at most two
live toasts the cost is irrelevant, and it keeps `NotiCenter` non-generic so it can
be stored and passed around freely.

### Deliberately excluded from v1

Styling knobs (max width, insets, corner radius), queueing, stacking, per-toast
animation overrides, and non-iOS platforms. All are additive later without breaking
the surface above.

## Internals

### Installation

`.notiWindow(center)` places a zero-size `UIViewRepresentable` in the background of
the modified view. In `updateUIView` it reads `view.window?.windowScene` — the app's
actual scene — and constructs `NotiWindowHost(scene:center:)`. `dismantleUIView`
tears the host down.

Window lifetime therefore tracks the installing view. A second iPad scene gets its
own window and center binding, and neither leaks.

### NotiWindowHost

The explicit seam beneath the modifier. Owns:

- a `PassthroughWindow(windowScene:)` at `windowLevel = .alert + 1` — above sheets
  and above system alerts
- a `UIHostingController<NotiRootView>` with a clear `view.backgroundColor` and a
  clear window background
- `isHidden = false`, and the window never becomes key, so it cannot steal first
  responder from the app's text fields

### Passthrough hit-testing

`PassthroughWindow.hitTest` delegates to `super`, then consults a pure function:

```swift
enum NotiHitTesting {
    static func passesThrough(hitView: UIView?, rootView: UIView?) -> Bool {
        hitView == nil || rootView == nil || hitView === rootView
    }
}
```

When it returns true, `hitTest` returns `nil` and the touch falls through to the
app's window.

A nil root view passes through as well. A window with no root view has no content
to hit, and `UIWindow.hitTest` returns the window itself for in-bounds points — so
absorbing that touch would freeze the entire host app if the window were ever
visible while unconfigured. Failing open here keeps the worst case aligned with the
failure-behavior principle below: a toast that does not appear, never an app that
stops responding.

Identity-against-root is chosen over frame math deliberately. Frame comparison gets
rounded corners, transforms, and in-flight transition geometry wrong, whereas "did we
hit anything other than the transparent backdrop" is correct by construction.
Interactive controls inside a toast work normally.

### NotiRootView

Observes the center and renders two independent slots in a full-screen `ZStack` —
the top presentation pinned to the top safe area, the bottom to the bottom safe area.
Per slot it applies:

- **Transition:** slide from that slot's own edge combined with opacity, collapsing
  to opacity-only when `\.accessibilityReduceMotion` is on. This is lifted from
  iAniList's current `ToastOverlay` so the library owns the behavior once rather than
  each consuming app reimplementing it. The slot view is keyed with
  `.id(presentation.token)`: replacing a toast on an occupied edge leaves the slot
  non-empty throughout, so without a per-presentation identity SwiftUI would reuse the
  view instance, skip the transition entirely, and carry the outgoing toast's drag
  offset into the incoming one.
- **Gestures:** tap when `dismissOnTap`; drag toward the slot's own edge when
  `dismissOnSwipe` — dismissing once the drag exceeds 40 points in that direction,
  otherwise springing back. Drags away from the edge are ignored.
- **Layout:** max width 500 with a horizontal inset, so a toast does not span an iPad.

Accessibility in v1 is deliberately minimal: `NotiToast` carries the static-text
trait, and the host does not force or trap VoiceOver focus. Richer announcement
behavior is deferred until the visual design settles.

### Lifetime and timing

Auto-dismiss timing lives in `NotiCenter`, behind an injected seam:

```swift
protocol NotiSleeper: Sendable {
    func sleep(for duration: Duration) async throws
}
```

The default implementation wraps `Task.sleep`. Tests inject a manual sleeper they
resume explicitly.

This moves timing out of the view, where iAniList currently keeps it. With timing in
a `.task` modifier, "a replacing toast resets the timer" and "`.indefinite` never
expires" are observable only by running the UI. Behind the seam they are synchronous
unit tests, which is what the behavioral-seam testing rule requires.

Each presentation's expiry task verifies its token is still the current occupant of
the slot before dismissing, so a replaced toast's in-flight timer cannot cut its
replacement short.

## Failure behavior

No public API throws. A notification library must never crash its host app or block
its UI; the worst realistic outcome is a toast that does not appear.

| Situation | Behavior |
|---|---|
| `present` called before `.notiWindow()` installs | Center stores the presentation. The host renders whatever is current when it appears, so a launch-time toast is not lost. |
| `view.window?.windowScene` nil on first pass | Installer retries on the next `updateUIView`. No crash, no assertion. |
| Host torn down while toasts are live | Expiry tasks cancelled; center state left intact so a re-install renders correctly. |
| `dismiss(_ token:)` after replacement | No-op. |
| `present` called off the main actor | Impossible — `NotiCenter` is `@MainActor`, enforced at compile time. |

## Testing

Tests run via `xcodebuild test` against a simulator destination. The package imports
UIKit, so `swift test` on macOS is not available. These remain fast unit tests: no UI
automation, no wall-clock sleeps.

**No source-reading tests.** Carried over from iAniList's testing policy: no test
loads source with `String(contentsOf:)` and asserts with `source.contains(...)`.
Invariants are protected behaviorally through a seam, or as a pure function.

### NotiCenterTests
- `present` populates the requested slot
- Same-edge `present` replaces the current occupant
- Top and bottom slots coexist and are independent
- `dismiss(_ edge:)` clears only that edge
- `dismissAll` clears both
- `dismiss(_ token:)` no-ops after that presentation was replaced

### Timing tests (via manual `NotiSleeper`)
- A toast auto-dismisses when its duration elapses
- `.indefinite` never expires
- A replacing toast receives a fresh full duration
- A replaced toast's expiry does not dismiss its replacement

### NotiHitTestingTests
- `passesThrough` is true for `nil`, for the root view itself, and for a nil root view
- `passesThrough` is false for any descendant view

### NotiWindowHostTests — hosted by the example app, not the package

The package's own test bundle cannot cover `NotiWindowHost`. It runs as the bare
`xctest` command-line tool, where `UIApplication.shared.delegate` is nil and
`connectedScenes` is empty, and SwiftPM offers no way to declare a test host. These
tests therefore live in `Example/NotiWindowExampleTests/`, run by the example app's
unit-test target, which has a real `UIWindowScene`.

- A host constructed against a real scene produces a window at `.alert + 1`
- The window is not key
- The window is visible
- The window and hosting controller backgrounds are clear
- Teardown hides the window and releases its root view controller
- Teardown leaves live toasts in the center untouched

## Example app

`Example/NotiWindowExample.xcodeproj` — a small SwiftUI app whose buttons cover:

- bottom toast
- top toast
- both simultaneously
- indefinite toast with manual dismiss
- custom `ViewBuilder` content containing a working button
- **present while a sheet is presented**

The last is the claim that justifies the library's existence and gets a dedicated
button. The example also serves as the README demo.
