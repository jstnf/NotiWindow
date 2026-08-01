# NotiWindow

Toasts that render above everything — including sheets — in a dedicated passthrough
window, while the app underneath stays fully usable.

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

Inside views, reach the center through the environment. The value is optional —
an `EnvironmentValues` default has to be constructible from a nonisolated context,
and `NotiCenter.init()` is main-actor isolated — but any view below a
`.notiWindow(_:)` finds one there:

```swift
@Environment(\.notiCenter) private var center
```

If every caller reaches the center through the environment, `.notiWindow()` with no
argument will make and own one for you.

## Behavior

- **Two independent slots.** Top and bottom each hold one toast, and can be occupied
  at the same time. Presenting on an occupied edge replaces its occupant, and the
  replacement slides in rather than snapping — even mid-drag, where the incoming
  toast arrives at rest instead of inheriting the outgoing one's offset.
- **Dismissal.** Tap and swipe-toward-its-own-edge are both on by default; disable
  either per call with `dismissOnTap:` / `dismissOnSwipe:`. A swipe that stops short
  of the dismissal threshold springs back. `dismiss(_:)` takes either a token or an
  edge, and `dismissAll()` clears both edges; dismissing one edge leaves the other
  alone.
- **Reduce Motion.** Slide transitions collapse to a fade automatically.
- **Passthrough.** Touches outside a toast reach the app untouched — including while
  a toast is up over a sheet. Buttons inside a toast work normally.

## License

MIT
