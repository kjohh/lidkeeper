import AppKit
import Foundation
import IOKit
import ServiceManagement

/// 讀寫系統的 SleepDisabled 旗標，順便看著蓋子開闔。
///
/// 讀：從 IORegistry 讀 IOPMrootDomain 的 SleepDisabled，不需要權限。
/// 寫：只能透過 `sudo pmset -a disablesleep`，需要 root。
///     第一次切換會彈出系統密碼框，順手把 sudoers 規則裝好，之後就不用再輸密碼。
@MainActor
final class SleepState: ObservableObject {
    @Published private(set) var sleepDisabled = false
    @Published private(set) var problem: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var voiceEnabled = false

    private let voice = LidVoice()
    private var lidClosed = false

    private var timer: Timer?
    private var powerNotifier: io_object_t = 0

    init() {
        refresh()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        voiceEnabled = voice.enabled
        watchPowerEvents()

        // 別的地方（終端機、另一個工具）改了設定也要跟著更新。
        // 蓋子的變化不靠這個，那條路走下面的電源事件，不然要闔上五秒才會出聲。
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let result = run("/usr/sbin/ioreg", ["-r", "-c", "IOPMrootDomain", "-d", "1"])
        guard result.status == 0 else { return }

        let lines = result.output.split(separator: "\n")

        if let line = lines.first(where: { $0.contains("\"SleepDisabled\"") }) {
            sleepDisabled = line.contains("Yes")
        }

        // 同一份輸出裡就有蓋子的狀態，不用另外再查一次。
        // 注意隔壁還有個 AppleClamshellCausesSleep，所以要連引號一起比對。
        if let line = lines.first(where: { $0.contains("\"AppleClamshellState\"") }) {
            updateLid(closed: line.contains("Yes"))
        }
    }

    /// 蓋子的狀態由 IOPMrootDomain 主動推過來，不用把輪詢間隔縮短去等它。
    /// 這裡不挑特定訊息類型，收到任何電源事件就重讀一次，省得依賴那些沒有公開常數的值。
    private func watchPowerEvents() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddInterestNotification(port, service, kIOGeneralInterest, { context, _, _, _ in
            guard let context else { return }
            // 上面指定了 main queue，所以這裡一定在主執行緒上
            MainActor.assumeIsolated {
                Unmanaged<SleepState>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, context, &powerNotifier)
    }

    /// 蓋子闔上而且現在是不睡的狀態，才值得出聲。
    /// 本來就要睡的話講到一半也會被切掉，不如不要講。
    private func updateLid(closed: Bool) {
        guard closed != lidClosed else { return }
        lidClosed = closed

        if closed {
            if sleepDisabled { voice.lidClosed() }
        } else {
            voice.lidOpened()
        }
    }

    func setVoiceEnabled(_ on: Bool) {
        voice.enabled = on
        voiceEnabled = on
    }

    /// 面板上那顆試聽鍵。開開關不該連帶播放，想聽的人自己點。
    func previewVoice() {
        voice.preview()
    }

    /// 畫面先走，pmset 丟到背景。
    ///
    /// pmset 是外部程序，同步跑會把主執行緒卡住一段時間，那段時間剛好吃掉整個切換動畫，
    /// 看起來就是開關瞬間跳過去。真正的狀態等 refresh 回來校正。
    func setSleepDisabled(_ on: Bool) {
        sleepDisabled = on
        problem = nil

        let target = on ? "1" : "0"
        Task { [weak self] in
            let granted = await Self.runOffMain("/usr/bin/sudo",
                                                ["-n", "/usr/bin/pmset", "-a", "disablesleep", target])
            guard let self else { return }
            // 免密碼那條沒過，就走彈系統密碼框的路徑
            if !granted { self.grantPermission(then: target) }
            self.refresh()
        }
    }

    private nonisolated static func runOffMain(_ path: String, _ arguments: [String]) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do { try process.run() } catch { return false }
            process.waitUntilExit()
            return process.terminationStatus == 0
        }.value
    }

    /// 結束前先問清楚要留下哪個狀態。
    ///
    /// 設定是寫在系統上的，app 結束不會還原，所以放著不管等於「闔蓋不睡」會一直生效，
    /// 而選單列上已經沒有東西可以關掉它了。現在是正常睡眠的話就沒有這個問題，直接結束。
    func quit() {
        guard sleepDisabled else {
            NSApplication.shared.terminate(nil)
            return
        }

        // 等選單收起來再彈，不然對話框會被蓋住
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = "結束之後要維持哪個狀態？"
            alert.informativeText = "現在闔蓋不會睡。這是寫在系統上的設定，LidKeeper 結束之後會繼續生效，只是選單列上不再有開關可以改。"
            alert.addButton(withTitle: "保持清醒")
            alert.addButton(withTitle: "恢復正常睡眠")
            alert.addButton(withTitle: "取消")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSApplication.shared.terminate(nil)
            case .alertSecondButtonReturn:
                self.apply(false)
                NSApplication.shared.terminate(nil)
            default:
                break
            }
        }
    }

    private func apply(_ disabled: Bool) {
        let target = disabled ? "1" : "0"
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
