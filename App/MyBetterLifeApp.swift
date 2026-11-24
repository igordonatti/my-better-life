import SwiftUI
import MyBetterLifeCore
import MyBetterLifeUI
#if os(macOS)
import AppKit
#endif

/// Multiplatform iOS + macOS App entry point for the Xcode project.
/// Flip `enableCloudKit` to `true` after enabling iCloud & CloudKit capability
/// with your Apple Developer team in Xcode Signing & Capabilities.
@main
struct MyBetterLifeApp: App {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
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
                #if os(macOS)
                .frame(minWidth: 1060, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1320, height: 840)
        #endif

        #if os(macOS)
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
        #endif
    }
}
