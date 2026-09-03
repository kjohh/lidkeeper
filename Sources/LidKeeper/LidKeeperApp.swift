import SwiftUI
import ServiceManagement

@main
struct LidKeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = SleepState()

    var body: some Scene {
        MenuBarExtra {
            Text(state.sleepDisabled ? "闔蓋不會睡" : "闔蓋會睡")

            Divider()

            Button(state.sleepDisabled ? "恢復正常睡眠" : "闔蓋保持清醒") {
                state.toggle()
            }

            Toggle("開機時啟動", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))

            if let problem = state.problem {
                Divider()
                Text(problem)
            }

            Divider()

            Button("結束") { state.quit() }
        } label: {
            Image(systemName: state.sleepDisabled ? "cup.and.saucer.fill" : "moon.zzz")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// 只為了在啟動後把選單列的提示叫出來。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in LaunchHint.show() }
    }

    /// 已經在跑的時候又去 Finder 點兩下，macOS 只會把 app 叫到前景、不會重新啟動。
    /// 那時候畫面上一樣毫無反應，所以這裡也要把提示叫出來。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in LaunchHint.show(reopened: true) }
        return true
    }
}
