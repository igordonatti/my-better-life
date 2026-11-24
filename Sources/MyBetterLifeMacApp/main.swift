import SwiftUI
import AppKit
import MyBetterLifeCore
import MyBetterLifeUI

/// macOS executable entry point so `swift run MyBetterLifeMacApp` launches
/// the native macOS SwiftUI window + Menu Bar companion directly without requiring Xcode.app.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    private func applyAppIcon() {
        // When launched as a packaged .app bundle, macOS already loads AppIcon.icns via Info.plist.
        if Bundle.main.bundleURL.pathExtension == "app",
           let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: icnsURL) {
            NSApp.applicationIconImage = icon
            return
        }
        // When launched via `swift run` / `make run`, load the bundled PNG from SwiftPM resources.
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppIcon()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Keep running in the macOS Menu Bar so the Focus Timer & Quick Capture stay accessible.
    /// Quit cleanly with `⌘Q` or "Encerrar" in the Menu Bar popover.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct MyBetterLifeMacSwiftUIApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var store = PlannerStore(inMemory: false, enableCloudKit: false)
    @State private var focusManager = FocusSessionManager()
    @State private var windowCoordinator = DetachedWindowCoordinator()

    var body: some Scene {
        WindowGroup(L10n.appName, id: "main") {
            MyBetterLifeRootView(
                store: store,
                focusManager: focusManager,
                windowCoordinator: windowCoordinator
            )
                .frame(minWidth: 1060, minHeight: 640)
        }
        .defaultSize(width: 1320, height: 840)

        WindowGroup(id: DetachedEditorTarget.windowID, for: DetachedEditorTarget.self) { $target in
            if let target {
                DetachedEditorWindowView(
                    target: target,
                    store: store,
                    focusManager: focusManager,
                    windowCoordinator: windowCoordinator
                )
            }
        }
        .defaultSize(width: 480, height: 660)

        MenuBarExtra {
            MacMenuBarPopoverView(
                store: store,
                focusManager: focusManager,
                onOpenMainWindow: {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        } label: {
            MacMenuBarLabel(focusManager: focusManager)
        }
        .menuBarExtraStyle(.window)
    }
}

MyBetterLifeMacSwiftUIApp.main()
