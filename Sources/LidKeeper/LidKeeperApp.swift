import SwiftUI
import ServiceManagement

@main
struct LidKeeperApp: App {
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
