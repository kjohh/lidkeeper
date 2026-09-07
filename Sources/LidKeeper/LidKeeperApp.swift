import SwiftUI
import ServiceManagement

@main
struct LidKeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = SleepState()

    var body: some Scene {
        MenuBarExtra {
            // 這個 app 只做一件事，所以那件事自己一區，標題直接講現在的狀況
            Section(state.sleepDisabled ? "現在闔蓋不會睡" : "現在闔蓋會睡") {
                Toggle("闔蓋保持清醒", isOn: Binding(
                    get: { state.sleepDisabled },
                    set: { state.setSleepDisabled($0) }
                ))
            }

            // 底下這兩個是偏好，開了就一直是那樣，跟上面的主開關不同性質
            Section("選項") {
                Toggle("闔蓋時說話", isOn: Binding(
                    get: { state.voiceEnabled },
                    set: { state.setVoiceEnabled($0) }
                ))

                Toggle("開機時啟動", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
            }

            if let problem = state.problem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                }
            }

            Divider()

            Button("結束 LidKeeper") { state.quit() }
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
