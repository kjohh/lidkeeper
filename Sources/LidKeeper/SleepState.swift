import Foundation
import ServiceManagement

/// 讀寫系統的 SleepDisabled 旗標。
///
/// 讀：從 IORegistry 讀 IOPMrootDomain 的 SleepDisabled，不需要權限。
/// 寫：只能透過 `sudo pmset -a disablesleep`，需要 root。
///     第一次切換會彈出系統密碼框，順手把 sudoers 規則裝好，之後就不用再輸密碼。
@MainActor
final class SleepState: ObservableObject {
    @Published private(set) var sleepDisabled = false
    @Published private(set) var problem: String?
    @Published private(set) var launchAtLogin = false

    private var timer: Timer?

    init() {
        refresh()
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // 別的地方（終端機、另一個工具）改了設定也要跟著更新
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let result = run("/usr/sbin/ioreg", ["-r", "-c", "IOPMrootDomain", "-d", "1"])
        guard result.status == 0 else { return }

        guard let line = result.output
            .split(separator: "\n")
            .first(where: { $0.contains("\"SleepDisabled\"") }) else { return }

        sleepDisabled = line.contains("Yes")
    }

    func toggle() {
        let target = sleepDisabled ? "0" : "1"
        problem = nil

        // 裝過 sudoers 的話這條就過了，不會有任何提示
        if run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", target]).status == 0 {
            refresh()
            return
        }

        // 第一次使用：彈一次系統密碼框，同時裝 sudoers 並把狀態切過去
        grantPermission(then: target)
        refresh()
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            problem = "設定開機啟動失敗：\(error.localizedDescription)"
        }
    }

    /// 用系統的密碼對話框取得 root，跑 bundle 裡的安裝腳本。
    /// 腳本本身放在 app bundle 內，不是暫存目錄，所以沒有被換掉後以 root 執行的風險。
    private func grantPermission(then target: String) {
        guard let script = Bundle.main.path(forResource: "install-sudoers", ofType: "sh") else {
            problem = "找不到安裝腳本，app 可能沒編完整"
            return
        }

        let command = "\(quoted(script)) \(quoted(NSUserName())) \(quoted(target))"
        let appleScript = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        let result = run("/usr/bin/osascript", ["-e", appleScript])

        if result.status != 0 {
            // 使用者按取消也會走到這，不用當成錯誤大聲抱怨
            problem = "沒有取得權限，再點一次可以重試"
        }
    }

    private func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func run(_ path: String, _ arguments: [String]) -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ("", -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
    }
}
