import AppKit
import SwiftUI

/// App 打開之後從選單列圖示滑出來的小提示。
///
/// 這個 app 沒有視窗也沒有 Dock 圖示，在 Finder 點兩下之後畫面上不會有任何反應，
/// 使用者不會知道它跑到選單列上了。這個提示就是在講這件事，幾秒後自己收掉。
@MainActor
enum LaunchHint {
    private static var popover: NSPopover?
    private static let visibleSeconds: TimeInterval = 6
    private static let contentSize = NSSize(width: 250, height: 132)

    static func show(reopened: Bool = false, attemptsLeft: Int = 10) {
        // MenuBarExtra 的 status item 是非同步建立的，而且剛出現時高度還是 0，
        // 那個狀態下 popover 定不到位置也不會顯示，所以要等它排版完成
        guard let anchor = statusItemView(), anchor.bounds.height > 0 else {
            guard attemptsLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                show(reopened: reopened, attemptsLeft: attemptsLeft - 1)
            }
            return
        }

        dismiss()

        let popover = NSPopover()
        popover.behavior = .applicationDefined   // 自己控制關閉時機，不要被點一下就消失
        popover.contentViewController = NSHostingController(rootView: HintView(reopened: reopened, onDismiss: dismiss))
        popover.contentSize = Self.contentSize   // 不給的話會是 0 乘 0，等於看不見

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        self.popover = popover

        DispatchQueue.main.asyncAfter(deadline: .now() + visibleSeconds) { dismiss() }
    }

    static func dismiss() {
        popover?.performClose(nil)
        popover = nil
    }

    /// 撈 MenuBarExtra 建出來的選單列按鈕，拿來當氣泡的錨點。
    /// 只讀 window 的型別名稱跟 contentView，沒有用到私有 API。
    private static func statusItemView() -> NSView? {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBar") {
            if let view = window.contentView, view.window != nil {
                return view
            }
        }
        return nil
    }
}

private struct HintView: View {
    let reopened: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reopened ? "LidKeeper 已經開著了" : "LidKeeper 開好了")
                .font(.headline)

            Text(reopened
                 ? "它一直在這裡。點這顆圖示就能切換闔蓋要不要保持清醒。"
                 : "它待在這裡，點這顆圖示就能切換闔蓋要不要保持清醒。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("知道了", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 250)
    }
}
