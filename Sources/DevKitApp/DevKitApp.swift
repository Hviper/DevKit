import SwiftUI
import DevKitCore
import AppKit

@main
struct DevKitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("DevKit - 开发者工具箱") {
            MainPopoverView()
                .environmentObject(appState)
                .frame(minWidth: 820, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 860, height: 600)

        MenuBarExtra("DevKit", systemImage: "hammer.fill") {
            MainPopoverView()
                .environmentObject(appState)
                .frame(width: 820, height: 580)
        }
        .menuBarExtraStyle(.window)
    }
}
