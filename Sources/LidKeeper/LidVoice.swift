import AVFoundation
import Foundation

/// 闔蓋的時候出個聲，說它不會睡。
///
/// 聲音優先用 bundle 裡的 `lid-closed` 音檔，沒放的話退回系統語音。
/// 換聲音只要換掉那個檔案，這裡不用動。
@MainActor
final class LidVoice {
    private static let defaultsKey = "announceOnLidClose"
    private static let fallbackLine = "Don't worry, I won't fall asleep."

    /// 蓋上的瞬間音訊輸出還在切換，太早出聲會被吃掉開頭，所以隔一下再講。
    private static let delay: TimeInterval = 1.2

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var pending: DispatchWorkItem?

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    func lidClosed() {
        guard enabled else { return }

        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.speak() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    /// 還沒出聲蓋子就被打開了，那就不用講。
    func lidOpened() {
        pending?.cancel()
        pending = nil
    }

    /// 在選單上打開這個功能時放一次，讓人當場知道會聽到什麼。
    func preview() {
        pending?.cancel()
        speak()
    }

    private func speak() {
        if let url = audioURL(), let player = try? AVAudioPlayer(contentsOf: url) {
            self.player = player   // 不留著 reference 的話會在播完之前被回收掉
            player.play()
            return
        }

        // 沒有音檔（或檔案讀不動）就用系統語音，總比整個沒反應好
        let utterance = AVSpeechUtterance(string: Self.fallbackLine)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    /// 副檔名不寫死，丟哪種格式進 bundle 都找得到。
    private func audioURL() -> URL? {
        for ext in ["m4a", "mp3", "wav", "aiff", "caf"] {
            if let url = Bundle.main.url(forResource: "lid-closed", withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
