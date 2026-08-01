import SwiftUI
import Testing
import UIKit
@testable import NotiWindow

/// Window-configuration tests, hosted by the example app.
///
/// These live here rather than in the package's own test bundle because that bundle
/// runs as the bare `xctest` tool, where `UIApplication.shared.connectedScenes` is
/// empty. An app-hosted test target has a real `UIWindowScene`, which is what
/// `NotiWindowHost` requires.
@Suite("NotiWindowHost")
@MainActor
struct NotiWindowHostTests {
    /// The runner app's window scene. A nil scene is a genuine failure here — the
    /// whole point of hosting these tests in the app is that one exists.
    private func activeScene() throws -> UIWindowScene {
        try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
    }

    @Test("The window sits above sheets and system alerts")
    func windowSitsAboveAlerts() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.windowLevel == .alert + 1)
    }

    @Test("The window never becomes key")
    func windowNeverBecomesKey() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isKeyWindow == false)
    }

    @Test("The window is visible")
    func windowIsVisible() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isHidden == false)
    }

    @Test("Window and root view backgrounds are clear")
    func backgroundsAreClear() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.backgroundColor == .clear)
        #expect(host.window.rootViewController?.view.backgroundColor == .clear)
    }

    @Test("Tearing down hides the window and releases its content")
    func tearDownHidesWindow() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())

        host.tearDown()

        #expect(host.window.isHidden == true)
        #expect(host.window.rootViewController == nil)
    }

    @Test("Teardown leaves live toasts in the center untouched")
    func tearDownPreservesCenterState() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        let token = center.present(.top, duration: .indefinite) { Text("live") }

        host.tearDown()

        #expect(center.presentation(for: .top)?.token == token)
    }
}
